#!/bin/sh
while [ ! -d /tmp/mnt/sda1/ ]
do
	sleep 1
done
swapon /mnt/sda1/swapfile
echo start
killall dnsmasq
dnsmasq --port=0
nohup /tmp/mnt/sda1/AdGuardHome/AdGuardHome >> /tmp/mnt/sda1/AdGuardHome/AdGuardHome.log 2>&1 &
#sleep 30
#/jffs/scripts/frps.sh
