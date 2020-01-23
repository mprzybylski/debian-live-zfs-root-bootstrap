#!/bin/bash

USAGE="
Usage: create-zfs-data-partition.sh </dev/block_device> [size [partition_number]]

Creates a ZFS data partition of the specified size, on the specified block
device, at the specified partition number.

Size is in sectors unless it is suffixed with K,M,G,T, or P.  If no size is
specified, the data partition will fill all available space on the device.

If no partition number is specified, the data partition is created with the
first available partition number.

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

if [ -n "$1" ] && is_block_device "$1" && ! is_partition "$1"; then
    if [ -n "$2" ]; then
        if [[ "$2" =~ ^[0-9]+[KMGTP]?$ ]]; then
            SIZE=$2
        else
            >&2 echo "Error: Partition size argument must be an integer optionally suffixed"
            >&2 echo "with K,M,G,T, or P."
            >&2 echo "$USAGE"
            exit 1
        fi
    else
        SIZE=0
    fi
    if [ -n "$3" ]; then
        if [[ "$3" =~ ^[0-9]+$ ]]; then
                PARTNUM=$3
            else
                >&2 echo "Error: Integer partition number expected after $3"
                >&2 echo "$USAGE"
                exit 1
            fi
    else
        PARTNUM=`get_first_available_partition_number "$1"`
    fi
    sgdisk --new=$PARTNUM:0:+$SIZE --typecode=$PARTNUM:BF01 --change-name=$PARTNUM:"ZFS data partition" "$1"
    partprobe $1
else
    >&2 echo "Error: First argument must be a block device and not a partition."
    >&2 echo "$USAGE"
    exit 1
fi