#!/bin/sh
sleep 30
echo `date`"start frps"
while true
do
    echo `date`"restart frps"
    /tmp/mnt/sda1/frp/frpc -c /tmp/mnt/sda1/frp/frpc.ini
done