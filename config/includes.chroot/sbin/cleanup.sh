#!/bin/bash

# Parameters: a list of pools in the order that they are to be exported

rm -f /mnt/root/$STAGE2_BOOTSTRAP

umount /mnt/dev/pts
umount /mnt/dev
umount /mnt/proc
umount /mnt/sys/fs/fuse/connections
umount /mnt/sys

for pool in $@; do
    zpool export pool
done

echo "All ZFS pools exported.  Ready for reboot"