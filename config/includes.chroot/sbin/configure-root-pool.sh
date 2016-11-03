#!/bin/bash

#FIXME add a -h option.

USAGE="\
Usage: bootstrap-zfs-debian-root.sh [zfs_pool_name]

Creates a root filesystem in the specified ZFS pool mounts it at /mnt and
installs a base debian system on it.  If no pool is specified, the first pool
in the output of 'zpool list' will be used.
"

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
