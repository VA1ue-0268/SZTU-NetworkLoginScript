#!/bin/sh
#sleep 60
times=0
con=0
#检测网络链接畅通
function network()
{
    #超时时间
    local timeout=1
    #目标网站
    local target=baidu.com
    #获取响应状态码
    local ret_code=`curl -I -s --connect-timeout ${timeout} ${target} -w %{http_code} | tail -n1`
    if [ "$ret_code" != "000" ]; then
        #网络畅通
        return 1
    else
        #网络不畅通
        return 0
    fi
    return 0
}
while [ $con -ne 3 ]
do
    network
    if [ $? -eq 0 ];then
        let times++
        logger `date`"网络不畅通！"$times
        con=0
        if [ $times -ge 2 ];then
            times=0
            mac_addr=`cat /sys/class/net/vlan2/address`
            new_mac_addr=${mac_addr:0:15}`openssl rand -hex 1 |sed 's/../&:/g;s/:$//'`
            nvram set wan0_hwaddr=${new_mac_addr}
            nvram set wan0_hwaddr_x=${new_mac_addr}
            nvram commit
            service restart_wan
            sleep 30
            python /jffs/scripts/logout.py

            username=
            password=
            ip=`ifconfig -a | grep inet | grep -v inet6 | grep -v 127.0.0.1 | grep -v 192.168.50.1 | grep -v 172.16.0.1 | awk '{print $2}' | tr -d "addr:"`
            
            python /jffs/scripts/login.py --ip $ip
            break
        fi
    else
        let con++
        ip=`ifconfig -a | grep inet | grep -v inet6 | grep -v 127.0.0.1 | grep -v 192.168.50.1 | grep -v 172.16.0.1 | awk '{print $2}' | tr -d "addr:"`
        times=0
        logger `date`"网络畅通！"$con
        break
    fi
done

