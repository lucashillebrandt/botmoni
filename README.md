# BotMoni
====================

[![Slack](https://img.shields.io/badge/Slack-Integration-34A85A.svg)](https://www.example.com/slack-docs)
[![VirusTotal Integration](https://img.shields.io/badge/VirusTotal-Integration-FF69B4.svg)](https://www.virustotal.com/)
[![SMTP Integration](https://img.shields.io/badge/SMTP-Integration-FF69B4.svg)](https://www.example.com/smtp-docs)

## Description

BotMoni is a plugin designed to monitor one or more websites' uptime, malware, and SSL expiration. It provides a simple and efficient way to keep track of your website's health.

## Commands

The following commands are available:

### Uptime Check

* `botmoni.sh check_uptime <domain> [--verbose]`: Check the uptime of a specific domain.

### SSL Expiration Check

* `botmoni.sh check_ssl_expiration <domain> [--verbose]`: Check the SSL expiration date of a specific domain.

### Malware Check

* `botmoni.sh check_for_malware [<domain>] [--file=<path_to_file>][--email=<email_address>][--skip-email][--skip-slack][--verbose]`: Check for malware on a specific domain or file.

## Virus Total Integration

BotMoni uses [Virus Total](https://www.virustotal.com/) to check for malware. To use this feature, you'll need to:

1. Create an account on Virus Total.
2. Generate an API key (free plan available up to 500 checks per day, no commercial use).
3. Consider supporting their service by upgrading to a paid plan.

## Email Notifications

BotMoni supports sending email notifications using Google SMTP. To set this up:

1. Generate an App password for your Google account (16 characters, no spaces).
2. Follow [these instructions](https://support.google.com/accounts/answer/185833) to create an App password.

## Slack Notifications

BotMoni also supports sending notifications to Slack. To set this up:

1. Create a Slack App and generate an Incoming Webhook.
