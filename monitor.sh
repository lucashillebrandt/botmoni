#!/bin/bash
#
# Adds a few custom commands to verify a domain status, like SSL status, uptime and more.
# Author: Lucas Hillebrandt
# Version: 1.2

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
    # jq is used to parse JSON data.
    if [[ ! -f /usr/bin/jq ]]; then
        echo "[INFO] - Installing jq package."
        sudo apt-get install jq -y

        if [[ "$?" -ne 0 ]]; then
            echo "[ERROR] - Could not install jq package. Please check your system."
            exit 1
        fi
    fi

    # OpenSSL is used to check the SSL status of the domains.
    if [[ ! -f /usr/bin/openssl ]]; then
        echo "[INFO] - Installing openssl package."
        sudo apt-get install openssl -y

        if [[ "$?" -ne 0 ]]; then
            echo "[ERROR] - Could not install openssl package. Please check your system."
            exit 1
        fi
    fi

    # curl is used to check the uptime of the domain and malware status.
    if [[ ! -f /usr/bin/curl ]]; then
        echo "[INFO] - Installing curl package."
        sudo apt-get install curl -y

        if [[ "$?" -ne 0 ]]; then
            echo "[ERROR] - Could not install curl package. Please check your system."
            exit 1
        fi
    fi
}

_validate_plugins

# Import Environment Variables
test .env && source .env

#######################################
# Checks if the site currently is available in the internet.
# Globals:
#   None
# Arguments:
#   Domain to check uptime
# Outputs:
#   Writes status to stdout
#######################################
_check_uptime() {
  domain="$1"

  if [[ -z $domain ]]; then
    echo "[ERROR] - Domain Missing"
    exit 4
  fi

  status_code=$(curl -sSLX GET -o /dev/null -w "%{http_code}\n" --max-time "15" --connect-timeout "10" https://"$domain")

  echo "$status_code"
  exit 0
}

#######################################
# Checks if the site currently has SSL certificate and if it's valid for more than 30 days.
# Globals:
#   None
# Arguments:
#   Domain to SSL Status
#   Port to check the SSL Certificate
# Outputs:
#   Writes SSL status to stdout
#######################################
_check_ssl_expiration() {
  domain="$1"

  if [[ -z $domain ]]; then
    echo "[ERROR] - Domain Missing"
    exit 4
  fi

  #TODO: Make port optional so if customers have SSL installed on different ports and they want to monitor it, they can.

  port="443"
  result=$(echo -n Q | openssl s_client -servername "$domain" -connect "$domain":"$port" 2> /dev/null | openssl x509 -noout -checkend 2592000)

  echo "$result"
  exit 0
}

_check_domain_expiration() {
  domain="$1"

  if [[ -z $domain ]]; then
    echo "[ERROR] - Domain Missing"
    exit 4
  fi

  domain=$(echo "$domain" | egrep -Eo "[^.]*(\.[^.]{2,3}){1,2}$")

  #	whois $domain
  #TODO: There are restricitons on domains .com.br, .br and others due country restrictions. Re-evaluate this feature in the future.
  exit 0

}

#######################################
# Maybe removes scan file from VirusTotal if it's older than 1 day.
# Globals:
#   None
# Arguments:
#   Domain
#######################################
_maybe_remove_scan_file() {
  local domain="$1"


  if [[ -z "$domain" ]]; then
    echo "[ERROR] - Domain Missing"
    exit 4
  fi

  if [[ -f "./virus_total/domain/${domain}.json" ]]; then
    # Check if file is older than 1 day

    if [[ $(find "./virus_total/domain/${domain}.json" -mtime +1) ]]; then

      rm "./virus_total/domain/${domain}.json"
    fi
  fi
}

#######################################
# Checks if the VirusTotal API quota has been exceeded.
# Globals:
#   virus_total_api_key
# Arguments:
#   None
# Outputs:
#   Writes "wait" if the quota has been exceeded
#######################################
_check_virus_total_quota() {
  if [[ -z "$virus_total_api_key" ]]; then
    echo "[ERROR] - Virus Total API Key Missing"
    exit 4
  fi

  local quota
  local quota_dir="./virus_total/quota"
  mkdir -p "$quota_dir"

  local hourly_exhausted_file="$quota_dir/hourly_quota_exhausted"
  local hourly_quota_allowed
  local hourly_quota_used
  local daily_exhausted_file="$quota_dir/daily_quota_exhausted"
  local daily_quota_allowed
  local daily_quota_used

  if [[ -f "$hourly_exhausted_file" && $(find "$hourly_exhausted_file" -mmin +60) ]]; then
    rm "$hourly_exhausted_file"
  fi

  if [[ -f "$daily_exhausted_file" && $(find "$daily_exhausted_file" -mmin +1440) ]]; then
    rm "$daily_exhausted_file"
  fi

  if [[ -f "$hourly_exhausted_file" || -f "$daily_exhausted_file" ]]; then
    echo "wait"
    exit 0
  fi

  # Get the quota
  quota=$(curl -sSX GET "https://www.virustotal.com/api/v3/users/$virus_total_api_key/overall_quotas" \
    --header 'accept: application/json' --header "x-apikey: $virus_total_api_key")

  # Extract the quota information
  hourly_quota_allowed=$(echo "$quota" | jq '.data.api_requests_hourly.user.allowed' | sed 's/"//g')
  hourly_quota_used=$(echo "$quota" | jq '.data.api_requests_hourly.user.used' | sed 's/"//g')
  daily_quota_allowed=$(echo "$quota" | jq '.data.api_requests_daily.user.allowed' | sed 's/"//g')
  daily_quota_used=$(echo "$quota" | jq '.data.api_requests_daily.user.used' | sed 's/"//g')

  if [[ -n "$hourly_quota_allowed" && -n "$hourly_quota_used" && -n "$daily_quota_allowed" && -n "$daily_quota_used" ]]; then
    # If the hourly quota has been exceeded, mark the quota as exhausted
    if [[ "$hourly_quota_used" -eq "$hourly_quota_allowed" ]]; then
      echo "Hourly quota Exhausted: $hourly_quota_used / $hourly_quota_allowed. Daily Quota: $daily_quota_used / $daily_quota_allowed" > "$hourly_exhausted_file"
      echo "wait"
      exit 0
    fi

    # If the daily quota has been exceeded, mark the quota as exhausted
    if [[ "$daily_quota_used" -eq "$daily_quota_allowed" ]]; then
      echo "Daily quota Exhausted: $daily_quota_used / $daily_quota_allowed" > "$daily_exhausted_file"
      echo "wait"
      exit 0
    fi
  fi
}

#######################################
# Checks if the site has been identified with Malware via VirusTotal.
# Globals:
#   None
# Arguments:
#   Domain
# Outputs:
#   Writes malware status to stdout
#######################################
_check_for_malware() {
  domains="$1"

  if [[ -n $arg_file && -f $arg_file ]]; then
    domains=$(cat $arg_file)
  fi

  if [[ -z $domains ]]; then
    echo "[ERROR] - Domain Missing"
    exit 4
  fi

  # shellcheck disable=SC2068
  for domain in ${domains[@]}; do
    # Checks if the directory to store the results exists. If not, create it.
    if [[ ! -d ./virus_total/domain ]]; then
      mkdir -p ./virus_total/domain;
    fi

    # Removed previous scan after 24 hours.
    _maybe_remove_scan_file "$1"
    quota=$(_check_virus_total_quota)

    result_file="./virus_total/domain/${domain}.json"

    if [[ ! -f $result_file ]]; then
      if [[ -n $quota && ! -f $result_file  ]]; then
        echo "[ERROR] Virus Total Quota exceeded. Will not try to check domain. Please try again later."
        exit 5
      fi

      curl -sS --location "https://www.virustotal.com/api/v3/domains/$domain" --header "x-apikey: $virus_total_api_key" > "$result_file"
    fi

    error=$(cat "$result_file" | jq '.error | .code' | sed 's/"//g')

    if [[ -n $error  && $error == "QuotaExceededError" ]]; then
      echo "[ERROR] Virus Total Quota Exceeded Error. Please try again later."

      if [[ -f $result_file ]]; then
        rm $result_file
      fi

      exit 5
    fi

    virus_summary=$(cat "$result_file" | jq '.data | .attributes | .last_analysis_stats')
    malicious=$(echo "$virus_summary" | jq '.malicious' | sed 's/"//g')
    suspicious=$(echo "$virus_summary" | jq '.suspicious' | sed 's/"//g')

    # Checks for the summary result from VirusTotal. If we have Malicious or Suspicious, there is a problem.
    if [[ $malicious -gt 0 || $suspicious -gt 0 ]]; then
      virus_checks=$(mktemp)
      cat "$result_file" | jq '.data | .attributes | .last_analysis_results | .[] | .engine_name + "," + .result' > "$virus_checks"

      # Starts checking Virus status by engine.
      cat "$virus_checks" | while read -r line ; do
        engine=$(echo "$line" | cut -d ',' -f1 | sed 's/"//g')
        status=$(echo "$line" | cut -d ',' -f2 | sed 's/"//g')

        if [[ $status == "malicious" || $status == "suspicious" ]]; then
          echo "The Antivirus $engine has flagged the domain $domain as $status. Please review"
          if [[ -z $arg_skip_email ]]; then
            _send_email "[EMERGENCY] Antivirus $engine has flagged the domain $domain as $status" "The Antivirus $engine has flagged the domain $domain as $status. Please review"
          fi
        fi
      done

      rm "$virus_checks" # Cleanup after looping antiviruses.
    else
      echo "Virus has not been detected on the domain $domain."
    fi
  done
}

#######################################
# Sends an email using the _send_mail function.
# Globals:
#   arg_email: Override recipient's email address
#   to_email: Default recipient's email address
# Arguments:
#   subject: Email subject
#   message: Email body
# Outputs:
#   Writes status to stdout
#######################################
_send_email() {
  local to
  local subject
  local message

  # Load the email.sh script and use the _send_mail function.
  source ./email.sh

  # Get the recipient's email address
  if [[ -n $arg_email ]]; then
    to="$arg_email"
  else
    to="$to_email"
  fi

  # Get the email subject and message
  subject="$1"
  message="$2"

  # Send the email using the _send_mail function.
  _send_mail "$to" "$subject" "$message"
}

_parse_args() {
    args=$(echo "$@" | egrep -o "\-\-(.*)( |=(.*)|$)")

    for arg in ${args[@]}; do
        echo $arg | egrep -q "^--" || continue

        arg=$(echo $arg | sed "s/^--//g" | sed "s/-/_/g")

        if echo $arg | grep -q "="; then
            name=$(echo $arg | cut -d= -f1)
            value=$(echo $arg | cut -d= -f2)
        else
            name=$arg
            value="1"
        fi

        name=$(echo "arg_$name" | sed "s/[^0-9a-zA-Z_]//g")

        eval "$name=\$value"
    done
}

_parse_args $*

[[ -n $arg_verbose ]] && stdout="" || stdout="1> /dev/null"

case "$1" in
    check_uptime)
        eval _check_uptime $2 $stdout
        ;;
    check_ssl_expiration)
        eval _check_ssl_expiration $2 $stdout
        ;;
    check_for_malware)
        eval _check_for_malware $2 $stdout
        ;;
    *)
        echo -e "Usage:\n"
        echo -e "monitor.sh check_uptime <domain> [--verbose]"
        echo -e "monitor.sh check_ssl_expiration <domain> [--verbose]"
        echo -e "monitor.sh check_for_malware [<domain>] [--file=<path_to_file>][--email=<email_address>][--skip-email][--verbose]"
        ;;
esac