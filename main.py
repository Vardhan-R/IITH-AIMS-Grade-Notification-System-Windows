from cryptography.fernet import Fernet
from json import load
from playwright.sync_api import Page, BrowserContext, Request, sync_playwright
import logging
import os
import smtplib
import ssl
import unicodedata


APP_DIR = os.path.join(os.path.expanduser("~"), ".aims-notifs")
LOG_FILE = os.path.join(APP_DIR, "aims-notifs.log")
CONFIG_FILE_PATH = os.path.join(APP_DIR, "config.json")

BASE_URL = "https://aims.iith.ac.in/aims/"
DASHBOARD_URL = "https://aims.iith.ac.in/aims/login/dashboard"
COURSES_URL = (
    "https://aims.iith.ac.in/aims/courseReg/loadMyCoursesHistroy"
    "?studentId=&courseCd={}&courseName=&orderBy=1"
    "&degreeIds=&acadPeriodIds=&regTypeIds="
    "&gradeIds={}&resultIds={}&isGradeIds="
)

# Grade ID to letter-grade mapping
GID_GRD = {
    1: "A+",
    2: "A",
    3: "A-",
    4: "B",
    5: "B-",
    6: "C",
    7: "C-",
    8: "D",
    9: "FS",
    10: "FR",
    11: "I",
    12: "S",
    13: "U",
    14: "AU",
    15: "F",
    16: "P"
}

SMTP_SERVER = "smtp.gmail.com"
PORT = 465


class NewlineFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        message = record.getMessage()

        if message.startswith("\n"):
            record.msg = message.lstrip("\n")
            result = super().format(record)
            record.msg = message
            return "\n" + result

        return super().format(record)


handler = logging.FileHandler(LOG_FILE)
handler.setFormatter(NewlineFormatter("%(asctime)s - %(levelname)s - %(message)s"))

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
logger.addHandler(handler)


def load_credentials() -> tuple[str, str, str, str]:
    if not os.path.exists(CONFIG_FILE_PATH):
        raise FileNotFoundError(f"{CONFIG_FILE_PATH} not found. Please run setup.py first.")

    with open(CONFIG_FILE_PATH, "r") as f:
        config_data = load(f)

    username = config_data.get("username")
    aims_password_ciphertext = config_data.get("aims_password_ciphertext")
    email = config_data.get("email")
    app_password_ciphertext = config_data.get("app_password_ciphertext")
    key = config_data.get("key")

    if not all([username, aims_password_ciphertext, email, app_password_ciphertext, key]):
        raise ValueError(f"Missing required fields in {CONFIG_FILE_PATH}.")

    cipher = Fernet(key.encode())
    aims_password = cipher.decrypt(aims_password_ciphertext.encode()).decode()
    app_password = cipher.decrypt(app_password_ciphertext.encode()).decode()

    return username, aims_password, email, app_password


def login(page: Page) -> bool:
    # Go to login page
    page.goto(BASE_URL, wait_until="networkidle")

    # Extract captcha
    src = page.locator("#appCaptchaLoginImg").get_attribute("src")
    if src is None:
        logger.error("Captcha image source not found.")
        return False
    captcha = src.split("/")[-1]

    # Fill login form
    page.fill("#uid", username)
    page.fill("#pswrd", aims_password)
    page.fill("#captcha", captcha)

    # Click login
    page.click("#login")

    page.wait_for_url(DASHBOARD_URL)

    return page.url == DASHBOARD_URL


def obtain_jsessionid(page: Page) -> str | None:
    jsessionid = None

    def on_request_finished(req: Request) -> None:
        nonlocal jsessionid

        if "login" in req.url.lower():
            cookies = page.context.cookies()
            sessionid = next(
                (c for c in cookies if c.get("httpOnly") and c.get("name") == "JSESSIONID"), None
            )
            if sessionid:
                jsessionid = sessionid.get("value")

    page.wait_for_load_state("networkidle")
    page.on("requestfinished", on_request_finished)
    page.reload()

    return jsessionid


def get_json(url: str, context: BrowserContext) -> list[dict] | None:
    try:
        res = context.request.get(url, timeout=30_000)
        if not res.ok:
            logger.error(f"HTTP error {res.status}")
            return None
        return res.json()
    except Exception as e:
        logger.error(f"Failed to fetch JSON:\n{e}")
        return None


def get_not_graded_courses(context: BrowserContext) -> list[dict] | None:
    # Find graded courses
    url_passed = COURSES_URL.format("", "", "[1]")
    passed_courses = get_json(url_passed, context)
    if passed_courses is None:
        return None

    url_failed = COURSES_URL.format("", "", "[2]")
    failed_courses = get_json(url_failed, context)
    if failed_courses is None:
        return None

    graded_courses = passed_courses + failed_courses
    graded_ids = {f"{c['courseCd']}|{c['periodName']}" for c in graded_courses}

    # Find not graded courses
    url_all = COURSES_URL.format("", "", "")
    all_courses = get_json(url_all, context)
    if all_courses is None:
        return None

    not_graded_courses = [
        c for c in all_courses
        if f"{c['courseCd']}|{c['periodName']}" not in graded_ids
    ]

    return not_graded_courses


def get_newly_graded_course_ids(not_graded_courses: list[dict]) -> set[str]:
    if not os.path.exists("not_graded_courses.txt"):
        with open("not_graded_courses.txt", "w") as f:
            for c in not_graded_courses:
                f.write(f"{c['courseCd']}|{c['periodName']}\n")
        return set()
    with open("not_graded_courses.txt", "r") as f:
        prev = f.readlines()
    prev_ids = {line.strip() for line in prev}
    curr_ids = {f"{c['courseCd']}|{c['periodName']}" for c in not_graded_courses}
    newly_graded_ids = prev_ids - curr_ids
    return newly_graded_ids


def get_grade_messages(course_ids: set[str], context: BrowserContext) -> set[str]:
    msgs = set()
    for course in course_ids:
        course_cd, _ = course.split("|")
        for grade_id in range(1, 17):
            grade = GID_GRD.get(grade_id, f"Unknown Grade ID {grade_id}")
            url = COURSES_URL.format(f"{course_cd}", f"[{grade_id}]", "")
            res = get_json(url, context)
            if res and len(res) > 0:
                courseCd = res[0].get("courseCd", "")
                courseName = res[0].get("courseName", "")
                msg = f"[GRADES ARE OUT] {grade} in {courseName} ({courseCd})"
                msgs.add(msg)
                break
    return msgs


def notify_by_email(messages: set[str]) -> bool:
    try:
        with smtplib.SMTP_SSL(SMTP_SERVER, PORT, context=ssl.create_default_context()) as server:
            server.login(email, app_password)
            for msg in messages:
                message = unicodedata.normalize("NFKD", f"Subject: {msg}") \
                    .encode("ascii", "ignore") \
                    .decode("ascii")
                logger.info(message)
                server.sendmail(email, email, message)
        return True
    except Exception as e:
        logger.error(f"An error occurred while sending the emails: {e}")
        return False


def update_not_graded_courses_file(not_graded_courses: list[dict]) -> None:
    curr = [f"{c['courseCd']}|{c['periodName']}" for c in not_graded_courses]
    with open("not_graded_courses.txt", "w") as f:
        for line in curr:
            f.write(line + "\n")


def main() -> None:
    with sync_playwright() as p:
        logger.info("\nStarting aims-notifs...")
        browser = p.chromium.launch()
        context = browser.new_context()
        page = context.new_page()

        logger.info("Logging in...")
        if not login(page):
            logger.error("Login failed.")
            browser.close()
            return

        logger.info("Obtaining JSESSIONID...")
        jsessionid = obtain_jsessionid(page)
        if jsessionid is None:
            logger.error("Could not obtain JSESSIONID.")
            try:
                page.evaluate("logOut()")
                page.wait_for_load_state("networkidle")
            except Exception as e:
                logger.error(f"Error while logging out: {e}")
            browser.close()
            return
        else:
            logger.info("Obtained JSESSIONID.")

        # Inject cookie obtained after login
        context.add_cookies([{
            "name": "JSESSIONID",
            "value": jsessionid,
            "domain": "aims.iith.ac.in",
            "path": "/aims",
            "httpOnly": True,
            "secure": True,
            "sameSite": "Lax"
        }])

        logger.info("Checking for newly graded courses...")
        not_graded_courses = get_not_graded_courses(context)
        if not_graded_courses is not None:
            newly_graded = get_newly_graded_course_ids(not_graded_courses)
            if newly_graded:
                msgs = get_grade_messages(newly_graded, context)
                if notify_by_email(msgs):
                    logger.info("Notification email(s) sent successfully.")
                    update_not_graded_courses_file(not_graded_courses)
                else:
                    logger.error("Failed to send notification email(s).")
            else:
                logger.info("No newly graded courses found.")

        logger.info("Logging out...")
        page.evaluate("logOut()")
        page.wait_for_load_state("networkidle")

        browser.close()


if __name__ == "__main__":
    username, aims_password, email, app_password = load_credentials()
    main()
