#!/bin/bash

#FIXME add a -h option.

USAGE="\
Usage: bootstrap-zfs-debian-root.sh

Installs bootable Debian root filesystem to /mnt.
"

STAGE2_BOOTSTRAP=stage-2-bootstrap.sh
ZFS_TRUST_PACKAGE=zfsonlinux_8_all.deb

sigint_handler(){
    >&2 echo "Caught SIGINT.  Exiting."
    exit
}

cleanup(){
    rm -f /mnt/root/$STAGE2_BOOTSTRAP
    rm -f /mnt/tmp/$ZFS_TRUST_PACKAGE

    umount /mnt/dev/pts
    umount /mnt/dev
    umount /mnt/proc
    umount /mnt/sys/fs/fuse/connections
    umount /mnt/sys

    zpool export -a

    echo "All ZFS pools exported.  Ready for reboot"
}

# if we aren't using a deb-caching proxy, check connectivity to debian's HTTP redirector
if [ -z "$http_proxy" ] && ! curl -IL http://httpredir.debian.org/ >/dev/null 2>&1; then
    >&2 echo "Failed to conect to http://httpredir.debian.org/
Check your network and firewall configurations."
exit 1
fi

zpool export -a
if ! zpool import -a altroot=/mnt; then
    >&2 echo "Failed to export and reimport ZFS pools at /mnt"
    exit 5
fi

mkdir /mnt/dev
mount -o bind /dev/ /mnt/dev
mount -o bind /dev/pts /mnt/dev/pts

mkdir /mnt/proc

mkdir /mnt/sys
mount -o bind /sys /mnt/sys

trap cleanup EXIT
trap sigint_handler INT

if ! apt-get update || ! cdebootstrap jessie /mnt; then
    >&2 echo "Failed to setup root filesystem in $ROOTFS"
    exit 6
fi

mount -o bind /proc /mnt/proc

cp /packages/$ZFS_TRUST_PACKAGE /mnt/tmp

cp /scripts/$STAGE2_BOOTSTRAP /mnt/root/$STAGE2_BOOTSTRAP
chroot /mnt /root/$STAGE2_BOOTSTRAP

# cleanup() called implicitly by exit