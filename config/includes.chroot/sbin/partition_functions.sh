# $1: path to a block device, i.e. /dev/sda
is_block_device(){
    return $(ls -l $1 | awk '{if(substr($1, 1, 1) == "b")print 0;else print 1; exit}')
}

# $1: path to a block device, i.e. /dev/sda
is_partition(){
    return $(ls -l $1 | awk '{if($6==0)print 1;else print 0; exit}')
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