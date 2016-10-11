#!/usr/bin/env bash
#- check_soap.sh v1 Aaron Gorka 2016

## Usage: ./check_soap.sh --action [STRING] --url [URL] --grep [REGEX] --soap [XML] -warn [INT] --crit [INT]
## 
## Generic plugin to query a SOAP API and retrieve a value embedded in it
##
##       -s|--soap     SOAP request in XML format. Recommend keeping it on one line and surrounding it with single quotes.
##       -a|--action   SOAP action
##       -u|--url      Full URL to send the SOAP request to
##       -w|--warn     Return WARN state when value is above this
##       -c|--crit     Return CRIT state when value is above this
##       -g|--grep     Regular expression passed to 'grep -Po' used to extract a value from the XML output
##       -o|--curlopts Any additional arguments to be passed to cURL, e.g. '--insecure'
##       -D|--debug    Print debug info
##       -h|--help     Show help options.
##       -v|--version  Print version info.
##
## Example
## ./check_soap.sh --action "tsl" --url "http://server1:25086/soap/tsl" --grep '(?<=MessagesWaiting>)[0-9]+(?=</)' --soap '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tn="http://www.topcall.com/XMLSchema/2004/tn" xmlns:mon="http://website.com/Monitor"><soapenv:Header><tn:credentials>cid:123123123234</tn:credentials></soapenv:Header><soapenv:Body><mon:GetMessagesWaiting><mon:Type>ALL</mon:Type></mon:GetMessagesWaiting></soapenv:Body></soapenv:Envelope>' --warn 300 --crit 600

# Failsafe settings
LC_ALL=C
PATH='/sbin:/usr/sbin:/bin:/usr/bin'
set -o noclobber
set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
unalias -a

help=$(grep "^## " "${BASH_SOURCE[0]}" | cut -c 4-)
version=$(grep "^#- "  "${BASH_SOURCE[0]}" | cut -c 4-)

PLUGIN='SOAP'

while [[ -n "${1:-}" ]]; do
  case "$1" in
    -s | --soap) shift; SOAP_REQ="$1";;
    -a | --action) shift; SOAP_ACTION="$1";;
    -u | --url) shift; URL="$1";;
    -w | --warn) shift; WARN="$1";;
    -c | --crit) shift; CRIT="$1";;
    -c | --curlopts) shift; CURL_OPTS="$1";;
    -g | --grep) shift; GREP="$1";;
    -D | --debug )  DEBUG=1;;
    -h | --help)    echo "$help"; exit 3;;
    -v | --version) echo "$version"; exit 3;;
    -* | --* )      echo "Invalid option: $1" >&2; HELP=1;;
  esac
  shift
done

# A function used in conjunction with bash's "trap" feature in order to exit cleanly and with an appropriate error message.
# It's a function as it allows proper quoting
function trap_exit {
  echo "${TRAP_MESSAGE}"
  exit 3
}

TRAP_MESSAGE="${PLUGIN} UNKNOWN: failed to access SOAP API"
trap trap_exit ERR INT TERM
OUTPUT="$(curl --silent --data "${SOAP_REQ}" --header "Content-Type: text/xml;charset=UTF-8" --header "SOAPAction: ${SOAP_ACTION}" "${URL}" ${CURL_OPTS:-})"

TRAP_MESSAGE="${PLUGIN} UNKNOWN: Failed to extract value from response"
trap trap_exit ERR INT TERM
VALUE="$(echo "${OUTPUT}" | grep -Po "${GREP}")"

# You can only compare integers in Bash, so if a non-integer is returned by cURL, the below line will cause the script to exit (due to 'set -o errexit'), triggering the above trap.
TRAP_MESSAGE="${PLUGIN} UNKNOWN: ${VALUE} is not an integer"
trap trap_exit ERR INT TERM
[[ "${VALUE}" -eq "${VALUE}" ]] 

PERFDATA="'messages'=${VALUE}messages;${WARN};${CRIT};;"

if [[ ${VALUE} -ge ${CRIT} ]]; then
  echo "${PLUGIN} CRIT: ${VALUE} messages waiting|${PERFDATA}"
  exit 2
elif [[ ${VALUE} -ge ${WARN} ]]; then
  echo "${PLUGIN} WARN: ${VALUE} messages waiting|${PERFDATA}"
  exit 1
elif [[ ${VALUE} -lt ${WARN} ]]; then
  echo "${PLUGIN} OK: ${VALUE} messages waiting|${PERFDATA}"
  exit 0
else
  echo "${PLUGIN} UNKNOWN: internal error determining check state"
  exit 3
fi
