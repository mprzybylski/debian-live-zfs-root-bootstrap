# pre-configuring debian packages

***Note:*** *fields in the ouptut of debconf-get-selections are separated by tab characters.  However, debconf-set-selections allows spaces as field separators.* 

## grub
```
root@sandbox:~# debconf-get-selections | grep grub
grub-pc	grub-pc/install_devices	multiselect	/dev/disk/by-id/ata-VBOX_HARDDISK_VB62393f66-ddd557e4
# Remove GRUB 2 from /boot/grub?
grub-pc	grub-pc/postrm_purge_boot_grub	boolean	false
grub-pc	grub2/kfreebsd_cmdline	string	
grub-pc	grub2/update_nvram	boolean	true
grub-pc	grub-pc/install_devices_empty	boolean	false
grub-pc	grub2/linux_cmdline	string	
grub-pc	grub2/kfreebsd_cmdline_default	string	quiet
grub-pc	grub-pc/hidden_timeout	boolean	false
grub-pc	grub-pc/mixed_legacy_and_grub2	boolean	true
grub-pc	grub-pc/install_devices_disks_changed	multiselect	
grub-pc	grub-pc/chainload_from_menu.lst	boolean	true
grub-pc	grub-pc/install_devices_failed	boolean	false
# /boot/grub/device.map has been regenerated
grub-pc	grub2/device_map_regenerated	note	
grub-pc	grub2/linux_cmdline_default	string	quiet
grub-pc	grub-pc/timeout	string	5
grub-pc	grub-pc/install_devices_failed_upgrade	boolean	true
grub-pc	grub2/force_efi_extra_removable	boolean	false
grub-pc	grub-pc/kopt_extracted	boolean	false
```

```
debconf-set-selections <<GRUB_DEBCONF_SELECTIONS
grub-pc	grub-pc/install_devices	multiselect	$BOOT_DEVICE
grub-pc	grub2/linux_cmdline_default	string
GRUB_DEBCONF_SELECTIONS
```

## zfs-dkms
```
root@sandbox:~# debconf-get-selections | grep zfs
zfs-dkms	zfs-dkms/stop-build-for-32bit-kernel	boolean	true
zfs-dkms	zfs-dkms/note-incompatible-licenses	note	
zfs-dkms	zfs-dkms/stop-build-for-unknown-kernel	boolean	true
```

See-also `debconf-set-selections`

# Notes used to get this project started

```
  lb config --debian-installer false -k amd64 --apt-indices false --apt-recommends false --debootstrap-options "--variant=minbase" --distribution stretch
```
  
**Process:**

* From live root:
* `sgdisk --new=2:48:2047 --typecode=2:EF02 --change-name=2:"BIOS boot partition" /dev/sda`
* Partition drive(s) (wrapper script? Typecodes: BF01:ZFS, BF07:ZFS-EFI (partition 9))
* Create pool (manual)
* Create filesystems and set properties
* export pool
* import pool with -o altroot=/mnt
* configure network
* cdebootstrap /mnt
* mount -o bind /dev, /dev/pts, /sys, /proc in /mnt
* copy zfsonlinux trust package to /mnt/tmp
* From `chroot /mnt /bin/bash --login`
* install zfsonlinux trust package
* apt-get update
* install linux-image-amd64, linux-headers-amd64, lsb-release, build-essential, debian-zfs, gdisk, grub2
* grub-install to pool members
* Configure hostname and /etc/hosts
* Set root password
* From live root:
* Export pool
* Halt
* Remove live CD or USB key
* Restart

```
# TODO: streamline grub legacy bios and efi setup
#root@sandbox:~# debconf-get-selections | grep grub
#...
#grub-pc	grub-pc/install_devices	multiselect	/dev/sda
```

Troubleshooting
`/bin/plymouth could not be executed and failed.` is a red herring.  It really has to do with a broken fstab entry.
mountpoint=legacy wasn't set for the /boot filesystem which has a dedicated line in /etc/fstab