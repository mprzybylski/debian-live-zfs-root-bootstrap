#@IgnoreInspection BashAddShebang

# Reference on device node major and minor numbers:
# https://www.kernel.org/doc/Documentation/admin-guide/devices.txt


# $1: path to a block device, i.e. /dev/sda
is_block_device(){
    return $(ls -l $1 | awk '{if(substr($1, 1, 1) == "b")print 0;else print 1; exit}')
}

# $1: path to a block device, i.e. /dev/sda
is_partition(){
    return $(ls -l $1 | awk '
        # major number 8, ($5) is a SCSI device
        # minor numbers for whole drives are multiples of 16
        $5 ~ /^8,$/{if(($6%16)!=0)print 0;else print 1; exit}
        # Add matching schemes for other major numbers and device types
        # above this comment, as needed.
    ')
}

# $1: path to a block device, i.e. /dev/sda
get_first_available_partition_number(){
    i=1
    for partnum in `sgdisk -p "$1" | awk '/^Number/{while(getline)print $1}'`; do
        # Partition 9 reserved for ZFS import/export data
        if [ $i -eq $partnum ] || [ $i -eq 9 ]; then
            ((i++))
        else
            break
        fi
    done
    echo $i
}