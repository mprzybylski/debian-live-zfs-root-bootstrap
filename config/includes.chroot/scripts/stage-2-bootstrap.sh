#!/bin/bash --login

ln -s /proc/mounts /etc/mtab
apt-get update
apt-get --assume-yes install linux-image-amd64 linux-headers-amd64 lsb-release build-essential gdisk
dpkg -i /tmp/zfsonlinux_8_all.deb
apt-get update
# FIXME: pre-seed grub2 package configuration somehow
apt-get --assume-yes install debian-zfs zfs-initramfs grub-pc

echo "Set the root password for your newly-installed system."
ROOT_PASSWD_SET=false
while ! $ROOT_PASSWD_SET; do
    if passwd; then
        ROOT_PASSWD_SET=true
    fi
done
