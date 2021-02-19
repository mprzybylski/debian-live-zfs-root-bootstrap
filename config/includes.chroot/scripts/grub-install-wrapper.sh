#!/bin/bash

# FIXME: take a list of devices or ask if the user wants to install to all non-cache, non-log leaf vdevs.
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