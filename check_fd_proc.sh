#!/usr/bin/env bash
#- check_fd_proc.sh

## Usage: ./check_fd_proc.sh --grep '[REGULAR EXPRESSION]' --warn [WARN] --crit [CRIT]
## 
## A monitoring plugin for checking how many file descriptors are in use by a certain process.
##
##       -g|--grep     Regular expression used to grep through the output of 'ps aux'
##       -w|--warn     Warning threshold
##       -c|--crit     Critical threshold
##       -D|--debug    Print debug info
##       -h|--help     Show help options.
##       -v|--version  Print version info.
##
## Example
## ./check_fd_proc.sh --grep '[c]arbon' --warn 1000 --crit 10000

# Failsafe settings
LC_ALL=C
PATH='/sbin:/usr/sbin:/bin:/usr/bin'
set -o noclobber
set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
unalias -a

# --help and --version functions
help=$(grep "^## " "${BASH_SOURCE[0]}" | cut -c 4-)
version=$(grep "^#- "  "${BASH_SOURCE[0]}" | cut -c 4-)

# getopts
while [[ -n "${1:-}" ]]; do
  case "$1" in
    -s | --grep) shift; GREP_OPT="$1";;
    -c | --crit) shift; CRIT_OPT="$1";;
    -c | --warn) shift; WARN_OPT="$1";;
    -D | --debug )  DEBUG=1;;
    -h | --help)    echo "$help"; exit 3;;
    -v | --version) echo "$version"; exit 3;;
    -* | --* )      echo "Invalid option: $1" >&2; HELP=1;;
  esac
  shift
done

WARN="${WARN_OPT}"
CRIT="${CRIT_OPT}"

# A function used in conjunction with bash's "trap" feature in order to exit cleanly and with an appropriate error message.
# It's a function as it allows proper quoting
TRAP_EXIT='3'
trap_exit() {
  echo "${TRAP_MESSAGE}"
  exit "${TRAP_EXIT}"
}
# Set the trap for the rest of the script
trap trap_exit ERR INT TERM

# Get first process ID that matches regex
TRAP_MESSAGE="UNKNOWN: failed to get process id"
PROC=$(ps aux | pgrep "${GREP_OPT}" | head -n 1)
[[ -n "${PROC}" ]]; [[ "${PROC}" -eq "${PROC}" ]] # This simply checks if ${PROC} is an integer and if not, triggers the above trap

# Get current FD count for the process
TRAP_MESSAGE="UNKNOWN: failed to count number of file descriptors in use by ${PROC}"
VALUE=$(find "/proc/${PROC}/fd" | wc -l)
[[ -n "${VALUE}" ]]; [[ "${VALUE}" -eq "${VALUE}" ]] 

# Get the soft limit for the process
TRAP_MESSAGE="UNKNOWN: failed to obtain soft limit for used file descriptors for process ${PROC}"
SOFT=$(cat /proc/${PROC}/limits | grep 'Max open files' | tail -c +27 | cut -f 1 -d ' ' )
[[ -n "${SOFT}" ]]; [[ "${SOFT}" -eq "${SOFT}" ]] 

# Get the hard limit for the process
TRAP_MESSAGE="UNKNOWN: failed to obtain hard limit for used file descriptors for process ${PROC}"
HARD=$(cat /proc/${PROC}/limits | grep 'Max open files' | tail -c +27 | grep -P '([0-9]+)' -o | tail -n 1)
[[ -n "${HARD}" ]]; [[ "${HARD}" -eq "${HARD}" ]]

if [[ ${VALUE} -gt ${CRIT} ]]; then
  echo "CRITICAL: ${VALUE} file descriptors in use by process id ${PROC}|'file descriptors'=${VALUE}fd;${WARN};${CRIT};0;${HARD} 'soft limit'=${SOFT} 'hard limit'=${HARD}"
  exit 2
elif [[ ${VALUE} -gt ${WARN} ]]; then
  echo "WARNING: ${VALUE} file descriptors in use by process id ${PROC}|'file descriptors'=${VALUE}fd;${WARN};${CRIT};0;${HARD} 'soft limit'=${SOFT} 'hard limit'=${HARD}"
  exit 1
elif [[ ${VALUE} -le ${WARN} ]]; then
  echo "OK: ${VALUE} file descriptors in use by process id ${PROC}|'file descriptors'=${VALUE}fd;${WARN};${CRIT};0;${HARD} 'soft limit'=${SOFT} 'hard limit'=${HARD}"
  exit 0
else
  echo "UNKNOWN: internal error determining check state"
  exit 3
fi
