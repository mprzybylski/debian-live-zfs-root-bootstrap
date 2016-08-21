#!/bin/bash

PROGNAME=$(basename $0)
if [[ $0 =~ ^/ ]]; then
    PROJECT_DIR="$(dirname \"$(dirname \"$0\")\")"
else
# an extra dirname should strip the dot that ends up in $(pwd)/$0
PROJECT_DIR="$(dirname \"$(dirname \"$(dirname \"$(pwd)/$0\")\")\")"
fi
USAGE="\
$PROGNAME:
Creates a disk image with a FAT32 debian live persistance filesystem in the
platform's native disk image format, populates it from the specified
persistence tree root, and converts it to a VirtualBox VDI image.

Usage:  $PROGNAME [options] </path/to/persistence/tree/root>
    </path/to/persistence/image> [persistence_image_size]

Valid unit suffixes for persistence_image_size are k, m, or g, (KiB, MiB, or
GiB).  If no persistence_image_size is specified, the default is 32MiB.

Options:
        -h  Print this help message and exit
        -f  Overwrite /path/to/persistence/image, if it already exists."

OVERWRITE=""
BADOPTS=false

while getopts :fh opt; do
    case "$opt" in
        h)  >&2 echo "$USAGE"
            exit
            ;;
        f)
            # FIXME: need to fix the force / overwrite logic
            OVERWRITE="-ov"
            ;;
        *)
            >&2 echo "Unrecognized option: $OPTARG"
            BADOPTS=true
            ;;
    esac
done
if $BADOPTS; then
    >&2 echo "$USAGE
Exiting."
    exit 1
else
    shift $((OPTIND-1))
fi

# make sure necessary vbox binaries are there
if ! $(which VBoxManage >/dev/null 2>&1); then
    >&2 echo "\
VBoxManage utility is not installed.  Please install the VirtualBox command
line utilities.  Exiting."
    exit 1
fi

INPUT_ERRORS=false

# sanity-check the arguments
if [ ${#@} -lt 2 ] || [ ${#@} -gt 3 ]; then
    >&2 echo "Wrong number of arguments.
"
    >&2 echo "$USAGE"
fi

if [ -d "$1" ]; then
    PERSISTENCE_ROOT="$1"
else
    >&2 echo "Persistence tree root:
$1
is not a directory"
    INPUT_ERRORS=true
fi

if [ -w "$(dirname "$2")" ]; then
    IMAGE_PATH="$2"
else
    >&2 echo "Directory '$2' is not writable.
"
    INPUT_ERRORS=true
fi

if [ -n "$3" ]; then
    if ! [[ $2 =~ ^[0-9]+[kmg]$ ]]; then
        >&2 echo "Persistence image size incorrectly specified."
        INPUT_ERRORS=true
    else
        IMAGE_SIZE=$3
    fi
else
    IMAGE_SIZE=32m
fi

if $INPUT_ERRORS; then
    >&2 echo "$USAGE"
    >&2 echo "
Exiting."
    exit 1
fi

platform=`uname -s`

# TODO: add support for Linux... eventually.
case $platform in
    "Darwin")
        # create and attach platform native disk image (hdiutil)
        hdiutil create -size $IMAGE_SIZE "$IMAGE_PATH".dmg || exit 1
        DEV_NODE=`hdiutil attach -nomount "$IMAGE_PATH.dmg" | awk '{print $1; exit;}'`
        diskutil partitionDisk $DEV_NODE 1 'MS-DOS FAT32' PERSISTENCE 31M

        # mount and copy persistence_tree into it
        TMPMNT=`mktemp -d`
        diskutil mount -mountPoint $TMPMNT ${DEV_NODE}s1
        mount
        hdiutil detach $DEV_NODE
        rm -f "$IMAGE_PATH.dmg"
        exit
        # assumes permissions are already correct in $PERSISTENCE_ROOT
        sudo cp -a "$PERSISTENCE_ROOT/" $TMPMNT

        # unmount
        diskutil umount $DEV_NODE

        # detach
        hdiutil detach $DEV_NODE

        # use virtualbox utility to convert native disk image into VirtualBox disk image.
        VBoxManage convertfromraw "$IMAGE_PATH.dmg" "$IMAGE_PATH" --format VDI
        # delete intermediate disk image, if it still exists.
        rm -f "$IMAGE_PATH.dmg"
    ;;
    *)
        >&2 echo "Only the following platforms are currently supported: MacOS X."
        >&2 echo "$USAGE"
        >&2 echo "Exiting."
        exit 1
    ;;
esac

