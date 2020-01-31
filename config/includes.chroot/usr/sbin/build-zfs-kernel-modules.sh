#!/bin/bash

MOD_MODVER=$(ls -d /usr/src/zfs* | awk -F / '{sub(/-/, "/", $4); print $4}')

dkms add $MOD_MODVER
dkms install $MOD_MODVER
