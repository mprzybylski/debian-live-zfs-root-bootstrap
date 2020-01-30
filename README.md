# TODO:
* Set up CI build and packer-based end-to-end test.
* Add EFI boot support.
* Streamline bootloader setup.
* Allow non-interactive installation with root SSH public key and no root password?

# Background
This project provides Debian-based live image that is pre-customized for installing a minimal, Debian-based linux distribution to a ZFS root filesystem and making it bootable.  The scripts it includes are based on [https://github.com/zfsonlinux/zfs/wiki/Debian-Buster-Root-on-ZFS](https://github.com/zfsonlinux/zfs/wiki/Debian-Buster-Root-on-ZFS), and are intended to streamline the procedure as well as making it more repeatable.

It can be run interactively, or non-interactively with tools like Packer.

If you are interested in forking or contributing to this project, please consider installing the [`live-manual-pdf`](https://packages.debian.org/search?keywords=live-manual-pdf) package and copying the file with your preferred language and page layout from `/usr/share/doc/live-manual/pdf/` to the system where you do most of your programming.  You are likely to be referencing it a lot as you wrap your head around where the bodies are buried in this project.

## Limitations
* The scripts included with this image are currently only tested against Debian 10.x, (Buster).
* EFI-based boot setup is not yet supported.

(FIXME: Finish rewriting around a pre-built image hosted at github)
# Virtual-machine-based quick start
* Create a virtual machine with a pair of virtual hard disks:
  * 1GB primary hard disk, (i.e. `/dev/sda`) to host `/boot`
  * Secondary hard disk, (i.e. `/dev/sdb`) at least 8GB in size to host the root filesystem
* Download the live image iso file and connect it to your virtual machine as a virtual CD-ROM
* Once booted:
  * `sudo -i` to get root
  * `build-zfs-kernel-modules.sh` to build the ZFS kernel module with DKMS.
  * Create a ZFS pool to host `/boot` on `/dev/sda`, i.e. `create-zfs-boot-pool.sh my_bootpool /dev/sda`
  * Create a ZFS pool to host `/` on `/dev/sdb`, i.e. `create-zfs-root-pool.sh my_rootpool /dev/sdb`
  * Create a BIOS boot partition on `/dev/sda`, i.e. `create-bios-boot-partition.sh /dev/sda`
  * `bootstrap-zfs-debian-root.sh -r my_rootpool -b my_bootpool -B /dev/sda`
* Shut down the system when `bootstrap-zfs-debian-root.sh` completes.
* Disconnect the iso from your VM
* Restart the newly bootstrapped system

# Usage

## A note on ZFS and disk partitions
In general, it is simpler to let `zpool` partition and use an entire block device.  However, that is frequently unfeasible in computers that only accept a limited number of storage devices, (especially laptops), and/or where one must also carve out an EFI boot partition.

ZFS does allow an administrator to create a pool from a partition, rather than a whole disk, with the following caveats:
* The partition table type must be GPT
* The disk where the ZFS vdev partition resides must include a partition number 9. (Typically, this is located at the end of the disk.)
* Partition 9 must have type code BF07
* Partition 9 must be at least 8MiB in length

`create-zfs-efi-partition.sh` will create a partition 9 at the end of the block device given as its argument that meets the above requirements.

`create-zfs-data-partition.sh` can be used to create one or more ZFS data partitions with the correct type codes.

`build-zfs-kernel-modules.sh` 

## Scripts included with the live image:

### `correct-host-timezone-offset.sh`
```
Usage: correct-host-timezone-offset.sh < +hh:mm | -hh:mm >

Correct a virtualizaiton guest's clock when it is set to the local time and the
guest is expecting the virtualized hardware clock to be in UTC.

The single argument is given as the local time zone's positive or negative
offset in hours and minutes from UTC.
```
Correcting the guest's clock prevents package installations from failing because a recently updated repository's digital signatures are not yet valid.

### `build-zfs-kernel-modules.sh`
Builds the live system's ZFS kernel modules with DKMS.  *(This step is required to allow this project to avoid embroiling itself in unresolved legal questions around distributing compiled, (binary), CDDL-licensed kernel modules in the same `.iso` file as the GPL-licensed linux kernel binary.)*

### `create-bios-boot-partition.sh`
```
Usage: create-bios-boot-partition.sh </dev/block_device>

Creates a bios boot partition for the GRUB bootloader on the specified block
device.

Options:
    -h | --help     Print this help message and exit"
```

### `create-efi-data-partition.sh`
```
Usage: create-efi-data-partition.sh </dev/block_device>

Creates a ZFS EFI partition for ZFS import/export data on the specified block
device at partition 9.

Options:
    -h | --help     Print this help message and exit
```

### `create-zfs-data-partition.sh`
```
Usage: create-zfs-data-partition.sh </dev/block_device> [size [partition_number]]

Creates a ZFS data partition of the specified size, on the specified block
device, at the specified partition number.

Size is in sectors unless it is suffixed with K,M,G,T, or P.  If no size is
specified, the data partition will fill all available space on the device.

If no partition number is specified, the data partition is created with the
first available partition number.

Options:
    -h | --help     Print this help message and exit
```

### `create-zfs-boot-pool.sh`
```
Usage: create-zfs-boot-pool.sh [-h,--help] pool vdev ...
Description:    Wrapper for 'zpool create -f' that enforces a pool
  configuration that is compatible with GRUB. Must be run as root.  See script
  source and the zpool(8) man page for more information.
```

### `create-zfs-root-pool.sh`
```
Usage: create-root-zfs-pool.sh [-h][-nd] [-o property=value] ...
    [-O file-system-property=value] ... [-m mountpoint] [-R root]
    [-t tname] pool vdev ...
Description:    Wrapper for 'zpool create -f' that enforces certain additional
    options that are useful for ZFS root pools. Must be run as root.  See
    script source and zpool(8) man page for more information.
```

### `bootstrap-zfs-debian-root.sh`
```
Usage: bootstrap-zfs-debian-root.sh [options] -r <rootpool> -b <bootpool>
  [additional_pool_1] [additional_pool_2]...

Installs bootable Debian root filesystem to the specified ZFS pool(s). The
administrator may specify additional pools that are also mounted on the
bootstrapped system.

Options:
  -r <zfs pool name>        Root ZFS pool name. (Required.)
  -b <zfs boot pool>        ZFS pool name hosting /boot. (Required.)
  -H <hostname>             Hostname to use for the bootstrapped machine.
                            (Defaults to the lsb_release Distributor ID.)
  -m <URL>                  Debian mirror URL.  (Defaults to
                            http://ftp.us.debian.org/debian/ )
  -n                        Non-interactive mode.
  -R <root password>        Root password for the bootstrapped system
  -k <root ssh public key>  Public key to append to /root/.ssh/authorized_keys
                            on the bootstrapped system.
  -B <boot device>          Block device or partition where the GRUB bootloader
                            should be written.  This flag may be used more than
                            once to install to redundant boot devices.
  -i <ipv4_addr/NN | dhcp>  IPv4 address / prefix length or 'dhcp' if the
                            host's network interface should be automatically
                            configured.  Can be specified multiple times for
                            multiple network interfaces.  Address settings will
                            be applied to non-loopback interfaces in the order
                            they appear in the output of 'ip -o -a link'.
  -h | --help               Print this usage information and exit.
```

### `cleanup.sh`*
```
Usage: cleanup.sh ...[additional_pool_2] [additional_pool_1] <bootpool>
    <rootpool>
Description: Unmounts the bootstrap chroot's filesystems and exports ZFS pools
in the order that they are specified.  Pools should be exported in the reverse
of the order in which they were imported ending with the boot pool and root
pool.
```
\* Most of the time, it is unnecessary to call `cleanup.sh` because is normally called by `bootstrap-zfs-debian-root.sh` at the end of a successful run.  It is documented here because it is useful for resetting the state of a live system after a failed run of `bootstrap-zfs-debian-root.sh`, especially when troubleshooting or testing scenarios.

# Building
* Clone this project to a debian "buster," or newer, system
* Install `apt-cacher-ng` on your live image build system, if you have not already done so.  This project is currently configured to download packages via a caching proxy at `localhost:3142` to speed up iteration while reducing network usage.
* ***Become root** (this is a gross but unavoidable artifact of Debian's live-build architecture)* 
* If the `live-build` package is not already present on the system `apt-get install live-build`
* Change directories into the project root
* `lb clean --purge && lb build`

# References
* https://github.com/zfsonlinux/zfs/wiki/Debian-Buster-Root-on-ZFS
* Linux kernel major and minor device numbering
  * https://www.kernel.org/doc/Documentation/admin-guide/devices.txt (NVMe major number is currently 259)
  * https://www.dell.com/support/article/us/en/04/sln312382/nvme-on-rhel7?lang=en
