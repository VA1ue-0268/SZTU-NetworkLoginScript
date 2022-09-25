#!/bin/sh
sleep 30
nohup /jffs/scripts/checknetwork.sh >> /tmp/mnt/sda1/network_state.log 2>&1 &
