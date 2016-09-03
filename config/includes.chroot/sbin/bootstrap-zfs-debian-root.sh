#!/bin/bash

#FIXME add a -h option.

USAGE="\
Usage: bootstrap-zfs-debian-root.sh [zfs_pool_name]

Creates a root filesystem in the specified ZFS pool mounts it at /mnt and
installs a base debian system on it.  If no pool is specified, the first pool
in the output of 'zpool list' will be used.
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

if [ -n "$1" ]; then
    if ! zpool list "$1"; then
        >&2 echo "ZFS pool $1 does not exist, or is not imported"
        exit 2
    fi
    POOL=$1
else
    POOL=`zpool list -H | awk '{print $1; exit}'`
    if [ -z "$POOL" ]; then
        >&2 echo "No ZFS pools available."
        exit 2
    fi
fi

trap cleanup EXIT
trap sigint_handler INT

#  * Create filesystems and set properties
ROOTFS_PARENT=$POOL/ROOT
ROOTFS=$ROOTFS_PARENT/debian-1
if ! zfs list $ROOTFS_PARENT >/dev/null 2>&1; then
    if ! zfs create -o mountpoint=none $ROOTFS_PARENT; then
        >&2 echo "Failed to create ZFS filesystem $ROOTFS_PARENT"
        exit 3
    fi
fi

# just in case filesystem was previously created manually without this property set
zfs set mountpoint=none $ROOTFS_PARENT

if ! zfs list $ROOTFS >/dev/null 2>&1; then
    if ! zfs create $ROOTFS; then
        >&2 echo "Failed to create ZFS filesystem $ROOTFS"
        exit 4
    fi
fi

# just in case pool or filesystem were previously created manually without these properties set
zfs set mountpoint=/ $ROOTFS
zpool set bootfs=$ROOTFS $POOL

# TODO: add code and/or switches for additional filesystem creation before bootstrapping?

zpool export $POOL
if ! zpool import -o altroot=/mnt $POOL; then
    >&2 echo "Failed to export and reimport $POOL at /mnt"
    exit 5
fi

mkdir /mnt/dev
mount -o bind /dev/ /mnt/dev
mount -o bind /dev/pts /mnt/dev/pts

mkdir /mnt/proc

mkdir /mnt/sys
mount -o bind /sys /mnt/sys

if ! apt-get update || ! cdebootstrap jessie /mnt; then
    >&2 echo "Failed to setup root filesystem in $ROOTFS"
    exit 6
fi

mount -o bind /proc /mnt/proc

cp /packages/$ZFS_TRUST_PACKAGE /mnt/tmp

cp /scripts/$STAGE2_BOOTSTRAP /mnt/root/$STAGE2_BOOTSTRAP
chroot /mnt /root/$STAGE2_BOOTSTRAP

# cleanup called implicitly by exit