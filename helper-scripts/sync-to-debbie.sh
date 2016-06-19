#!/usr/bin/env bash

if [[ `hostname` == "Lunch-Tray.local" ]]; then
    if [[ "$0" =~ ^/ ]]; then
        PROJECT_PATH=$(dirname $(dirname "$0"))
    else
        PROJECT_PATH="$(dirname $(dirname $(pwd)/$0))"
    fi
fi
set -x
rsync -Pavp\
    --exclude .git\
    --exclude .idea\
    --exclude *.iml\
    ${PROJECT_PATH}/ root@debbie-does-linus:$(basename $PROJECT_PATH)/
