#!/bin/sh
echo `date`"script starting"
sleep 30

swapon /mnt/sda1/swapfile
echo start
killall dnsmasq
dnsmasq --port=0
nohup /jffs/scripts/AD.sh >> /tmp/mnt/sda1/AdGuardHome/AdGuardHome.log 2>&1 &
nohup /jffs/scripts/frpc.sh >> /tmp/mnt/sda1/frp_script.log 2>&1 &
