#!/usr/bin/env bash
#- check_or.sh v1 Aaron Gorka 2016

## Usage: ./check_or.sh --hostname HOSTNAME1[,HOSTNAMEn] --command COMMAND
## 
## Run an NRPE command on multiple hosts and exit with the best state. Also returns all STDOUT and all perfdata.
##
##       -H|--hostname A comma-delimited list of hosts to run the command on.
##       -c|--command  The NRPE handler to run
##       -D|--debug    Print debug info
##       -h|--help     Show help options.
##       -v|--version  Print version info.
##
## Example
## ./check_or.sh --hostname 'server1.mydomain.com,server2.mydomain.com' --command 'check_https_google_com'

# Failsafe settings
LC_ALL=C
PATH='/sbin:/usr/sbin:/bin:/usr/bin'
set -o noclobber
#set -o errexit # couldn't find a way to include this
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
    -H | --hostname) shift; EXTHOSTS="$1";;
    -c | --command) shift; COMMAND="$1";;
    -D | --debug )  DEBUG=1;;
    -h | --help)    echo "$help"; exit 3;;
    -v | --version) echo "$version"; exit 3;;
    -* | --* )      echo "Invalid option: $1" >&2; HELP=1;;
  esac
  shift
done

# find where check_nrpe is located, it's different for every package manager
NRPE_EXECUTABLE="$(PATH="${PATH}:/usr/lib64/nagios/plugins:/usr/lib/nagios/plugins:/usr/local/nagios/libexec" which check_nrpe)"

OLDIFS="${IFS}"
IFS=','
for EXTHOST in ${EXTHOSTS};
do
  OUTPUT="$(${NRPE_EXECUTABLE} -H "${EXTHOST}" -t 55 -c "${COMMAND}")"
  OUTPUT_EXIT="$?"
  if [[ ${OUTPUT_EXIT} -eq 0 ]]; then NAGIOS_OKAYS="$(expr ${NAGIOS_OKAYS:-} + 1)"; fi
  if [[ ${OUTPUT_EXIT} -eq 1 ]]; then NAGIOS_WARNS="$(expr ${NAGIOS_WARN:-} + 1)"; fi
  if [[ ${OUTPUT_EXIT} -eq 2 ]]; then NAGIOS_CRITS="$(expr ${NAGIOS_CRITS:-} + 1)"; fi
  if [[ ${OUTPUT_EXIT} -eq 3 ]]; then NAGIOS_UNKNOWNS="$(expr ${NAGIOS_UNKNOWNS:-} + 1)"; fi
  STDOUT="${STDOUT:-}$(echo -e "${OUTPUT}" | sed 's/|.*//g')
"
  PERFDATA="${PERFDATA:-}$(echo -e "${OUTPUT:-}" | grep '|' | sed 's/.*|//g' | sed "s/=/_${EXTHOST}=/g")
" # update the perfdata's series name to include the hostname - otherwise there will be conflicts as perfdata from different hosts will have the same name
done
IFS="${OLDIFS}"

# Remove extra newlines
STDOUT="$(echo "${STDOUT}" | head -c -1)"
PERFDATA="$(echo "${PERFDATA}" | head -c -1)"

echo "${STDOUT}|${PERFDATA}"
if [[ ${NAGIOS_OKAYS:-} -gt 0 ]]; then
  exit 0
elif [[ ${NAGIOS_WARNS:-} -gt 0 ]]; then
  exit 1
elif [[ ${NAGIOS_CRITS:-} -gt 0 ]]; then
  exit 2
elif [[ ${NAGIOS_UNKNOWNS:-} -gt 0 ]]; then
  exit 3
fi
