#!/bin/bash

#FIXME add a -h option.

USAGE="\
Usage: bootstrap-zfs-debian-root.sh <rootpool> [pooltwo]...

Installs bootable Debian root filesystem to /mnt.
"

DISTRO_NAME=jessie
ROOT_CONTAINER_FS="${1}/ROOT"
ROOTFS="${ROOT_CONTAINER_FS}/debian"
STAGE2_BOOTSTRAP=stage-2-bootstrap.sh

sigint_handler(){
    >&2 echo "Caught SIGINT.  Exiting."
    exit
}

reverse(){
    i=${#@}
        while [ $i -gt 0 ]; do
        echo ${!i}
        ((i--))
    done
}

if [ -z "$1" ]; then
    >&2 echo "Root pool argument required.  Unable to proceed.  Exiting"
    exit 1
fi

# if we aren't using a deb-caching proxy, check connectivity to debian's HTTP redirector
if [ -z "$http_proxy" ] && ! curl -IL http://httpredir.debian.org/ >/dev/null 2>&1; then
    >&2 echo "Failed to conect to http://httpredir.debian.org/
Check your network and firewall configurations."
exit 2
fi

if ! zfs list $ROOT_CONTAINER_FS >/dev/null 2>&1
then
    if ! zfs create -o canmount=off -o mountpoint=none $ROOT_CONTAINER_FS
    then
        >&2 echo "Failed to create $ROOT_CONTAINER_FS. Exiting."
        exit 3
    fi
fi

if ! zfs list $ROOTFS >/dev/null 2>&1
then
    # create rootfs and keep it from complaining that it can't mount to / with
    #   canmount=noauto
    if ! zfs create -o canmount=noauto -o mountpoint=/ $ROOTFS
    then
        >&2 echo "Failed to create $ROOTFS. Exiting."
        exit 4
    fi
fi

zpool set bootfs=$ROOTFS $1

# make sure $ROOTFS mounts at / when we import its pool
zfs set canmount=on $ROOTFS

zpool export -a

for pool in $@; do
    if ! zpool import -o altroot=/mnt $pool; then
        >&2 echo "Failed to export and reimport ZFS pools at /mnt"
        exit 6
    fi
done


# TODO: identify the root pool and add a bios boot partition to each non-cache, non-log leaf vdev

mkdir -p /mnt/etc/zfs
for pool in `zpool list -H | awk '{print $1}'`; do
    zpool set cachefile=/mnt/etc/zfs/zpool.cache $pool
done

mkdir /mnt/dev
mount -o bind /dev/ /mnt/dev
mount -o bind /dev/pts /mnt/dev/pts

mkdir /mnt/proc

mkdir /mnt/sys
mount -o bind /sys /mnt/sys

trap sigint_handler INT

if ! apt-get update || ! cdebootstrap $DISTRO_NAME /mnt; then
    >&2 echo "Failed to setup root filesystem in $ROOTFS"
    exit 4
fi

# copy custom apt and other config files into new root
cp -a /target_config/* /mnt/

mount -o bind /proc /mnt/proc

cp /scripts/$STAGE2_BOOTSTRAP /mnt/root/$STAGE2_BOOTSTRAP
# $http_proxy is an environment variable that (c)debootstrap honors for downloading packages
# if it happens to point to caching proxy like apt-cacher-ng, it can greatly accelerate installs
if ! chroot /mnt /root/$STAGE2_BOOTSTRAP $http_proxy; then
    >&2 echo "Stage 2 bootstrap failed. Exiting"
    exit 5
fi

cleanup.sh $(reverse $@)