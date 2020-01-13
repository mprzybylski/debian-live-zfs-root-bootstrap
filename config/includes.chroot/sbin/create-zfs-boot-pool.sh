#!/bin/bash

# Based on the following procedure:  https://github.com/zfsonlinux/zfs/wiki/Debian-Buster-Root-on-ZFS

# Notes:
#  * The rationale behind a separate boot pool is that it allows the enable feature flags to be limited to only those
#    supported by GRUB

# FIXME: validate pool name, but prohibit whitespace
#             The pool name must begin with a let‐
#             ter, and can only contain alphanumeric characters as well as un‐
#             derscore ("_"), dash ("-"), colon (":"), space (" "), and period
#             (".").

USAGE="Usage:
create-zfs-boot-pool.sh [-h,--help] pool vdev ...
Description:    Wrapper for 'zpool create -f' that enforces a pool
  configuration that is compatible with GRUB. Must be run as root.  See script
  source and the zpool(8) man page for more information."

SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})
ETC="$SCRIPT_DIR/../etc"
LIB="$SCRIPT_DIR/../usr/lib"

# shellcheck disable=SC1090
source "$ETC/bootstrap-zfs-root/conf.sh"
# shellcheck disable=SC1090
source "$LIB/bootstrap-zfs-root/common_functions.sh"

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

exit_if_not_root
exit_if_gnu_getopt_not_in_path

# use getopt to detect, warn on, toss unwanted zpool flags, and detect -h or '--help' and be helpful
# See documentation for the 'set' "BUILTIN" on the bash(1) man page and the getopt(1) man page.
args="$(getopt -o "ho:O:" -l "help" -- "$@")"
eval set -- "$args"

while true; do
  case $1 in
    -h|--help) echo "$USAGE"
      exit 0
      ;;
    -o|-O) >&2 echo "Warning: custom dataset and pool options not allowed for boot pool."
      # Throw out the arg to -o or -O
      if ! [[ $2 =~ ^- ]]; then
        shift
      fi
      ;;
    --) shift
      break
      ;;
  esac
  shift
done

ZFS_BPOOL_NAME="$1"
modprobe zfs
# shellcheck disable=SC2068
zpool create -f -o ashift=12 $ZFS_BPOOL_CREATION_OPTS $ZFS_BPOOL_TOPLEVEL_DATASET_OPTS $@
