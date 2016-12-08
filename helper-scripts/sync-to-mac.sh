#!/usr/bin/env bash

if [[ `hostname` == "debbie-does-linus" ]]; then
    if [[ "$0" =~ ^/ ]]; then
        PROJECT_PATH=$(dirname $(dirname "$0"))
    else
        PROJECT_PATH="$(dirname $(dirname $(echo "$(pwd)/$0" | sed -e 's,/\./,/,')))"
    fi
fi
set -x
rsync -Pavp \
    --exclude .git\
    --exclude .build\
    --exclude binary\
    --exclude cache\
    --exclude chroot*\
    --exclude *.md\
    ${PROJECT_PATH}/ mikep@mac:~/src/debian-live-zfs-root-bootstrap/
