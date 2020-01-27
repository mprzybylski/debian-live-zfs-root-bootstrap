# TODO:
* Set up CI build and packer-based end-to-end test.
* Add EFI boot support.
* Streamline bootloader setup.
* Allow non-interactive installation with root SSH public key and no root password?

# Background
This project provides Debian-based live image that is pre-customized for installing a minimal, Debian-based linux distribution to a ZFS root filesystem and making it bootable.  The scripts it provides are based on the following procedure: https://github.com/zfsonlinux/zfs/wiki/Debian-Buster-Root-on-ZFS 

It can be run interactively, or non-interactively with tools like Packer.

If you are interested in forking or contributing to this project, please consider installing the [`live-manual-pdf`](https://packages.debian.org/search?keywords=live-manual-pdf) package and copying the file with your preferred language and page layout from `/usr/share/doc/live-manual/pdf/` to the system where you do most of your programming.  You are likely to be referencing it a lot as you wrap your head around where the bodies are buried in this project.

## Limitations
* (Buster-only)
* (BIOS-boot only, for now)

(FIXME: rewrite around buster)
(FIXME: rewrite around a pre-built image hosted at github)
# Quick-start
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

# Usage

(details on every script and its usage)

# Building
* Clone this project to a debian "buster," or newer, system
* Install `apt-cacher-ng` on your live image build system, if you have not already done so.  This project is currently configured to download packages via a caching proxy at `localhost:3142` to speed up iteration while reducing network usage.
* ***Become root** (this is a gross but unavoidable artifact of Debian's live-build architecture)* 
* If the `live-build` package is not already present on the system `apt-get install live-build`
* Change directories into the project root
* `lb clean --purge && lb build`

# References
* (FIXME: update for buster)
* https://github.com/zfsonlinux/zfs/wiki/Debian-Stretch-Root-on-ZFS
* Linux kernel major and minor device numbering
  * https://www.kernel.org/doc/Documentation/admin-guide/devices.txt (NVMe major number is currently 259)
  * https://www.dell.com/support/article/us/en/04/sln312382/nvme-on-rhel7?lang=en
