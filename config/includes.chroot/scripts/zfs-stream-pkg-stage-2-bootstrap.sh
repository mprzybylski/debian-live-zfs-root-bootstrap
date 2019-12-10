#!/bin/bash --login

# FIXME: update usage and flags.
USAGE="\
Usage: zfs-stream-pkg-stage-2-bootstrap.sh [options]

Installs and pre-configures packages necessary to make the final target
system bootable on a ZFS root.

Options:
TBD
"

BAD_INPUT=false

#FIXME: update flags, as necessary.
while getopts ":nr:b:i:h" option; do
    case $option in
        * )
            >&2 echo "'$OPTARG' is not a recognized option flag."
            BAD_INPUT=true
        ;;
    esac
done

shift $((OPTIND-1))


if $BAD_INPUT; then
    >&2 echo "$USAGE"
    exit 1
fi

# FIXME: do we even need this?
# ln -s /proc/mounts /etc/mtab

# irqbalance gets automatically started by kernel installation and hangs onto file handles in /dev/  Stop it before
# leaving chroot
trap "service irqbalance stop" EXIT



debconf-set-selections <<GRUB_BOOT_ZFS
grub-pc	grub2/linux_cmdline	string	boot=zfs
grub-pc	grub2/linux_cmdline_default	string
GRUB_BOOT_ZFS

debconf-set-selections <<NON_INTERACTIVE_DEBCONF_SELECTIONS
zfs-dkms	zfs-dkms/stop-build-for-32bit-kernel	boolean	true
zfs-dkms	zfs-dkms/note-incompatible-licenses	note
zfs-dkms	zfs-dkms/stop-build-for-unknown-kernel	boolean	true
NON_INTERACTIVE_DEBCONF_SELECTIONS

apt_get_errors=0

# $1:       non_interactive: true | false
# $2...:    package_1 package_2 ... package_n
wrapt_get(){
    # shellcheck disable=SC2068
    DEBIAN_FRONTEND=noninteractive apt-get --assume-yes install $@ || ((apt_get_errors++))
}

apt-get update || ((apt_get_errors++))

wrapt_get locales
locale-gen --purge en_US.UTF-8
update-locale LANG=en_US.UTF-8 LANGUAGE=en_US:en

wrapt_get openssh-server
# ZFS dependencies
wrapt_get linux-image-amd64 linux-headers-amd64 lsb-release build-essential gdisk dkms dpkg-dev

#FIXME: remove when done debugging
echo "Opening a debugging shell..."
/bin/bash

# Must be installed separately becuase ZFS tries to build DKMS modules before the headers package is installed,
# and errors
wrapt_get zfs-initramfs

if [ $apt_get_errors -gt 0 ]; then
    >&2 echo "Failed to install one or more required, stage 2 packages."
    exit 1
fi

# Delete compiled ZFS kernel modules to avoid appearance of GPL / CDDL license violations
dkms remove $(ls -d /usr/src/zfs* | awk -F / '{sub(/-/, "/", $4); print $4}') --all
