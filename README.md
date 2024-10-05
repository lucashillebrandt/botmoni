# Monitor Bash Plugin 

This plugin provides a few commands to check domain status, like SSL status, uptime and more.

## Commands

```
monitor.sh check_uptime <domain> [--verbose]
monitor.sh check_ssl_expiration <domain> [--verbose]
monitor.sh check_for_malware <domain> [--verbose]
```

## Virus Total

Currently, to check for malware, we are using [Virus Total](https://www.virustotal.com/). In order to use the malware checks, you will need to create an account with [Virus Total](https://www.virustotal.com/) and create an API key. They offer a free plan up to 500 checks per day. No commercial use. Please consider using a paid version to support their service if you can. 


