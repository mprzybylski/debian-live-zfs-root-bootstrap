# FIXME:

# TODO:
* Test non-interactive mode

# Background
* FIXME: talk about live-manual-pdf

# Building
* Clone this project to a debian "buster," or newer, system
* Install `apt-cacher-ng` on your live image build system, if you have not already done so.  This project is currently configured to download packages via a caching proxy at `localhost:3142` to speed up iteration while reducing network usage.
* ***Become root** (this is a gross but unavoidable artifact of Debian's live-build architecture)* 
* If the `live-build` package is not already present on the system `apt-get install live-build`
* Change directories into the project root
* `lb clean --purge && lb build`

# Usage
* dd the resulting .iso file onto a USB key or connect it to your blank VM and boot it.
* Once booted:
  * `sudo -i` to get root
  * `build-zfs-kernel-modules.sh` to build the ZFS kernel module with DKMS
  * Create root pool with `create-root-zfs-pool.sh [options] <pool name> <vdev spec>` 
  (i.e. `create-root-zfs-pool.sh foo-pool /dev/sda`) (Run `create-root-zfs-pool.sh -h` for more useful info.) 
  * Create a BIOS boot partition on your boot drive(s) (i.e. `create-bios-boot-partition.sh /dev/sda`)
  * Create other pools and ZFS data sets as required for your environment
  * `bootstrap-zfs-debian-root.sh <root pool name> [extra-pool-1] [extra-pool-2]...`
* Shut down the system when `bootstrap-zfs-debian-root.sh` completes.
* Remove the USB key or disconnect the iso from your VM
* Restart the newly bootstrapped system

# References
* https://github.com/zfsonlinux/zfs/wiki/Debian-Stretch-Root-on-ZFS
* Linux kernel major and minor device numbering
  * https://www.kernel.org/doc/Documentation/admin-guide/devices.txt (NVMe major number is currently 259)
  * https://www.dell.com/support/article/us/en/04/sln312382/nvme-on-rhel7?lang=en
