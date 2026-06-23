# IITH AIMS Grade Notification System (`aims-notifs`)

A lightweight utility that automatically monitors AIMS for newly released course grades and sends email notifications when grades become available.

The application runs locally on your machine and checks AIMS every 15 minutes. When one or more courses are graded, an email notification is sent to your configured email address.

---

## Features

* Automatic AIMS grade monitoring
* Email notifications when new grades are released
* Runs automatically every 15 minutes
* Manual on-demand checks
* Persistent logging via systemd journal
* Simple installation and setup
* User-level installation (no root access required)

---

## Requirements

* Linux system with systemd user services enabled
* Python 3.10 or newer
* Internet connection
* AIMS account credentials (will only be stored locally)
* Email account with an app password configured

---

## Installation

Download or clone the project, then run:

```bash
./install.sh
```

This installs the `aims-notifs` command and copies the application files to:

```text
~/.aims-notifs
```

After installation, run:

```bash
aims-notifs setup
```

---

## Gmail App Password Setup

If you use Gmail to send notifications, you must create an **App Password** and use that instead of your normal Google account password.

Google requires App Passwords for applications that access Gmail via SMTP. App Passwords are only available if **2-Step Verification (2FA)** is enabled on your Google account.

### Step 1: Enable 2-Step Verification

1. Open your Google Account Security settings.
2. Enable **2-Step Verification** if it is not already enabled.

### Step 2: Generate an App Password

Follow Google's official instructions:

[Google App Passwords Guide](https://support.google.com/mail/answer/185833)

Or go directly to:

[Google App Passwords Page](https://myaccount.google.com/apppasswords)

### Step 3: Create a Password for AIMS Grade Notification System

1. Select **App passwords**.
2. Choose **Other (Custom name)** if prompted.
3. Enter:

```text
AIMS Grade Notification System
```

4. Click **Generate**.
5. Google will display a 16-character password.

Example:

```text
abcd efgh ijkl mnop
```

### Step 4: Use the App Password During Setup

When running:

```bash
aims-notifs setup
```

and prompted for:

```text
Enter your app password (NOT your email account password):
```

paste the generated App Password.

Do **not** enter your normal Gmail password.

### Troubleshooting

If you cannot find the **App passwords** option:

* Ensure 2-Step Verification is enabled.
* App Passwords may be unavailable for some work, school, or managed Google accounts.
* App Passwords are not available when certain advanced security settings are enabled.

---

## Initial Setup

During setup, you will be prompted for:

* AIMS username (roll number, lowercase)
* AIMS password
* Email address
* Email app password

The setup command:

1. Creates a Python virtual environment
2. Installs all required Python packages
3. Installs Playwright Chromium
4. Stores your encrypted configuration
5. Creates the systemd service and timer

Run:

```bash
aims-notifs setup
```

---

## Starting Automatic Monitoring

Enable automatic checks:

```bash
aims-notifs start
```

The application will run every 15 minutes.

---

## Stopping Automatic Monitoring

Stop scheduled checks:

```bash
aims-notifs stop
```

---

## Check Status

View the timer status:

```bash
aims-notifs status
```

---

## Run a Check Immediately

Run the grade checker once without waiting for the next scheduled execution:

```bash
aims-notifs run-now
```

---

## View Logs

View live logs:

```bash
aims-notifs logs
```

Logs are stored in the systemd journal.

Additional commands:

```bash
journalctl --user -u aims-notifs.service
```

View all logs.

```bash
journalctl --user -u aims-notifs.service -n 100
```

View the most recent 100 log entries.

```bash
journalctl --user -u aims-notifs.service -f
```

Follow logs live.

---

## Uninstallation

To completely remove the application:

```bash
aims-notifs uninstall
```

This removes:

* Systemd timer
* Systemd service
* Configuration files
* Virtual environment
* Application files

---

## Directory Layout

```text
~/.aims-notifs/
├── main.py
├── setup.py
├── config.json
├── requirements.txt
└── venv/

~/.config/systemd/user/
├── aims-notifs.service
└── aims-notifs.timer

~/.local/bin/
└── aims-notifs
```

---

## Security Notes

Passwords are not stored in plaintext. They are encrypted before being written to the configuration file.

However, the encryption key is stored locally on the same machine. This protects against casual inspection but should not be considered a substitute for a dedicated secrets manager.

Only install and run this software on machines you trust.

---

## Disclaimer

This project is an unofficial utility and is not directly affiliated with IIT Hyderabad, nor the AIMS platform.

Use at your own risk.
