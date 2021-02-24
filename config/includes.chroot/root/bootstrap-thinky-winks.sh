#!/bin/bash

# Shell script to attempt repeated installs to mike's laptop more quickly

set -e
build-zfs-kernel-modules.sh
modprobe zfs
export http_proxy=http://192.168.1.3:3142
zpool import -afo altroot=/mnt
zfs destroy -r thinky-winks-boot
zfs destroy -r thinky-winks-root
iwctl
dhclient wlp4s0
bootstrap-zfs-root.sh -r thinky-winks-root\
  -b thinky-winks-boot\
  -H thinky-winks\
  -neNR changeme\
  -B /dev/nvme0n1p1\
  -B /dev/nvme1n1p1\
  thinky-winks-scratch
