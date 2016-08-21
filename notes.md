```
sgdisk --new=2:48:2047 --typecode=2:EF02 --change-name=2:"BIOS boot partition" /dev/sda
```

... and then `grub-install /dev/sda` really did just work

NB:
Also need to install `linux-image-amd64` and `linux-headers-amd64`