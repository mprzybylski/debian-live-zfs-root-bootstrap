
```
lb config --debian-installer false -k amd64 --apt-indices false --apt-recommends false --debootstrap-options "--variant=minbase"
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