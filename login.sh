#!/bin/sh
username=
password=
ip=`ifconfig -a | grep inet | grep -v inet6 | grep -v 127.0.0.1 | grep -v 192.168.50.1 | grep -v 172.16.0.1 | awk '{print $2}' | tr -d "addr:"`

curl -X POST -d "usrname=$username&passwd=$password&treaty=on&nasid=3&offline=0&protal_version=1&protal_papchap=pap&usrmac=30:5f:77:d9:28:01&usrip=$ip&basip=172.17.127.254&success=http://47.98.217.39/lfradius/libs/portal/unify/portal.php/login/success/nastype/huawei&fail=http://47.98.217.39/lfradius/libs/portal/unify/portal.php/login/fail" -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.100 Safari/537.36' http://47.98.217.39/lfradius/libs/portal/unify/portal.php/login/huawei_login
