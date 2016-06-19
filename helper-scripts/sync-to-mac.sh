#!/usr/bin/env bash

if [[ `hostname` == "debbie-does-linus" ]]; then
    if [[ "$0" =~ ^/ ]]; then
        PROJECT_PATH=$(dirname $(dirname "$0"))
    else
        PROJECT_PATH="$(dirname $(dirname $(pwd)/$0))"
    fi
fi
set -x
rsync -Pavp \
    --exclude .git\
    --exclude .build\
    --exclude binary\
    --exclude cache\
    --exclude chroot*\
    ${PROJECT_PATH}/ mikep@mac:~/src/$(basename $PROJECT_PATH)/
