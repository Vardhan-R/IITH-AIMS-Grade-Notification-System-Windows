from cryptography.fernet import Fernet
from getpass import getpass
from json import dump
from pathlib import Path


CONFIG_PATH = Path.home() / ".aims-notifs" / "config.json"

username = input("Enter your AIMS username (roll number, all lowercase): ").strip().lower()
aims_password = getpass("Enter your AIMS password: ").strip("\n")
email = input("Enter your email address (from/to which the notification will be sent/received): ").strip()
app_password = getpass("Enter your App Password (NOT your email account password): ").strip("\n")

key = Fernet.generate_key()
cipher = Fernet(key)

aims_password_ciphertext = cipher.encrypt(aims_password.encode())
app_password_ciphertext = cipher.encrypt(app_password.encode())

config_data = {
    "username": username,
    "aims_password_ciphertext": aims_password_ciphertext.decode(),
    "email": email,
    "app_password_ciphertext": app_password_ciphertext.decode(),
    "key": key.decode()
}

with open(CONFIG_PATH, "w") as f:
    dump(config_data, f, ensure_ascii=False, indent=4)
