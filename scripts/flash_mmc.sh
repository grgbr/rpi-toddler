#!/bin/bash -e

################################################################################
# Make bootable SD
# Should be formatted as something like:
#  Device    Boot Start End    Sectors Size Id Type
#  /dev/sdh1      2048  249855 247808  121M  e W95 FAT16 (LBA)
################################################################################

usage()
{
	echo "$(basename $0): FIRMWARE_FILES"
}

if test $# -lt 2; then
	echo "invalid number of arguments"
	usage
	exit 1
fi

declare -a devs
devs=($(lsblk --raw --output NAME,MOUNTPOINT,RM | \
        grep "[^ \t]\+ [^[ \t]\+ 1$" | \
        cut -f 1,2 -d ' '))

echo "Available removable block device for flashing :"
d=0
while test $d -lt ${#devs[@]}; do
	echo -e "\t$((d / 2 + 1)) - ${devs[d]} ${devs[d + 1]}"
	d=$((d + 2))
done
if test ${#devs[@]} -lt 2; then
	echo -e "\tnone"
	exit 1
fi
echo

read -N 1 -p "select device number to flash into : " reply
echo
if ! echo $reply | grep -q '[0-9]\+'; then
	echo "invalid device number selected"
	exit 1
fi
reply=$(((reply - 1) * 2))
if test $reply -ge ${#devs[@]}; then
	echo "invalid device number selected"
	exit 1
fi

dev=/dev/${devs[reply]}
root=${devs[reply + 1]}

if test ! -b "$dev"; then
	echo "$dev: invalid block device"
	exit 1
fi
if test ! -d $root; then
	echo "$root: no such directory"
	exit 1
fi

read -N 1 -p "flash into $dev under $root ? (y,[n]): " reply
echo
if test "$reply" != "y"; then
	echo "aborted"
	exit 1
fi

cp $* $root
umount $root
