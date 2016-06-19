#!/usr/bin/env bash

if ! $(which $(basename $BASH_SOURCE)>/dev/null); then
    if [[ "$BASH_SOURCE" =~ ^/ ]]; then
        HELPER_PATH=$(dirname $BASH_SOURCE)
    else
        HELPER_PATH=$(dirname $(pwd)/$BASH_SOURCE)
    fi
    export PATH="${PATH}:$HELPER_PATH"
fi
