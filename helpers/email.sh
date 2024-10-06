#!/bin/bash
# BotMoni
# email.sh - This is a helper script to send emails. We'll only accept sending emails via SMTP.
# Author: Lucas Hillebrandt
# Version: 1.3
# LICENSE: GPLv3

#######################################
# Validates that the required plugins are installed.
# Globals:
#     None
# Arguments:
#     None
# Outputs:
#     Installs required plugins if they are not already installed, and exits with an error code if installation fails.
#######################################
_validate_plugins() {
    # msmtp is used to send emails.
    if [[ ! -f /usr/bin/msmtp && ! -f /usr/local/bin/msmtp ]]; then
        echo "[INFO] - Installing msmtp package."
        sudo apt-get install msmtp -y

        if [[ "$?" -ne 0 ]]; then
            echo "[ERROR] - Could not install msmtp package. Please check your system."
            exit 1
        fi
    fi
}

_validate_plugins

if [[ -z $email_from_name || -z $email_address || -z $email_password || -z $to_email ]]; then
  echo "[ERROR] - Missing environment variables to send emails correctly. Please update your .env file before running this script."
  exit 1
fi

# Import Environment Variables
test ../.env && source ../.env

if [[ ! -f ~/.msmtprc ]]; then
  echo "
  # gmail
  account gmail
  host smtp.gmail.com
  port 587
  protocol smtp
  auth on
  from $email_from_name
  user $email_address
  password $email_password
  tls on
  tls_nocertcheck

  account default : gmail
  " > ~/.msmtprc

  chmod 600 ~/.msmtprc
fi

#######################################
# Send an email to the specified recipient.
# Globals:
#   None
# Arguments:
#   to: Recipient's email address
#   subject: Email subject
#   message: Email body
# Outputs:
#   Writes status to stdout
#######################################
_send_mail() {
  local to
  local subject
  local message

  to="$1"
  subject="$2"
  message="$3"

  email=$(mktemp)

  echo "Subject: $subject" >> $email
  echo "Content-Type: text/html" >> $email
  echo "$message" >> $email

  msmtp $to < $email

  if [[ $? -eq 0 ]]; then
    echo "[SUCCESS] Email was sent successfully."
  else
    echo "[ERROR] Failed to send email, please try again."
  fi
}
