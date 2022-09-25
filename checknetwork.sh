#!/bin/sh
#检测连通性，不通自动重连
function network()
{
    local timeout=5
    local target=www.baidu.com
    #获取响应状态码
    local ret_code=`curl -I -s --connect-timeout ${timeout} ${target} -w %{http_code} | tail -n1`
    if [ "$ret_code" = "200" ]; then
        #网络畅通
        return 1
    else
        #网络不畅通
        return 0
    fi
    return 0
}
while true
do
    sleep 5
    network
    if [ $? -eq 0 ];then
        echo `date`"网络不畅通！"
        python /jffs/scripts/logout.py
        mac_addr=`cat /sys/class/net/vlan2/address`
        new_mac_addr=${mac_addr:0:15}`openssl rand -hex 1 |sed 's/../&:/g;s/:$//'`
        nvram set wan0_hwaddr=${new_mac_addr}
        nvram set wan0_hwaddr_x=${new_mac_addr}
        nvram commit
        service restart_wan
        sleep 30
        # username=自己填
        # password=
        # 获取ip根据自己的需求改
        ip=`ifconfig -a | grep inet | grep -v inet6 | grep -v 127.0.0.1 | grep -v 192.168.50.1 | grep -v 172.16.0.1 | awk '{print $2}' | tr -d "addr:"`
        curl -X POST -d "action=login&user=$username&pwd=$password&usrmac=30:5f:77:d9:28:01&ip=$ip&success=http://47.98.217.39/lfradius/libs/portal/unify/portal.php/login/success/nastype/Panabit/basip/10.99.99.99/usrip/$ip&fail=http://47.98.217.39/lfradius/libs/portal/unify/portal.php/login/fail" -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.100 Safari/537.36' http://10.99.99.99:8010/cgi-bin/webauth/ajax_webauth
    else
        echo `date`"网络畅通！"
    fi
done

