#!/bin/bash

USAGE="
Usage: create-efi-data-partition.sh </dev/block_device>

Creates a ZFS EFI partition for ZFS import/export data on the specified block
device at partition 9.

Options:
    -h | --help     Print this help message and exit"

if [ "$1" == '-h' ] || [ "$1" == '--help' ]; then
    >&2 echo "$USAGE"
    exit 1
fi

# include common functions
SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})
LIB="$SCRIPT_DIR/../lib"
source "$LIB/bootstrap-zfs-root/partition_functions.sh"

PARTNUM=9

if [ -n "$1" ] && is_block_device "$1" && ! is_partition "$1"; then
    sgdisk --new=$PARTNUM:-8M:+8M --typecode=$PARTNUM:BF07 --change-name=$PARTNUM:"ZFS EFI partition" "$1"
    partprobe $1
else
    >&2 echo "Error: Argument must be a block device and not a partition."
    >&2 echo "$USAGE"
    exit 1
fi
