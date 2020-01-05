#!/bin/bash

USAGE="Usage:
create-zfs-boot-pool.sh [-h] pool vdev ...
Description:    Wrapper for 'zpool create -f' that enforces a pool
  configuration that is compatible with GRUB. Must be run as root.  See script
  source and zpool(8) man page for more information."

SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})
# shellcheck disable=SC1090
source "${SCRIPT_DIR}/bootstrap-zfs-debian-root-constants.sh"

ZFS_BPOOL_CREATION_OPTS="-o ashift=12 -o cachefile=none -o altroot=${TARGET_DIRNAME} -d \
    -o feature@async_destroy=enabled \
    -o feature@bookmarks=enabled \
    -o feature@embedded_data=enabled \
    -o feature@empty_bpobj=enabled \
    -o feature@enabled_txg=enabled \
    -o feature@extensible_dataset=enabled \
    -o feature@filesystem_limits=enabled \
    -o feature@hole_birth=enabled \
    -o feature@large_blocks=enabled \
    -o feature@lz4_compress=enabled \
    -o feature@spacemap_histogram=enabled \
    -o feature@userobj_accounting=enabled \
    -o feature@zpool_checkpoint=enabled \
    -o feature@spacemap_v2=enabled \
    -o feature@project_quota=enabled \
    -o feature@resilver_defer=enabled \
    -o feature@allocation_classes=enabled"

ZFS_BPOOL_TOPLEVEL_DATASET_OPTS="-O acltype=posixacl -O canmount=off -O compression=lz4 -O devices=off \
    -O normalization=formD -O relatime=on -O xattr=sa \
    -O mountpoint=/"

# FIXME: use getopts to detect, warn on, and toss unwanted zpool flags, and detect -h
# detect a '-h' or '--help' and be helpful
for arg in $@
do
    if [[ $arg == '-h' ]] || [[ $arg == '--help' ]]
    then
        >&2 echo "$USAGE"
        exit 0
    fi
done

#FIXME: add root user check

zpool create -f -o ashift=12 -O relatime=on -O canmount=off \
    -O compression=lz4 -O normalization=formD \
    -O mountpoint=/ -R /mnt $@
