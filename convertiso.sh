#! /bin/bash

#converts a regular ISO file to Apple UDRW file for writing to USB
#then flashes then new image to the specified USB device

#check is script has been run as root /sudo
if [[ $UID != 0 ]]; then
	echo "Please run the script as root."
	exit 1
fi

ISOPATH=$1
if [[ ! -f $ISOPATH ]]; then
	echo "ISO not found. Aborting."
	exit 1
fi
DEVPATH=$2
if [[ ! -b $DEVPATH ]]; then
	echo "Device not found. Aborting"
	exit 1
fi
#check if device is USB. Exit if device is not USB.
DEVINFO=$(diskutil info $DEVPATH | grep Protocol)
DEVINFO=$(echo $DEVINFO | cut -d' ' -f2)
if [[ $DEVINFO != "USB" ]]; then
	echo "Non-USB device specified. This is dangerous."
	echo "Aborting."
	exit 1
fi


#convert the ISO to Mac format
hdiutil convert -format UDRW -o ${ISOPATH}.dmg $ISOPATH
#change the ownership of the new file to match the owner of the
#current directory
OWNER=$(ls -dl . | cut -d' ' -f4)
GROUP=$(ls -dl . | cut -d' ' -f6)
chown ${OWNER}:${GROUP} ${ISOPATH}.dmg

#unmount the device target device
if [[ $(mount | grep $DEVPATH) ]]; then
	diskutil unmountdisk $DEVPATH
	#echo "Unmounted $DEVPATH"
	sleep 2
	if [[ $(mount | grep $DEVPATH) ]]; then
		echo "Unable to unmount target device."
		echo "Aborting."
		exit 1
	fi
fi

#add an 'r' to the beginning of the device name 
#rdisk or raw disks write much faster
echo "Writing image to device. This may take a while."
DEVNAME=$(echo $DEVPATH | cut -d'/' -f3)
RDISKPATH="/dev/r$DEVNAME"

#start the image writing process in the background
dd if=${ISOPATH}.dmg of=$RDISKPATH bs=1m &
PID=$(ps | grep dd | grep -v grep)
PID=$(echo $PID | cut -d' ' -f1)

while [[ $(ps | grep $PID | grep -v grep) ]]
do 
	kill -SIGINFO $PID
	sleep 10
done

echo "Finished. You may now eject the disk."
