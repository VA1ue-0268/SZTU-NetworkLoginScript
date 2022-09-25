#!/bin/sh
sleep 30
nohup /tmp/mnt/sda1/frp/frpc -c /tmp/mnt/sda1/frp/frpc.ini >> /tmp/mnt/sda1/frp/frp.log &
