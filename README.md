# Background
* FIXME: talk about live-manual-pdf

# Building
* Clone this project to a debian box
* ***Become root** (this is a gross but unavoidable artifact of Debian's live-build architecture)* 
* Change directories into the project root
* `lb clean --purge && lb build`

# Usage
* dd the resulting .iso file onto a USB key or connect it to your blank VM and boot it.
* Once booted:
  * Login with
    * User name: `user`
    * Password: `live`
  * `sudo -i` to get root
  * Create root pool with `zpool-create.sh [options] <pool name> <vdev spec>` (i.e. `zpool-create.sh -o ashift=12 foo-pool /dev/sda`) (Run `zpool-create.sh -h` for more useful info.) 
  * Create a BIOS boot partition on your boot drive(s) `create-bios-boot-partition.sh /dev/sda`
  * Create other pools and ZFS data sets as required for your environment
  * `bootstrap-zfs-debian-root.sh <root pool name> [extra-pool-1] [extra-pool-2]...`



# Old Notes used to get this project going

```
sgdisk --new=2:48:2047 --typecode=2:EF02 --change-name=2:"BIOS boot partition" /dev/sda
```

... and then `grub-install /dev/sda` really did just work

NB:
Also need to install `linux-image-amd64` and `linux-headers-amd64`


`http_proxy=http://proxyhost:proxyport` environment variable tells debootstrap to download via a caching proxy

`lb clean --purge && lb build` 
