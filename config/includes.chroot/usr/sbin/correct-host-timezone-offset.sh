#!/bin/bash

USAGE="\
Usage: correct-host-timezone-offset.sh < +hh:mm | -hh:mm >

Correct a virtualizaiton guest's clock when it is set to the local time and the
guest is expecting the virtualized hardware clock to be in UTC.
"

SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})
SIGN=1

# shellcheck disable=SC1090
source "$LIB/bootstrap-zfs-root/common_functions.sh"
exit_if_not_root
exit_if_gnu_getopt_not_in_path

BAD_INPUT=false

LOCAL_UNIXTIME=$(date +%s)

if [ $# -ne 1 ]; then
  >&2 echo "ERROR: Wrong number of arguments detected."
  BAD_INPUT=true
fi

case $1 in
  -h | --help)
    echo "$USAGE"
    exit 0
  ;;
  *)
    if [[ "$1" =~ ^([-+])([0-9][0-9]?):([0-9]{2})$ ]]; then
      if [ "${BASH_REMATCH[1]}" == "-" ]; then
        SIGN=-1
      fi
      OFFSET_HOURS=${BASH_REMATCH[2]}
      OFFSET_MINUTES=${BASH_REMATCH[3]}
    else
      >&2 echo "ERROR: time offset must be specified in the format '+HH:MM' or '-HH:MM'"
      BAD_INPUT=true
    fi
  ;;
esac

if $BAD_INPUT; then
  >&2 echo "$USAGE"
  exit 1
fi

date -u -s @$(( SIGN * (OFFSET_HOURS * 3600 + OFFSET_MINUTES * 60) + LOCAL_UNIXTIME))
