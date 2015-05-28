#!/bin/bash

# mini_image.sh, A simple script that uses rsync to make a minimal image of the current os.
#
# Usage: ./mini_image.sh <filename> <device - optional>
#        ./mini_image.sh backup.img sda
#
# The image can be made on the current device if %used is below ~48%
#    Freesapce is check to see if there is enough room
#
# Using the system during image creation should be keep between none and minimal
#
# Although it is writen for pi folks, other then dependency retrival, it should work on any Linux system
#
# Have A Great Day
# ShorTie  <idiot@dot.com>

args=("$@")
image_name=${args[0]}
sdcard=${args[1]}

echo -e "\nChecking for root .. "
if [ `id -u` != 0 ]; then
    echo "nop"
    echo -e "Ooops, mini_image.sh needs to be run as root !!\n"
    exit 1
else
    echo "Yuppers .. :)~"
fi

if [ "$image_name" = "" ]; then
	echo ""
	echo "usage: mini_image.sh <filename> <device - optional>"
	echo "Example: ./mini_image.sh bakup.img sda"
	exit 0
fi

echo " "
echo "Checking for a 3rd partition"
THIRD_PART=$(fdisk -l $IMAGEFILE | grep 'img3' |  awk '{print $2}')
if [ "$THIRD_PART" != ""  ]; then
  echo " "
  echo "So, So, Sorry .. :(~"
  echo "This script only works on the standard"
  echo "  2 partition systems"
  exit 1
fi

echo "Checking for necessary programs..."
APS=""

echo -n "Checking for file ... "
if [ `which file` ]; then
    echo "ok"
else
    echo "nope"
    APS+="file "
fi

echo -n "Checking for rsync ... "
if [ `which rsync` ]; then
    echo "ok"
else
    echo "nope"
    APS+="rsync "
fi

echo -n "Checking for kpartx ... "
if [ `which kpartx` ]; then
    echo "ok"
else
    echo "nope"
    APS+="kpartx "
fi

echo -n "Checking for dosfstools ... "
if [ `which fsck.vfat` ]; then
    echo "ok"
else
    echo "nope"
    APS+="dosfstools "
fi

if [ "$APS" != "" ]; then
    echo "Ooops, Applications need .. :(~"
    echo $APS
    echo ""
    echo "Would you like me to get them for you ?? (y/n): "
    echo "Default is yes"
	read resp
	if [ "$resp" = "" ] || [ "$resp" = "y" ] || [ "$resp" = "yes" ]; then
        apt-get update
        apt-get -y install $APS
    else
        echo "Needed Application not installed"
        echo "Exiting .. :(~"
        exit 1
    fi
else
    echo "No applications needed .. :)~"
fi   

fail () {
    echo -e "\n\nOh no's, sumfin went wrong\n"
    echo "Cleaning up my mess .. :(~"
    fuser -av sdcard
    fuser -kv sdcard
    umount sdcard/boot
    fuser -k sdcard
    umount sdcard
    kpartx -dv $image_name
    rm -rf sdcard
    rm $image_name
    exit 1
}

start_time=$(date)
start_dir=$PWD
echo -en "\nStart directory "; echo $start_dir
#cd /media

if [ "$sdcard" != "" ]; then
    mount=$(cat /etc/mtab | grep "$sdcard"1  | cut -f 2 -d ' ')
    cd $mount
    
    thingy=$image_name
else
    cd /media
    thingy=$image_name
fi

# df --block-size=1M


echo -e "\nCalculating the size of file needed\n"
boot_blocks=$(df --block-size=1M | grep 'mmcblk0p1' | awk '{print $2}')
root_blocks=$(df --block-size=1M | grep '/dev/root' | awk '{print $3}')
file_size=$(($boot_blocks+$root_blocks+420))
echo -n "Boot blocks  "
echo $boot_blocks
echo -n "Root blocks  "
echo $root_blocks
echo -n "File blocks  "
echo $file_size


#FREE_SPACE=$(df $DEVICE_DIR | grep $DEVICE | awk '{print $4}')
FREE_SPACE=$(df --block-size=1M | grep '/dev/root' | awk '{print $4}')
echo -n "Free blocks  "
echo $FREE_SPACE

if [ "$file_size" -gt "$FREE_SPACE" ]; then
  echo -e"\nSo, So, Sorry .. :(~\n"
  echo "You do not have enough free space to make the image."
  exit 1
else
  echo -e "\nL@@ks like you have enough free space .. :)~"
  echo "Lets go for it...."
fi

# Create image file
echo "Creating a zero-filled file $image_name $file_size mega blocks big"
dd if=/dev/zero of=$thingy  bs=1M  count="$file_size" iflag=fullblock


bb="+"
bb+=$boot_blocks
bb+="M"

# Create partitions
echo -e "\n\nCreating partitions\n"
fdisk_version=$(fdisk -v | grep 2 | cut -d "." -f2)
echo -n "fdisk_version "; echo $fdisk_version
if [ "$fdisk_version" -lt 25 ]; then
fdisk $thingy <<EOF
o
n



$bb
a
1
t
6
n




w
EOF

else

fdisk $thingy <<EOF
o
n



$bb
a
t
6
n




w
EOF

fi

# Set up drive mapper
echo -e "\n\nSetting up kpartx drive mapper for $thingy and define loopback devices for boot & root\n"
loop_device=$(kpartx -av $thingy | grep p2 | cut -d" " -f8 | awk '{print$1}')
echo -n "Loop device is "; echo $loop_device
echo -n "\n\nPartprobing $thingy\n"
partprobe $loop_device
echo ""
bootpart=$(echo $loop_device | grep dev | cut -d"/" -f3 | awk '{print$1}')p1
bootpart=/dev/mapper/$bootpart
rootpart=$(echo $loop_device | grep dev | cut -d"/" -f3 | awk '{print$1}')p2
rootpart=/dev/mapper/$rootpart
echo -n "Boot partition is "
echo $bootpart
echo -n "Root partition is "
echo $rootpart

# Format partitions
echo -e "\nFormating partitions\n"
mkdosfs -n BOOT $bootpart
echo " "
echo "mkfs.ext4 -O ^huge_file  -L Raspbian $rootpart"
echo "y" | mkfs.ext4 -O ^huge_file  -L Raspbian $rootpart && sync
fdisk -l $thingy
echo ""

# Mount
echo "Mounting $thingy"
mkdir -v sdcard
mount -v -o sync $rootpart sdcard
mkdir -v sdcard/boot
mount -v -t vfat -o sync $bootpart sdcard/boot
echo " "

#--force -rltWDEgoptv"
#  rsync -avxHAX


echo -e "\nStarting the filesystem rsync to $WORKING_PATH\n"
echo "(This may take several minutes)..."

rsync -rltWDEgopt --force --progress --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} /* sdcard && sync

umount sdcard/boot
umount sdcard
kpartx -dv $image_name
rm -rf sdcard

if [ "$sdcard" == "" ]; then
    mv -v $image_name $start_dir/$image_name
fi

echo $start_time
echo $(date)
echo " "

exit 0

