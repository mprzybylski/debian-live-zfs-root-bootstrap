#!/bin/bash

USAGE="Usage: cleanup.sh ...[additional_pool_2] [additional_pool_1] <bootpool>
    <rootpool>
Description: Unmounts the bootstrap chroot's filesystems and exports ZFS pools
in the order that they are specified.  Pools should be exported in the reverse
of the order in which they were imported ending with the boot pool and root
pool."

if [[ "$1" =~ ^(-h)|(--help)$ ]]; then
  echo "$USAGE"
  exit 0
fi

# Parameters: a list of pools in the order that they are to be exported
SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})
CONFDIR="$SCRIPT_DIR/../../etc/bootstrap-zfs-debian-root"

# shellcheck disable=SC1090
source "$CONFDIR/conf.sh"

STAGE2_BOOTSTRAP=stage-2-bootstrap.sh

rm -f "$TARGET_DIRNAME/root/$STAGE2_BOOTSTRAP"

umount "$TARGET_DIRNAME/dev/pts"
umount "$TARGET_DIRNAME/dev"
umount "$TARGET_DIRNAME/proc"
umount "$TARGET_DIRNAME/sys/fs/fuse/connections"
umount "$TARGET_DIRNAME/sys"
umount "$TARGET_DIRNAME/boot/efi"

set -e #Exit with an error immediately if any of the zpool exports fail
for pool in "$@"; do
    zpool export "$pool"
done

echo "All ZFS pools exported.  Ready for reboot"
