#!/bin/bash
#
# Adds a few custom commands to verify a domain status, like SSL status, uptime and more.
# Author: Lucas Hillebrandt
# Version: 1.0


# Tools required: curl, jq,  TODO: Add an IF to block script execution if needed tools are not installed.

if [[ ! -d ./virus_total/domain ]]; then
  mkdir -p ./virus_total/domain;
fi

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
  domain="$1"

  if [[ -z $domain ]]; then
    echo "[ERROR] - Domain Missing"
    exit 4
  fi

  if [[ -f ./virus_total/"${domain}.json" ]]; then
    find ./virus_total/ -name "${domain}.json" -mtime +1 -delete &> /dev/null
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
	domain="$1"

  # Removed previous scan after 24 hours.
  _maybe_remove_scan_file "$1"

	result_file="./virus_total/domain/${domain}.json"

  if [[ ! -f $result_file ]]; then
	  curl -sS --location "https://www.virustotal.com/api/v3/domains/$domain" --header "x-apikey: $virus_total_api_key" > "$result_file"
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
      fi
    done

    rm "$virus_checks" # Cleanup after looping antiviruses.
  else
    echo "Virus has not been detected on the domain $domain."
  fi

	exit 0
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
        echo -e "monitor.sh check_for_malware <domain> [--verbose]"
        ;;
esac