#!/bin/bash

USAGE="Usage:
create-root-zfs-pool.sh [-h][-nd] [-o property=value] ... [-O file-system-property=value]
            ... [-m mountpoint] [-R root] [-t tname] pool vdev ...
Description:    Wrapper for 'zpool create -f' that enforces certain additional
    options that are useful for ZFS root pools. Must be run as root.  See
    script source and zpool(8) man page for more information."

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
