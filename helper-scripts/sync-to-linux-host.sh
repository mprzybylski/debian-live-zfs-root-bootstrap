#!/usr/bin/env bash

USAGE="USAGE: sync-to-linux-host.sh [user@]hostname [/remote/directory/prefix]
Description: rsyncs this project to the remote development host.  If the user
does not specify a remote directory prefix, the user's home directory will be
used"

# detect a '-h' or '--help' and be helpful
for arg in $@
do
    if [[ $arg == '-h' ]] || [[ $arg == '--help' ]]
    then
        >&2 echo "$USAGE"
        exit 0
    fi
done

if [ ${#@} -lt 1 ] || [ ${#@} -gt 2 ]
then
    >&2 echo "ERROR: Wrong number of arguments.

$USAGE

Exiting."
    exit
fi

if [[ `uname -s` == "Darwin" ]]; then
    if [[ "$0" =~ ^/ ]]; then
        PROJECT_PATH=$(dirname $(dirname "$0"))
    else
        PROJECT_PATH="$(dirname $(dirname $(echo "$(pwd)/$0" | sed -e 's,/\./,/,')))"
    fi
else
    >&2 echo "Not running on a Mac development host.
Exiting."
    exit 1
fi

if [ -n "$2" ]
then
    REMOTE_PREFIX=$1:$2/
else
    REMOTE_PREFIX=$1:
fi

set -x
rsync -Pavp\
    --exclude .git\
    --exclude .idea\
    --exclude *.iml\
    --exclude *.iso\
    --exclude *.zsync\
    --exclude .build\
    --exclude binary\
    --exclude cache\
    --exclude chroot\
    ${PROJECT_PATH}/ ${REMOTE_PREFIX}$(basename $PROJECT_PATH)/
