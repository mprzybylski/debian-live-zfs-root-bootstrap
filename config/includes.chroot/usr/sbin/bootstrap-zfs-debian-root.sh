#!/bin/bash

# TODO: add -I flag for IPv6 configuration
# FIXME: add a debug flag

USAGE="\
Usage: bootstrap-zfs-debian-root.sh [options] -r <rootpool> -b <bootpool>
  [additional_pool_1] [additional_pool_2]...

Installs bootable Debian root filesystem to the specified ZFS pool(s). The
administrator may specify additional pools that are also mounted on the
bootstrapped system.

NOTE: bootstrap-zfs-debian-root.sh also honors the http_proxy environment
variable.  One can set http_proxy to point at a caching package proxy like
apt-cacher-ng to speed up this script while reducing Internet bandwidth
consumption.

Options:
  -r <zfs pool name>        Root ZFS pool name. (Required.)

  -b <zfs boot pool>        ZFS pool name hosting /boot. (Required.)

  -H <hostname>             Hostname to use for the bootstrapped machine.
                            (Defaults to the lsb_release Distributor ID.)

  -m <URL>                  Debian mirror URL.  (Defaults to
                            http://ftp.us.debian.org/debian/ )

  -n                        Non-interactive mode.

  -N                        Include non-free packages in installed sources.list

  -R <root password>        Root password for the bootstrapped system

  -k <root ssh public key>  Public key to append to /root/.ssh/authorized_keys
                            on the bootstrapped system.

  -B <boot device>          Block device or partition where the GRUB bootloader
                            should be written.  This flag may be used more than
                            once to install to redundant boot devices.

  -g                        Setup legacy grub bios bootloader.

  -e                        Setup efi grub bootloader.

  -i <ipv4_addr/NN | dhcp>  IPv4 address / prefix length or 'dhcp' if the
                            host's network interface should be automatically
                            configured.  Can be specified multiple times for
                            multiple network interfaces.  Address settings will
                            be applied to non-loopback interfaces in the order
                            they appear in the output of 'ip -o -a link'.

  -h | --help               Print this usage information and exit.
"

SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})
CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup.sh"
CONFDIR="$SCRIPT_DIR/../../etc/bootstrap-zfs-root"
LIB="$SCRIPT_DIR/../lib"
# shellcheck disable=SC1090
source "$LIB/bootstrap-zfs-root/common_functions.sh"
# shellcheck disable=SC1090
source "$LIB/bootstrap-zfs-root/partition_functions.sh"

exit_if_not_root
exit_if_gnu_getopt_not_in_path

DEBIAN_MIRROR="http://ftp.us.debian.org/debian/"
DEBIAN_SUITE=buster
NON_FREE=""
STAGE2_BOOTSTRAP=stage-2-bootstrap.sh

NON_INTERACTIVE=false
ROOT_PASSWORD=""
ROOT_PUBLIC_KEY=""
BOOT_DEVICES=( )
LEGACY_GRUB_BOOT=false
EFI_GRUB_BOOT=false
IPV4_ADDRESSES=( )
BAD_INPUT=false

LOOPBACK_IF_NAME=lo
IMPORT_BOOTPOOL_UNIT_NAME=zfs-import-bootpool.service

args="$(getopt -o "nNegr:R:k:b:B:i:H:m:h" -l "help" -- "$@")"
eval set -- "$args"

while true; do
    case $1 in
      -e )
        EFI_GRUB_BOOT=true
      ;;
      -g )
        LEGACY_GRUB_BOOT=true
      ;;
      -r )
        if [[ "$2" =~ ^- ]]; then
          >&2 echo "Error: Argument expected for '$1' flag"
          BAD_INPUT=true
        else
          if is_valid_zpool_name_without_spaces "$2"; then
            ROOT_POOL="$2"
          else
            >&2 echo "Error: invalid argument to the '$1' flag"
            >&2 echo "$ZPOOL_NAME_ERROR_MSG_PART2"
          fi
          # check for existence of the pool!
          if ! zfs list "$2" >/dev/null 2>&1; then
            >&2 echo "ERROR: ZFS pool '$2' does not exist.  Is there a typo in the pool name?"
            BAD_INPUT=true
          fi
          shift
        fi
      ;;
      -b )
        if [[ "$2" =~ ^- ]]; then
          >&2 echo "Error: Argument expected for '$1' flag"
          BAD_INPUT=true
        else
          if is_valid_zpool_name_without_spaces "$2"; then
            BOOT_POOL="$2"
            BOOT_FS_NAME="$BOOT_POOL/BOOT/debian"
         else
          >&2 echo "Error: invalid argument to the '$1' flag"
          >&2 echo "$ZPOOL_NAME_ERROR_MSG_PART2"
          fi
          # check for existence of the pool!
          if ! zfs list "$2" >/dev/null 2>&1; then
            >&2 echo "ERROR: ZFS pool '$2' does not exist.  Is there a typo in the pool name?"
            BAD_INPUT=true
          fi
          shift
        fi
      ;;
      -n )
        NON_INTERACTIVE=true
      ;;
      -N )
        NON_FREE=non-free
      ;;
      -R )
        if [[ "$2" =~ ^- ]]; then
          >&2 echo "Error: Argument expected for '$1' flag"
          BAD_INPUT=true
        else
          ROOT_PASSWORD="$2"
          shift
        fi
      ;;
      -k )
        if [[ "$2" =~ ^- ]]; then
          >&2 echo "Error: Argument expected for '$1' flag"
          BAD_INPUT=true
        else
          ROOT_PUBLIC_KEY="$2"
          shift
        fi
      ;;
      -B )
        if [[ "$2" =~ ^- ]]; then
          >&2 echo "Error: Argument expected for '$1' flag"
          BAD_INPUT=true
        else
          # FIXME: add uniqueness check to prevent a user from accidentally specifying the same device twice
          if is_block_device "$2"; then
              BOOT_DEVICES+=( "$2" )
          else
              >&2 echo "'$2' is not a block device."
              BAD_INPUT=true
          fi
          shift
        fi
      ;;
      -h|--help)
          echo "$USAGE"
          exit 0
      ;;
      -i)
        if [[ "$2" =~ ^- ]]; then
          >&2 echo "Error: Argument expected for '$1' flag"
          BAD_INPUT=true
        else
          if [[ "$2" =~ ^dhcp|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[1-3]?[0-9]$ ]] ; then
              IPV4_ADDRESSES+=( "$2" )
          else
              >&2 echo "'$2' is not 'dhcp' or in address/prefix-length format, i.e. 87.65.53.9/24"
              BAD_INPUT=true
          fi
          shift
        fi
      ;;
      -H)
        if [[ "$2" =~ ^- ]]; then
          >&2 echo "Error: Argument expected for '$1' flag"
          BAD_INPUT=true
        else
          #Validate hostname according to RFC1123
          if [[ "$2" =~ ^[A-Za-z0-9][-A-Za-z0-9]* ]] && ! [[ "$2" =~ -$ ]]; then
            TARGET_HOSTNAME=$2
          else
            >&2 echo "Error: '$2' is not an RFC1123-compliant hostname."
            BAD_INPUT=true
          fi
          shift
        fi
      ;;
      -m)
        if [[ "$2" =~ ^- ]]; then
          >&2 echo "Error: Argument expected for '$1' flag"
          BAD_INPUT=true
        else
          #Validate hostname according to RFC1123
          if [[ "$2" =~ ^https?://[A-Za-z0-9][-A-Za-z0-9.]*/ ]]; then
            DEBIAN_MIRROR="$2"
          else
            >&2 echo "Error: '$2' is does not appear to be a valid debian mirror URL."
            BAD_INPUT=true
          fi
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

if [ "$BOOT_POOL" == "$ROOT_POOL" ]; then
  >&2 echo "ERROR: The ZFS pool hosting /boot must be separate from the pool hosting /, and
only grub-compatible ZFS pool features may be enabled for the /boot pool."
  BAD_INPUT=true
fi

if $LEGACY_GRUB_BOOT && $EFI_GRUB_BOOT; then
  >&2 echo "ERROR: Legacy grub boot and EFI grub boot flags, (-e and -g) are mutually
exclusive."
  BAD_INPUT=true
fi

if ! $LEGACY_GRUB_BOOT && ! $EFI_GRUB_BOOT; then
  >&2 echo "ERROR: Please specify -e for EFI bootloader installation or -g for legacy grub
BIOS bootloader installation."
  BAD_INPUT=true
fi

if [ -z "$ROOT_POOL" ]; then
    >&2 echo "Root pool not specified.  Unable to proceed."
    BAD_INPUT=true
fi

if [ -z "$BOOT_POOL" ]; then
    >&2 echo "Boot pool not specified.  Unable to proceed."
    BAD_INPUT=true
fi

# Sanity check: require root password arg in non-interactive mode
if $NON_INTERACTIVE &&  [ -z "$ROOT_PASSWORD" ]; then
    >&2 echo "Error: A root password must be specified when running $0
    non-interactively."
    BAD_INPUT=true
fi

# Sanity check: require user to specify at least one boot device.
if [ ${#BOOT_DEVICES[@]} -eq 0 ]; then
    >&2 echo "Error: At least one boot device must be specified.
"
    BAD_INPUT=true
fi

if $BAD_INPUT; then
    >&2 echo "$USAGE"
    exit 1
fi

mkdir -p "$CONFDIR"
echo "TARGET_DIRNAME='$(mktemp -d)'" >> "$CONFDIR/conf.sh"
source "$CONFDIR/conf.sh"

# pass trailing arguments from the command line ( "$@" )
gen_stage2_command(){
  echo -n "chroot ${TARGET_DIRNAME} /root/$STAGE2_BOOTSTRAP -r $ROOT_POOL -b $BOOT_POOL -c $TARGET_DIRNAME"
  $LEGACY_GRUB_BOOT && echo -n " -g"
  $EFI_GRUB_BOOT && echo -n " -e"
  $NON_INTERACTIVE && echo -n " -n"
  [ -n "$ROOT_PASSWORD" ] && echo -n " -R $ROOT_PASSWORD"

  i=0
  while [ $i -lt ${#BOOT_DEVICES[@]} ]; do
    echo -n " -B ${BOOT_DEVICES[$i]}"
    ((i++))
  done
  if [ $# -gt 0 ]; then
    echo -n ' ' "${@}"
  fi
}

sigint_handler(){
  >&2 echo "Caught SIGINT.  Exiting."
  "$CLEANUP_SCRIPT" "${POOLS_TO_EXPORT[@]}"
  exit
}

reverse(){
  i=${#@}
    while [ $i -gt 0 ]; do
    echo "${!i}"
    ((i--))
  done
}

# validate debian mirror with curl -IL with or without caching proxy.
INRELEASE_URL="$DEBIAN_MIRROR/dists/$DEBIAN_SUITE/InRelease"
if ! curl -IL "$INRELEASE_URL" >/dev/null 2>&1; then
  >&2 echo "HTTP HEAD $INRELEASE_URL failed."
  >&2 echo "Check your network and firewall configurations."
  if [ -n "$http_proxy" ]; then
    >&2 echo "Make sure the proxy at $http_proxy is functioning correctly."
  fi
exit 2
fi

i=0

set -x
zpool export -a

# shellcheck disable=SC2012
if [[ $(ls -1 "$TARGET_DIRNAME" | wc -l) -gt 0 ]]; then
  >&2 echo "ERROR: chroot directory '$TARGET_DIRNAME' is not empty.
This will prevent $ROOT_POOL/ROOT/debian from mounting properly.
Exiting."
  exit 1
fi

# FIXME: add zpool import flags and other logic to handle these datasets already existing
zpool import -o altroot=${TARGET_DIRNAME} -o cachefile=none "$ROOT_POOL"
zpool import -o altroot=${TARGET_DIRNAME} -o cachefile=none "$BOOT_POOL"

zfs create -o canmount=off -o mountpoint=none "$ROOT_POOL/ROOT"
zfs create -o canmount=off -o mountpoint=none "$BOOT_POOL/BOOT"

zfs create -o canmount=noauto -o mountpoint=/ "$ROOT_POOL/ROOT/debian"
zfs mount "$ROOT_POOL/ROOT/debian"

zfs create -o canmount=noauto -o mountpoint=/boot "$BOOT_FS_NAME"
zfs mount "$BOOT_FS_NAME"
set +x

zfs create                                 "$ROOT_POOL/home"
zfs create -o mountpoint=/root             "$ROOT_POOL/home/root"
zfs create -o canmount=off                 "$ROOT_POOL/var"
zfs create -o canmount=off                 "$ROOT_POOL/var/lib"
zfs create                                 "$ROOT_POOL/var/log"
zfs create                                 "$ROOT_POOL/var/spool"
zfs create -o com.sun:auto-snapshot=false  "$ROOT_POOL/var/cache"
zfs create -o com.sun:auto-snapshot=false  "$ROOT_POOL/var/tmp"
chmod 1777 "${TARGET_DIRNAME}/var/tmp"
zfs create                                 "$ROOT_POOL/opt"
zfs create -o canmount=off                 "$ROOT_POOL/usr"
zfs create                                 "$ROOT_POOL/usr/local"


if [ $# -gt 0 ]; then
  POOLS_TO_EXPORT=("$(reverse "$@")")
fi
POOLS_TO_EXPORT+=("$BOOT_POOL" "$ROOT_POOL")

trap sigint_handler INT

# import any additional user-specified ZFS pools
for pool in "$@"; do
    if ! zpool import -o altroot=${TARGET_DIRNAME} -o cachefile=none "$pool"; then
        >&2 echo "Failed to export and reimport ZFS pools at ${TARGET_DIRNAME}"
        exit 6
    fi
done

mkdir "${TARGET_DIRNAME}/dev"
mount -o bind /dev/ "${TARGET_DIRNAME}/dev"
mount -o bind /dev/pts "${TARGET_DIRNAME}/dev/pts"

mkdir "${TARGET_DIRNAME}/proc"
# mount after cdebootstrap

mkdir "${TARGET_DIRNAME}/sys"
mount -o bind /sys "${TARGET_DIRNAME}/sys"

if ! cdebootstrap $DEBIAN_SUITE "${TARGET_DIRNAME}" "${DEBIAN_MIRROR}"; then
    >&2 echo "Failed to setup root filesystem in $ROOT_POOL"
    exit 4
fi

# copy custom apt and other config files into new root
cp -a /target_config/* "${TARGET_DIRNAME}/"

cat > "$TARGET_DIRNAME/etc/apt/sources.list" <<SOURCES_DOT_LIST
deb [arch=i386,amd64] $DEBIAN_MIRROR $DEBIAN_SUITE main contrib $NON_FREE
deb-src $DEBIAN_MIRROR $DEBIAN_SUITE main contrib

deb [arch=i386,amd64] http://security.debian.org/debian-security $DEBIAN_SUITE/updates main contrib $NON_FREE
deb-src http://security.debian.org/debian-security $DEBIAN_SUITE/updates main contrib

# buster-updates, previously known as 'volatile'
deb [arch=i386,amd64] $DEBIAN_MIRROR $DEBIAN_SUITE-updates main contrib $NON_FREE
deb-src $DEBIAN_MIRROR $DEBIAN_SUITE-updates main contrib

# buster backports:
deb [arch=i386,amd64] http://deb.debian.org/debian buster-backports main contrib $NON_FREE
SOURCES_DOT_LIST

if [ -n "$ROOT_PUBLIC_KEY" ]; then
    AUTH_KEYFILE="${TARGET_DIRNAME}/root/.ssh/authorized_keys"
    SSH_CONFDIR=$(dirname "$AUTH_KEYFILE")
    mkdir -pm 700 $SSH_CONFDIR
    cat > "$AUTH_KEYFILE" <<< "$ROOT_PUBLIC_KEY"
    chmod 600 "$AUTH_KEYFILE"
fi

# enable mounting of /boot at the correct time
zfs set mountpoint=legacy $BOOT_FS_NAME
cat > "${TARGET_DIRNAME}/etc/systemd/system/$IMPORT_BOOTPOOL_UNIT_NAME" <<ZFS_IMPORT_BOOTPOOL_DOT_SERVICE
[Unit]
    DefaultDependencies=no
    Before=zfs-import-scan.service
    Before=zfs-import-cache.service

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=/sbin/zpool import -N -o cachefile=none "${BOOT_POOL}"

    [Install]
    WantedBy=zfs-import.target
ZFS_IMPORT_BOOTPOOL_DOT_SERVICE

cat >> "${TARGET_DIRNAME}/etc/fstab" <<BOOT_FS_SPEC
$BOOT_FS_NAME /boot zfs nodev,relatime,x-systemd.requires=$IMPORT_BOOTPOOL_UNIT_NAME 0 0
BOOT_FS_SPEC

cat > "${TARGET_DIRNAME}/etc/network/interfaces.d/$LOOPBACK_IF_NAME" <<LOOPBACK_CONFIG
auto $LOOPBACK_IF_NAME
iface $LOOPBACK_IF_NAME inet loopback
LOOPBACK_CONFIG

# Get all non-loopback interface names
NETWORK_INTERFACES=( `ip -o -a link | awk '$2 !~ /^lo:/{print substr($2, 1, length($2)-1)}'` )

i=0
while [[ $i -lt ${#NETWORK_INTERFACES[@]} ]]; do
    if [[ -z "${IPV4_ADDRESSES[$i]}" ]] || [[ "${IPV4_ADDRESSES[$i]}" == "dhcp" ]]; then
        cat > "${TARGET_DIRNAME}/etc/network/interfaces.d/${NETWORK_INTERFACES[$i]}" <<DHCP_NETWORK_CONFIG
auto ${NETWORK_INTERFACES[$i]}
iface ${NETWORK_INTERFACES[$i]} inet dhcp
DHCP_NETWORK_CONFIG
    else
        cat > "${TARGET_DIRNAME}/etc/network/interfaces.d/${NETWORK_INTERFACES[$i]}" <<STATIC_NETWORK_CONFIG
auto ${NETWORK_INTERFACES[$i]}
iface ${NETWORK_INTERFACES[$i]} inet static
    address ${IPV4_ADDRESSES[$i]}
STATIC_NETWORK_CONFIG
    fi
    ((i++))
done

mount -o bind /proc "${TARGET_DIRNAME}/proc"
cp /scripts/$STAGE2_BOOTSTRAP "${TARGET_DIRNAME}/root/$STAGE2_BOOTSTRAP"
# $http_proxy is an environment variable that (c)debootstrap honors for downloading packages
# if it happens to point to caching proxy like apt-cacher-ng, it can greatly accelerate installs

# shellcheck disable=SC2091
>&2 echo "DEBUG: Stage 2 bootstrap command:
$(gen_stage2_command "$@")"
# shellcheck disable=SC2091
if ! $(gen_stage2_command "$@"); then
    >&2 echo "Stage 2 bootstrap failed. Exiting"
    exit 5
fi

"$CLEANUP_SCRIPT" "${POOLS_TO_EXPORT[@]}"
set +x