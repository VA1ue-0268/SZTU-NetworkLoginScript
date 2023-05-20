#!/bin/sh
logger `date`"restart frps"
/tmp/mnt/sda1/frp/frpc -c /tmp/mnt/sda1/frp/frpc.ini
