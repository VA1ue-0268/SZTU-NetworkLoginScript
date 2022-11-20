#!/bin/sh
sleep 90
while [ ! -d /tmp/mnt/sda1/ ]
do
	sleep 1
done
swapon /mnt/sda1/swapfile
echo start
killall dnsmasq
dnsmasq --port=0
nohup /jffs/scripts/AD.sh >> /tmp/mnt/sda1/AdGuardHome/AdGuardHome.log 2>&1 &
nohup /jffs/scripts/frps.sh >> /tmp/mnt/sda1/frp_script.log 2>&1 &
