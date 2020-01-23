#!/bin/bash

# Parameters: a list of pools in the order that they are to be exported
SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})
CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup.sh"
ETC="$SCRIPT_DIR/../../etc"
LIB="$SCRIPT_DIR/../lib"

STAGE2_BOOTSTRAP=stage-2-bootstrap.sh

rm -f /mnt/root/$STAGE2_BOOTSTRAP

umount /mnt/dev/pts
umount /mnt/dev
umount /mnt/proc
umount /mnt/sys/fs/fuse/connections
umount /mnt/sys
# FIXME: https://github.com/zfsonlinux/zfs/pull/7329 may to change the way /var/lib is mounted
# umount /mnt/var/lib

for pool in "$@"; do
    zpool export "$pool"
done

echo "All ZFS pools exported.  Ready for reboot"