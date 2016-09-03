#!/bin/bash

PROGNAME=$(basename $0)
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

OVERWRITE=false
BADOPTS=false

while getopts :fh opt; do
    case "$opt" in
        h)  >&2 echo "$USAGE"
            exit
            ;;
        f)
            OVERWRITE=true
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
    if [ -f "$2" ]; then
        if $OVERWRITE; then
            if ! rm "$2"; then
                >&2 echo "Failed to delete $2.  Exiting."
            fi
            IMAGE_PATH="$2"
        else
            >&2 echo "$2 already exists.  Use -f to overwrite
"
            INPUT_ERRORS=true
        fi
    else
        IMAGE_PATH="$2"
    fi
else
    >&2 echo "Directory '$2' is not writable.
"
    INPUT_ERRORS=true
fi

if [ -n "$3" ]; then
    if ! [[ $2 =~ ^[0-9]+[kmg]$ ]]; then
        >&2 echo "Persistence image size incorrectly specified.
"
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

#Temporary mount point for disk image
TMPMNT=
#Node in /dev where image is attached
DEV_NODE=

platform=`uname -s`

# TODO: add support for Linux... eventually.
case $platform in
    "Darwin")
        darwin_cleanup(){
            if [ -n "DEV_NODE" ] && [ -f $DEV_NODE ]; then
                # unmount
                diskutil umount ${DEV_NODE}s1
                # detach
                hdiutil detach $DEV_NODE
            fi
            # delete intermediate disk image, if it still exists.
            rm -f "$IMAGE_PATH.dmg"
            [ -n "$TMPMNT" ] && rm -rf $TMPMNT
        }
        # create and attach platform native disk image (hdiutil)

        if ! HDIUTIL_ERR=`hdiutil create -size $IMAGE_SIZE -layout GPTSPUD -fs "MS-DOS FAT16" -volname persistence\
            "$IMAGE_PATH".dmg 2>&1`; then
            >&2 echo "Failed to create intermediate, native image $IMAGE_PATH.dmg"
            >&2 echo "$HDIUTIL_ERR"
            exit 1
        fi

        trap darwin_cleanup EXIT

        DEV_NODE=`hdiutil attach -nomount "$IMAGE_PATH.dmg" | awk '{print $1; exit;}'`
        diskutil rename ${DEV_NODE}s1 persistence

        # mount and copy persistence_tree into it
        TMPMNT=`mktemp -d`
        diskutil mount -mountPoint $TMPMNT ${DEV_NODE}s1
        # assumes permissions are already correct in $PERSISTENCE_ROOT
        COPYCMD="sudo cp -a $PERSISTENCE_ROOT/ $TMPMNT"
        echo "About to execute..."
        echo "$COPYCMD"
        echo "...sudo password may be required."
        $COPYCMD
        ls -l $TMPMNT

        # unmount
        diskutil umount ${DEV_NODE}s1
        # detach
        hdiutil detach $DEV_NODE

        # use virtualbox utility to convert native disk image into VirtualBox disk image.
        VBoxManage convertfromraw "$IMAGE_PATH.dmg" "$IMAGE_PATH" --format VDI
    ;;
    *)
        >&2 echo "Only the following platforms are currently supported: MacOS X."
        >&2 echo "$USAGE"
        >&2 echo "Exiting."
        exit 1
    ;;
esac

