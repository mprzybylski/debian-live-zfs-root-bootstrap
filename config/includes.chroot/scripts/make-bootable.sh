#!/bin/bash --login

apt-get update
apt-get --assume-yes install linux-image-amd64 linux-headers-amd64 lsb-release build-essential gdisk
dpkg -i /tmp/zfsonlinux_8_all.deb
apt-get update
# FIXME: pre-seed grub2 package configuration somehow
apt-get --assume-yes install debian-zfs grub2

# Install grub to all non-cache and non-log pool members
for device_name in `zpool list -H -v $POOL | awk '\
{
	while(getline){ # also skips the pool name line
		if($1 ~ /^(log|cache)$/)exit;
		if( $1 !~ /^(mirror|raidz[0-3])$/)print $1""
	}
}'`; do
    grub-install /dev/$device_name
done
update-grub
