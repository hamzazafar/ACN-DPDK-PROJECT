#!/bin/bash

DEVS=("eth1" "eth2" "eth3")                                                     
GIT_URL=acn@git.net.in.tum.de:framework
FRAMEWORK=~/framework
DPDK_PATH=$FRAMEWORK/dpdk
MNT_DIR=/mnt/huge
IGB_UIO_PATH=$DPDK_PATH/build/kmod/igb_uio.ko
PAGE_2MB=/sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages

#clone framework
if [ ! -d ~/framework ]; then
	echo "Cloning from : $GIT_URL"
	git clone  $GIT_URL $FRAMEWORK
	
	#compile DPDK
	cd $DPDK_PATH
	make config T=x86_64-native-linuxapp-gcc && \
	make T=x86_64-native-linuxapp-gcc
	echo "DPDK is compiled"
fi

#load moudules
grep -q "uio" /proc/modules > /dev/null
if [ $? -ne "0" ]; then
	modprobe uio || { echo 'Failed to load uio' ; exit 1; }
	echo "Loaded uio"
else
	echo "uio is already loaded"
fi

grep -q "igb_uio" /proc/modules > /dev/null
if [ $? -ne 0 ]; then
	insmod $IGB_UIO_PATH || { echo 'failed to load igb_uio' ; exit 1; }
	echo "Loaded igb_uio"
else
	echo "igb_uio is already loaded"
fi

#bind interfaces 
for DEV in "${DEVS[@]}"
do
	if [[ $(python $DPDK_PATH/tools/dpdk-devbind.py -s | grep $DEV | \
		awk -F'[= ]' '{printf $8}') == "virtio-pci" ]]; then

		echo "Binding $DEV to igb_uio driver"
		python $DPDK_PATH/tools/dpdk-devbind.py --bind=igb_uio $DEV ||\
		{ echo 'failed to bind igb_uio for $DEV' ; exit 1; }
	fi
done

#setup 256 2MB pages
echo "Setting up huge pages for DPDK"
mkdir -p $MNT_DIR
mount | grep $MNT_DIR
if [ $? -ne 0 ]; then
	mount -t hugetlbfs nodev $MNT_DIR &&
	echo 256 > $PAGE_2MB
fi

echo "Compiling Forwarding Application"
cd $FRAMEWORK && cmake . && make

#Firing up the forwarding application
./fwd -s 0 -d 0
