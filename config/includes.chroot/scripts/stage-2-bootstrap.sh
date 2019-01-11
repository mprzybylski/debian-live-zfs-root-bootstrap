#!/bin/bash --login

# FIXME: add flags for customized network settings, (multiline string that drops straight into file)
USAGE="\
Usage: stage-2-bootstrap.sh [options]

Makes a chroot setup with cdebootstrap bootable.

Options:
  -n                        Non-interactive mode.
  -r <root password>        Root password for the bootstrapped system
  -b <boot device>          Where the GRUB bootloader should be written.  This
                            flag may be used more than once to install to
                            redundant boot devices.
  -i <ipv4_addr/NN | dhcp>  IPv4 address / prefix length or 'dhcp' if the
                            host's network interface should be automatically
                            configured.  Can be specified multiple times for
                            multiple network interfaces.  Address settings will
                            be applied to non-loopback interfaces in the order
                            they appear in the output of 'ip -o -a link'.
"

NON_INTERACTIVE=false
ROOT_PASSWORD=""
BOOT_DEVICES=( )
IPV4_ADDRESSES=( )
BAD_INPUT=false

while getopts ":nr:b:i:h" option; do
    case $option in
        n )
            NON_INTERACTIVE=true
        ;;
        r )
            set -x
            ROOT_PASSWORD="$OPTARG"
            set +x
        ;;
        b )
            BOOT_DEVICES+=( "$OPTARG" )
        ;;
        i )
            IPV4_ADDRESSES+=( "$OPTARG" )
        ;;
        h )
            echo "$USAGE"
            exit 0
        ;;
        * )
            >&2 echo "'$OPTARG' is not a recognized option flag."
            BAD_INPUT=true
        ;;
    esac
done

shift $((OPTIND-1))

# Sanity check: require root password arg in non-interactive mode
if $NON_INTERACTIVE &&  [ -z "$ROOT_PASSWORD" ] && [ -z "$ROOT_PUBLIC_KEY" ]; then
    >&2 echo "A root password or root ssh public key must be specified when running
$0 non-interactively.
"
    BAD_INPUT=true
fi

# Sanity check: grub config pre-seeding required in non-interactive mode
if $NON_INTERACTIVE && [ ${#BOOT_DEVICES[@]} -eq 0 ]; then
    >&2 echo "At least one boot device must be specified when running $0
non-interactively
"
    BAD_INPUT=true
fi

if $BAD_INPUT; then
    >&2 echo "$USAGE"
    exit 1
fi



ln -s /proc/mounts /etc/mtab
# FIXME: https://github.com/zfsonlinux/zfs/pull/7329 may to change the way /var/lib is mounted
# See https://www.freedesktop.org/software/systemd/man/bootup.html and
# the systemd.mount(5) man page for an explanation
cat >> /etc/fstab <<VAR_LIB_MOUNT
$(findmnt -no SOURCE / | cut -d / -f 1)/var/lib /var/lib zfs x-initrd.mount 0 0
VAR_LIB_MOUNT

# irqbalance gets automatically started by kernel installation and hangs onto file handles in /dev/  Stop it before
# leaving chroot
trap "service irqbalance stop" EXIT

debconf-set-selections <<GRUB_BOOT_ZFS
grub-pc	grub2/linux_cmdline	string	boot=zfs
grub-pc	grub2/linux_cmdline_default	string
GRUB_BOOT_ZFS

if $NON_INTERACTIVE; then
    debconf-set-selections <<NON_INTERACTIVE_DEBCONF_SELECTIONS
zfs-dkms	zfs-dkms/stop-build-for-32bit-kernel	boolean	true
zfs-dkms	zfs-dkms/note-incompatible-licenses	note
zfs-dkms	zfs-dkms/stop-build-for-unknown-kernel	boolean	true
NON_INTERACTIVE_DEBCONF_SELECTIONS
fi

apt_get_errors=0

# $1:       non_interactive: true | false
# $2...:    package_1 package_2 ... package_n
wrapt_get(){
    NON_INTERACTIVE_APT=$1
    shift

    if $NON_INTERACTIVE_APT; then
        DEBIAN_FRONTEND=noninteractive apt-get --assume-yes install $@ || ((apt_get_errors++))
    else
        apt-get --assume-yes install $@ || ((apt_get_errors++))
    fi
}

apt-get update || ((apt_get_errors++))

wrapt_get $NON_INTERACTIVE openssh-server
wrapt_get $NON_INTERACTIVE linux-image-amd64 linux-headers-amd64 lsb-release build-essential gdisk dkms
wrapt_get $NON_INTERACTIVE spl-dkms

wrapt_get $NON_INTERACTIVE zfs-dkms zfs-initramfs
wrapt_get $NON_INTERACTIVE grub-pc

if [ $apt_get_errors -gt 0 ]; then
    >&2 echo "Failed to install one or more required, stage 2 packages."
    exit 1
fi

LOOPBACK_IF_NAME=lo

cat > /etc/network/interfaces.d/$LOOPBACK_IF_NAME <<LOOPBACK_CONFIG
auto $LOOPBACK_IF_NAME
iface $LOOPBACK_IF_NAME inet loopback
LOOPBACK_CONFIG

# Get all non-loopback interface names
NETWORK_INTERFACES=( `ip -o -a link | awk '$2 !~ /^lo:/{print substr($2, 1, length($2)-1)}'` )

i=0
while [[ $i -lt ${#NETWORK_INTERFACES[@]} ]]; do
    if [[ -z "${IPV4_ADDRESSES[$i]}" ]] || [[ "${IPV4_ADDRESSES[$i]}" == "dhcp" ]]; then
        cat > /etc/network/interfaces.d/${NETWORK_INTERFACES[$i]} <<DHCP_NETWORK_CONFIG
auto ${NETWORK_INTERFACES[$i]}
iface ${NETWORK_INTERFACES[$i]} inet dhcp
DHCP_NETWORK_CONFIG
    else
        cat > /etc/network/interfaces.d/${NETWORK_INTERFACES[$i]} <<STATIC_NETWORK_CONFIG
auto ${NETWORK_INTERFACES[$i]}
iface ${NETWORK_INTERFACES[$i]} inet static
    address ${IPV4_ADDRESSES[$i]}
STATIC_NETWORK_CONFIG
    fi
    ((i++))
done

grub_errors=0
for device in ${BOOT_DEVICES[@]}; do
    if ! grub-install $device; then
        >&2 echo "'grub-install $device' failed."
        ((grub_errors++))
    fi
done

if [ $grub_errors -gt 0 ]; then
    >&2 echo "Exiting."
    exit 2
fi

if ! update-grub; then
    >&2 echo "'update-grub' failed.  Your system is probably not bootable."
    exit 3
fi

#FIXME: non-interactive root-password setting still broken
set -x
if $NON_INTERACTIVE; then
    if ! echo "root:$ROOT_PASSWORD" | chpasswd; then
        >&2 echo "Failed to set the root password with 'chpasswd'
Exiting."
        exit 4
    fi
else
    echo "Set the root password for your newly-installed system."
    ROOT_PASSWD_SET=false
    while ! $ROOT_PASSWD_SET; do
        if passwd; then
            ROOT_PASSWD_SET=true
        fi
    done
fi
