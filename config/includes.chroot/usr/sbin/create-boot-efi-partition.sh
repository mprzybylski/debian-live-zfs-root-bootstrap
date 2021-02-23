#!/bin/bash

USAGE="
Usage: create-boot-efi-partition.sh </dev/block_device>

Creates a UEFI boot partition for the GRUB bootloader on the specified block
device.

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
    PARTNUM=`get_first_available_partition_number "$1"`
    sgdisk --new=$PARTNUM:1M:+512M --typecode=$PARTNUM:EF00 --change-name=$PARTNUM:"UEFI boot partition" "$1"
    partprobe $1
else
    >&2 echo "Error: Argument must be a block device and not a partition."
    exit 1
fi
