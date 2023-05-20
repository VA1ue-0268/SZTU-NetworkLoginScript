#!/bin/sh

swapon /mnt/sda1/swapfile

if pidof frpc > /dev/null
then
    logger "frpc is running"
else
    logger "frpc is not running"
    nohup /jffs/scripts/frpc.sh >> /tmp/mnt/sda1/frp_script.log 2>&1 &
fi

if pidof AdGuardHome > /dev/null
then
    logger "AdGuardHome is running"
else
    logger "AdGuardHome is not running"
    killall dnsmasq
    dnsmasq --port=0
    nohup /jffs/scripts/AD.sh >> /tmp/mnt/sda1/AdGuardHome/AdGuardHome.log 2>&1 &
fi

if pidof naive > /dev/null
then
    logger "naive is running"
else
    logger "naive is not running"
    nohup /jffs/scripts/naive.sh >> /tmp/mnt/sda1/naive.log 2>&1 &
fi
