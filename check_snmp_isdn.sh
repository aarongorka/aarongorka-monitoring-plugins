#!/usr/bin/env bash
#- check_snmp_isdn.sh

## Usage: check_snmp_isdn.sh [HOSTNAME] [v2c COMMUNITY] [INTERFACE INDEX]
## 
## Checks an interface and reports critical if it is down. Does not report 
## critical if it is dormant.
##
##       -h     Show help options.
##       -v     Print version info.
##
## Example
## ./check_snmp_isdn.sh 10.41.189.1 public 83
##
## To get the interface index, you can run the following command:
## snmpwalk -v 2c -c public '10.41.189.1' 1.3.6.1.2.1.2.2.1.2

help=$(grep "^## " "${BASH_SOURCE[0]}" | cut -c 4-)
version=$(grep "^#- "  "${BASH_SOURCE[0]}" | cut -c 4-)

opt_h() {
  echo "$help"
  exit 3
}

opt_v() {
  echo "$version"
  exit 3
}

while getopts "hv" opt; do
  eval "opt_$opt"
done

# Failsafe settings
unalias -a
PATH='/sbin:/usr/sbin:/bin:/usr/bin'
set -o noclobber
set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# Run the SNMP query to get the interface status
RESULTS="$(snmpget -v 2c -c "$2" "$1" "1.3.6.1.2.1.2.2.1.8.$3")"
SNMPEXIT="$?"

if [[ "${SNMPEXIT}" -ne 0 ]];  then
  echo "CRITICAL: ${RESULTS}"
  exit 3
fi

# Description can either be the index number or a second request will be send
# to get the description
DESCRIPTION="interface #$3"
DESCRIPTION="$(snmpget -v 2c -c "$2" "$1" "1.3.6.1.2.1.2.2.1.2.$3" | grep -Po "(?<=STRING: ).*")"
SNMPCODE=$(echo "${RESULTS}" | grep -Po "(?<=\()[0-9](?=\))")
SNMPSTRING=$(echo "${RESULTS}" | grep -Po "(?<=\: ).*(?=\()")
if [[ "${SNMPCODE}" -eq 2 ]]; then
  echo "CRITICAL: Interface ${DESCRIPTION} down!"
  exit 2
elif [[ "${SNMPCODE}" -eq 6 ]]; then
  echo "CRITICAL: Interface ${DESCRIPTION} not found!"
  exit 2
elif [[ "${SNMPCODE}" -eq 1 ]] || [[ "${SNMPCODE}" -eq 5 ]]; then
  echo "OK: Interface ${DESCRIPTION} is ${SNMPSTRING}"
  exit 0
else
  echo "Unknown error"
  exit 3
fi
