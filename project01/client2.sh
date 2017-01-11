#!/bin/bash

IP="192.168.0.2"
CIDR=( "172.16.0.2/24" "10.0.0.2/24" "192.168.0.2/24")
NETWORK="192.168.0.0/24"
DEFAULT_GATEWAY="192.168.0.1"                                                      
DEV="eth1"                                                                      
ROUTING_TABLE_NUM="200"                                                         
ROUTING_TABLE_NAME="table_eth1"

function flush() {

if [ -z $1 ]; then
	echo "Please specify the device name for flushing"
else
	echo "Settings flushed for device : $1"
    	ip addr flush dev $1
    	echo "Setting $1 state to down"
    	ip link set dev $1 down
        #remove rules
	for i in ${CIDR[@]}
	do
		ip rule delete from ${i}
		ip rule delete to ${i}
	done 
fi
}


# Add IP Address to Interface
ip a add $CIDR dev $DEV
if [ $? -eq 0 ]; then
	echo "Successfully added IP Address: $CIDR"
else
	flush $DEV
	exit 1
fi

#Set interface state up
ip link set $DEV  up
if [ $? -eq 0 ]; then 
	echo "Successfully set state of device: $DEV up"
else 
	flush $DEV
	exit 1
fi

#Policy based Routing
grep -q $ROUTING_TABLE_NUM$'\t'$ROUTING_TABLE_NAME /etc/iproute2/rt_tables
if [ $? -ne 0 ]; then                                                           
	echo -e $ROUTING_TABLE_NUM"\t"$ROUTING_TABLE_NAME >> /etc/iproute2/rt_tables
	if [ $? -eq 0 ]; then                                                   
		echo "Successfully created a new routing table: $ROUTING_TABLE_NAME"
	else
		flush $DEV
		exit 1
	fi
fi

ip rule list | grep $ROUTING_TABLE_NAME
if [ $? -ne 0 ]; then
	for i in ${CIDR[@]}
	do
		ip rule add from ${i} table $ROUTING_TABLE_NAME
		if [ $? -ne 0 ]; then
			flush $DEV
			exit 1
		fi

		ip rule add to ${i} table $ROUTING_TABLE_NAME
		if [ $? -ne 0 ]; then
			flush $DEV
			exit 1
		fi
	done
fi

#Set routes in new routing table
ip route add $NETWORK dev $DEV src $IP table $ROUTING_TABLE_NAME
if [ $? -ne 0 ]; then
	flush $DEV
	exit 1
fi

#Default gateway is router's interface ip
ip route add default via $DEFAULT_GATEWAY dev $DEV table $ROUTING_TABLE_NAME
if [ $? -ne 0 ]; then
	flush $DEV
	exit 1                                                                  
fi

echo -e "\nInterface $DEV"                                                      
ifconfig $DEV

echo -e "\nRouting Table Policy"
ip rule show

echo -e "\nRoutes"
ip route show table $ROUTING_TABLE_NAME
