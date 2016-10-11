#!/usr/bin/env bash
#- check_dashing.sh

## Usage: ./check_dashing.sh --histfile [FILE] --warn [SECONDS] --crit [SECONDS]
## 
## Checks the history.yml file to find out when each widget in Dashing was updated and alerts if it's over a threshold.
##
## dashing-nagios scrapes the Nagios web interface using a Ruby library called nagiosharder, and doing so is very slow. It can take around 10 minutes to update 8 widgets on a 15000 service installation. This plugin checks when each widget was last updated according to the history file. The history file is part of dashing-contrib and is mainly used to save status while rebooting, but also allows us to check how long it has been since the last widget updated. The history file is located on the Dashing server so this plugin must be executed via NRPE.
##
##       -H|--histfile Path to history.yml
##       -w|--warn     Value to alert with WARNING status in seconds
##       -c|--crit     Value to alert with CRITICAL status in seconds
##       -h            Show help options.
##       -v            Print version info.
##
## Example
## /usr/local/nagios/libexec/monitoring-plugins/check_dashing.sh --histfile /home/dashing/dashing-nagios/history.yml --warn 3540 --crit 3600

help=$(grep "^## " "${BASH_SOURCE[0]}" | cut -c 4-)
version=$(grep "^#- "  "${BASH_SOURCE[0]}" | cut -c 4-)

while [[ -n "${1:-}" ]]; do
  case "$1" in
    -H | --histfile) shift; HIST_FILE="$1";;
    -w | --warn) shift; WARN="$1";;
    -c | --crit) shift; CRIT="$1";;
    -D | --debug ) DEBUG=1;;
    -h | --help) echo "$help"; exit 3;;
    -v | --version) echo "$version"; exit 3;;
    -* | --* ) echo "Invalid option: $1" >&2; HELP=1;;
  esac
  shift
done

# Failsafe settings
PATH='/sbin:/usr/sbin:/bin:/usr/bin'
set -o noclobber
set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
unalias -a

# A function used in conjunction with bash's "trap" feature in order to exit cleanly and with an appropriate error message.
# It's a function as it allows proper quoting
TRAP_EXIT='3'
trap_exit() {
  echo "${TRAP_MESSAGE}"
  exit "${TRAP_EXIT}"
}
# Set the trap for the rest of the script
trap trap_exit ERR INT TERM

# Update history.yml via dashing-contrib API
TRAP_MESSAGE="DASHING UNKNOWN: failed to update file ${HIST_FILE}|'widgets with expired data'=10widgets;1;1;0;8"
curl -XPOST 'https://localhost/api/history/save' --insecure --silent --max-time 5 > /dev/null 2>&1

TRAP_MESSAGE="DASHING UNKNOWN: Error retrieving file ${HIST_FILE}|'widgets with expired data'=10widgets;1;1;0;8"
EPOCHS="$(cat "${HIST_FILE}" | grep -Po '(?<="updatedAt"\:)[0-9]*(?=\})' | sed '/^$/d')"

CURRENT_EPOCH="$(date +%s)"
WARNS=0
CRITS=0

TRAP_MESSAGE="DASHING UNKNOWN: Error comparing dates|'widgets with expired data'=10widgets;1;1;0;8"
IFS=$'\n'
for EPOCH in ${EPOCHS}; do
  TIME_LAPSED="$(expr ${CURRENT_EPOCH} - ${EPOCH})"
  if [[ ${TIME_LAPSED} -gt ${CRIT} ]]; then
    CRITS=$(expr ${CRITS} + 1)
  elif [[ ${TIME_LAPSED} -gt ${WARN} ]]; then
    WARNS=$(expr ${WARNS} + 1)
  fi
done
unset IFS

TRAP_MESSAGE="DASHING UNKNOWN: Error determining check state|'widgets with expired data'=10widgets;1;1;0;8"
if [[ ${CRITS} -gt 0 ]]; then
  echo "DASHING CRITICAL: ${CRITS} widgets that haven't updated in ${CRIT} seconds|'widgets with expired data'=$(expr ${CRITS} + ${WARNS})widgets;1;1;0;8"
  exit 2 
elif [[ ${WARNS} -gt 0 ]]; then
  echo "DASHING CRITICAL: ${WARNS} widgets that haven't updated in ${WARN} seconds|'widgets with expired data'=$(expr ${CRITS} + ${WARNS})widgets;1;1;0;8"
  exit 1
else
  echo "DASHING OK: all widgets within thresholds.|'widgets with expired data'=$(expr ${CRITS} + ${WARNS})widgets;1;1;0;8"
  exit 0
fi 
