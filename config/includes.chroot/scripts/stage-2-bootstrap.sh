#!/bin/bash --login

#FIXME: should take an optional http_proxy argument and poke it into apt.conf.d

ln -s /proc/mounts /etc/mtab

if [ -n "$1" ]; then
    cat >> /etc/apt/apt.conf.d/99caching-proxy <<CACHING_PROXY_CONFIG
Acquire::http { Proxy "$1"; };
CACHING_PROXY_CONFIG
fi

apt_get_errors=0


apt-get update
apt-get --assume-yes install linux-image-amd64 linux-headers-amd64 lsb-release build-essential gdisk vim-tiny\
    || ((apt_get_errors++))
apt-get --assume-yes install spl-dkms || ((apt_get_errors++))
apt-get --assume-yes install zfs-dkms zfs-initramfs || ((apt_get_errors++))
apt-get --assume-yes install grub-pc

if [ $apt_get_errors -gt 0 ]; then
    >&2 echo "Failed to install one or more required, stage 2 packages."
    exit 1
fi

ex -s /etc/default/grub <<UPDATE_DEFAULT_GRUB
%s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="boot=zfs"/
%s/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="boot=zfs"/
wq
UPDATE_DEFAULT_GRUB

if ! update-grub; then
    >&2 echo "'update-grub' failed.  Your system is probably not bootable."
    exit 2
fi

echo "Set the root password for your newly-installed system."
ROOT_PASSWD_SET=false
while ! $ROOT_PASSWD_SET; do
    if passwd; then
        ROOT_PASSWD_SET=true
    fi
done

# irqbalance gets automatically started by kernel installation and hangs onto file handles in /dev/  Stop it before
# leaving chroot
service irqbalance stop
