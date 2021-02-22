#!/bin/bash

USAGE="Usage: create-root-zfs-pool.sh [-h][-nd] [-o property=value] ...
    [-O file-system-property=value] ... [-m mountpoint] [-R root]
    [-t tname] pool vdev ...
Description:    Wrapper for 'zpool create -f' that enforces certain additional
    options that are useful for ZFS root pools. Must be run as root.  See
    script source and zpool(8) man page for more information."

SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})
ETC="$SCRIPT_DIR/../../etc"
LIB="$SCRIPT_DIR/../lib"

# shellcheck disable=SC1090
source "$ETC/bootstrap-zfs-root/conf.sh"
# shellcheck disable=SC1090
source "$LIB/bootstrap-zfs-root/common_functions.sh"

ZFS_RPOOL_CREATION_OPTS="-o ashift=12 -o cachefile=none -o altroot=${ZPOOL_ALTROOT}"
ZFS_RPOOL_TOPLEVEL_DATASET_OPTS="-O compression=lz4 -O recordsize=1M -O acltype=posixacl -O canmount=off \
    -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa -O mountpoint=/"

exit_if_not_root
exit_if_gnu_getopt_not_in_path

declare -a SANITIZED_ZPOOL_ARGS

args="$(getopt -o "dfnm:o:O:R:t:h" -l "help" -- "$@")"
eval set -- "$args"

while true; do
  case $1 in
    -h|--help)
      echo "$USAGE"
      exit 0
      ;;
    -d|-n)
      SANITIZED_ZPOOL_ARGS+=("$1")
      #FIXME: include a warning that -d means "dry run" mode?
      ;;
    -f)# we are already using zpool create -f, just ignore here.
      ;;
    -m)
      if [ "$2" != "/" ]; then
        >&2 echo "Warning: Root pool root dataset mount point must be '/'."
        >&2 echo "Ignoring '-m' flag."
        if ! [[ "$2" =~ ^- ]]; then
          shift
        fi
      fi
      ;;
    -o|-O|-t)
      if [[ "$2" =~ ^- ]]; then
        >&2 echo "Error: Argument expected for '$1' flag.  Exiting."
        exit 1
      fi
      SANITIZED_ZPOOL_ARGS+=("$1" "$2")
      shift
      ;;
    -R)
      >&2 echo "Warning: for compatibility with other scripts on this live image, the pool's"
      >&2 echo "temporary mount point is set to $ZPOOL_ALTROOT.  Ignoring '$1' flag."
      if ! [[ "$2" =~ ^- ]]; then
        shift
      fi
      ;;
    --)
      shift
      break
      ;;
  esac
  shift
done

if ! is_valid_zpool_name_without_spaces "$1"; then
  >&2 echo "Error: '$1' contains characters that are not allowed in a ZFS pool name."
  >&2 echo "$ZPOOL_NAME_ERROR_MSG_PART2"
  exit 1
fi

modprobe zfs
# shellcheck disable=SC2086
zpool create -f $ZFS_RPOOL_CREATION_OPTS $ZFS_RPOOL_TOPLEVEL_DATASET_OPTS "${SANITIZED_ZPOOL_ARGS[@]}" "$@"
