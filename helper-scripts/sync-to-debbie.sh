#!/usr/bin/env bash

if [[ `hostname` == "Lunch-Tray.local" ]]; then
    if [[ "$0" =~ ^/ ]]; then
        PROJECT_PATH=$(dirname $(dirname "$0"))
    else
        PROJECT_PATH="$(dirname $(dirname $(dirname $(pwd)/$0)))"
    fi
fi
set -x
rsync -Pavp --delete\
    --exclude .git\
    --exclude .idea\
    --exclude *.iml\
    --exclude *.iso\
    --exclude *.zsync\
    --exclude .build\
    --exclude binary\
    --exclude cache\
    --exclude chroot\
    ${PROJECT_PATH}/ root@debbie-does-linus:$(basename $PROJECT_PATH)/
