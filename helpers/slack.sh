#!/bin/bash
# BotMoni
# slack.sh - This is a helper script to send Slack notifications.
# Author: Lucas Hillebrandt
# Version: 1.3
# LICENSE: GPLv3

# Import Environment Variables
test ../.env && source ../.env

# Sends a Slack notification to the specified webhook_url about Malwares found during a review.
#
# Globals:
#   None
# Arguments:
#   webhook_url: URL to send the Slack notification to
#   domain: Domain to send the Slack notification about
#
# Outputs:
#   Writes status to stdout
send_slack() {
  local webhook_url
  local domain
  local domain_no_http

  webhook_url="$1"
  domain="$2"
  domain_no_http=${domain#http://}
  domain_no_http=${domain_no_http#https://}

  # Send the Slack notification
  curl -X POST -H 'Content-type: application/json' "$webhook_url" --data-binary @- << EOF
  {
		"blocks": [
			{
				"type": "section",
				"text": {
					"type": "mrkdwn",
					"text": "*[BotMoni] - Malware Monitoring :anger:* "
				}
			},
			{
				"type": "section",
				"fields": [
					{
						"type": "mrkdwn",
						"text": "*Website:*\n $domain "
					},
					{
						"type": "mrkdwn",
						"text": "*Reason:* \n Malware has been detected. Please see instructions below."
					}
				]
			},
			{
				"type": "section",
				"text": {
					"type": "mrkdwn",
					"text": "Please click on the button 'Virus Total' for more information."
				},
				"accessory": {
					"type": "button",
					"text": {
						"type": "plain_text",
						"text": "Virus Total",
						"emoji": true
					},
					"value": "virus_total_url",
					"url": "https://www.virustotal.com/gui/search/$domain_no_http",
					"action_id": "button-action"
				}
			}
		]
	}
EOF
}