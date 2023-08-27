#!/bin/sh
#########################################################
# Clash Process Control script for AM380 merlin firmware
# Writen by Awkee (next4nextjob(at)gmail.com)
# Website: https://vlike.work
#########################################################

KSHOME="/koolshare"
app_name="clash"

source ${KSHOME}/scripts/base.sh

# 避免出现 out of memory 问题
ulimit -s unlimited

eval $(dbus export ${app_name}_)

alias curl="curl --connect-timeout 300"
CURL_OPTS="--proxy socks5://127.0.0.1:1080 -sSL "
bin_list="${app_name} yq"

dns_port="1053"         # Clash DNS端口
redir_port="3333"       # Clash 透明代理端口

# 存放规则文件目录#
rule_src_dir="${KSHOME}/clash/ruleset"
config_file="${KSHOME}/${app_name}/config.yaml"
temp_provider_file="/tmp/clash_provider.yaml"

# provider_url_bak="${KSHOME}/${app_name}/provider_url.yaml"        # URL订阅源配置信息
# provider_file_bak="${KSHOME}/${app_name}/provider_file.yaml"      # FILE订阅源配置信息

update_file="${KSHOME}/${app_name}/provider_remote.yaml"          # 远程URL更新文件

CMD="${app_name} -d ${KSHOME}/${app_name}/"
lan_ipaddr=$(nvram get lan_ipaddr)
cron_id="clash_daemon"             # 调度ID,用来查询和删除操作标识

LOGGER() {
    # Magic number for Log 9977
    logger -s -t "$(date +'%Y年%m月%d日%H:%M:%S'):clash" "$@"
}

if [ "$lan_ipaddr" = "" ]; then
    LOGGER "真糟糕！ nvram 命令没找到局域网路由器地址，这样防火墙规则配置不了啦！还是自己手动设置后再执行吧！"
    exit 1
fi
# 检测是否有 cru 命令
if [ ! -x "$(which cru)" ]; then
    if [ -x "$(which cru.sh)" ]; then
        alias cru="cru.sh"
    else
        LOGGER "糟糕！没有找到 cru 命令！ 这样配置不了调度啦！"
    fi
fi

usage() {
    cat <<END
 使用帮助:
    ${app_name} <start|stop|status|restart>
 参数介绍：
    start   启动服务
    stop    停止服务
    status  状态检查
    restart 重启服务
END
}

echo_status() {
    if [ "$1" = "head" ]; then
        printf "%-20s %-20s %-s" "进程名称" "进程号" "运行状态"
        return 0
    fi
    pids=$(pidof $1)
    if [ "$pids" == "" ]; then
        printf "%-15s %-15s %-s" "$1" "$pids" "已停止."
    else
        printf "%-15s %-15s %-s" "$1" "$pids" "正常运行中."
    fi
}

ARCH=""

# 暂时支持ARM芯片吧，等手里有 MIPS 芯片再适配
case $(uname -m) in
    armv7l)
        if grep -i vfpv3 /proc/cpuinfo >/dev/null 2>&1; then
            ARCH="armv7"
        elif grep -i vfpv1 /proc/cpuinfo >/dev/null 2>&1; then
            ARCH="armv6"
        else
            ARCH="armv5"
        fi
        ;;
    *)
        LOGGER "糟糕！平台类型不支持呀！赶紧通知开发者适配！或者自己动手丰衣足食！"
        exit 0
        ;;
esac

get_proc_status() {
    echo "检查进程信息："
    echo "$(echo_status head)"
    echo "$(echo_status $app_name)"
    echo "----------------------------------------------------"
    echo "服务守护调度： [$(cru l | grep ${cron_id})]"
    echo "文件更新调度： [$(cru l| grep update_provider_local)]"
    echo "订阅链接: $clash_provider_file"
    echo "----------------------------------------------------"
    echo "Clash版本信息： `clash -v`"
    echo "yq工具版本信息： `yq -V`"
    echo "----------------------------------------------------"
}

# 添加守护监控脚本
add_cron() {

    cru a "check_status" "*/1 * * * * /jffs/scripts/check_status.sh"
    cru a "checknetwork" "*/2 * * * * /jffs/scripts/checknetwork.sh"

    if cru l | grep ${cron_id} >/dev/null && cru l |grep update_provider_local >/dev/null; then
        LOGGER "进程守护脚本已经添加!不需要重复添加吧？！？"
        return 0
    fi

    cru a "${cron_id}" "*/2 * * * * /koolshare/scripts/clash_control.sh start"
    if cru l | grep ${cron_id} >/dev/null; then
        LOGGER "添加进程守护脚本成功!"
    else
        LOGGER "不知道啥原因，守护脚本没添加到调度里！赶紧查查吧！"
        return 1
    fi

    # cru a "update_provider_local" "0 * * * * /koolshare/scripts/clash_control.sh update_provider_file >/dev/null 2>&1"
    # if cru l | grep update_provider_local >/dev/null; then
    #     LOGGER "添加订阅源更新调度脚本成功!"
    # else
    #     LOGGER "不知道啥原因，订阅源更新调度脚本没添加到调度里！赶紧查查吧！"
    #     return 1
    # fi

}

# 删除守护监控脚本
del_cron() {
    # cru d "update_provider_local"
    cru d "${cron_id}"
    LOGGER "删除进程守护脚本成功!"
}

# 配置iptables规则
add_iptables() {
    # 1. 转发 HTTP/HTTPS 请求到 Clash redir-port 端口
    # 2. 转发 DNS 53端口请求到 Clash dns.listen 端口
    if [ "$clash_trans" = "off" ]; then
        LOGGER "透明代理模式已关闭！不需要添加iptables转发规则！"
        return 0
    fi
    if iptables -t nat -S ${app_name} >/dev/null 2>&1; then
        LOGGER "已经配置过${app_name}的iptables规则！"
        return 0
    fi

    LOGGER "开始配置 ${app_name} iptables规则..."
    
    # Fake-IP 规则添加
    iptables -t nat -A OUTPUT -p tcp -d 198.18.0.0/16 -j REDIRECT --to-port ${redir_port}

    
    if [ "$clash_gfwlist_mode" = "on" ] ; then
        # 根据dnsmasq的ipset规则识别流量代理
        LOGGER "创建ipset规则集"
        ipset -! create gfwlist nethash && ipset flush gfwlist
        # ipset -! create router nethash && ipset flush router
        iptables -t nat -N ${app_name}
        iptables -t nat -A ${app_name} -p tcp -m set --match-set gfwlist dst -j REDIRECT --to-ports ${redir_port}
        iptables -t nat -A PREROUTING -p tcp -s ${lan_ipaddr}/16 -m set --match-set gfwlist dst -j ${app_name}
    else
        iptables -t nat -N ${app_name}
        iptables -t nat -F ${app_name}
        iptables -t nat -A PREROUTING -p tcp -s ${lan_ipaddr}/16  -j ${app_name}
        # 本地地址请求不转发
        iptables -t nat -A ${app_name} -d 10.0.0.0/8 -j RETURN
        iptables -t nat -A ${app_name} -d 127.0.0.0/8 -j RETURN
        iptables -t nat -A ${app_name} -d 169.254.0.0/16 -j RETURN
        iptables -t nat -A ${app_name} -d 172.16.0.0/12 -j RETURN
        iptables -t nat -A ${app_name} -d ${lan_ipaddr}/16 -j RETURN
        # 服务端口${redir_port}接管HTTP/HTTPS请求转发, 过滤 22,1080,8080一些代理常用端口
        iptables -t nat -A ${app_name} -s ${lan_ipaddr}/16 -p tcp -m multiport --dport 80,443 -j REDIRECT --to-ports ${redir_port}
        # # 转发DNS请求到端口 dns_port 解析
        iptables -t nat -N ${app_name}_dns
        iptables -t nat -F ${app_name}_dns
        iptables -t nat -A ${app_name}_dns -p udp -s ${lan_ipaddr}/16 --dport 53 -j REDIRECT --to-ports $dns_port
        iptables -t nat -A PREROUTING -p udp -s ${lan_ipaddr}/16 --dport 53 -j ${app_name}_dns
        iptables -t nat -I OUTPUT -p udp --dport 53 -j ${app_name}_dns
    fi
}

# 清理iptables规则
del_iptables() {
    if ! iptables -t nat -S ${app_name} >/dev/null 2>&1; then
        LOGGER "已经清理过 ${app_name} 的iptables规则！"
        return 0
    fi
    LOGGER "开始清理 ${app_name} iptables规则 ..."
    # Fake-IP 规则清理
    iptables -t nat -D OUTPUT -p tcp -d 198.18.0.0/16 -j REDIRECT --to-port ${redir_port}
    
    iptables -t nat -D PREROUTING -p tcp -s ${lan_ipaddr}/16 -m set --match-set gfwlist dst -j ${app_name}
    iptables -t nat -D PREROUTING -p tcp -s ${lan_ipaddr}/16 -j ${app_name}
    iptables -t nat -D ${app_name} -p tcp -m set --match-set gfwlist dst -j REDIRECT --to-ports ${redir_port}
    iptables -t nat -F ${app_name}
    iptables -t nat -X ${app_name}

    iptables -t nat -D PREROUTING -p udp -s ${lan_ipaddr}/16 --dport 53 -j ${app_name}_dns
    iptables -t nat -D OUTPUT -p udp --dport 53 -j ${app_name}_dns
    iptables -t nat -F ${app_name}_dns
    iptables -t nat -X ${app_name}_dns
}

status() {
    pidof ${app_name}
    # ps | grep ${app_name} | grep -v grep |grep -v /bin/sh | grep -v " vi "
}

get_filelist() {
    for fn in gfw apple google greatfire icloud proxy telegramcidr
    do
        printf "%s/%s.yaml " ${rule_src_dir} $fn
    done
}

## 已经废弃:生成 gfwlist.conf # dnsmasq 服务使用
#update_gfwlist() {
    # gfwlist_file=${KSHOME}/$app_name/gfwlist.conf

    # awk '!/^[a-z]/{
    #     gsub(/\+|'\''/,"",$2);
    #     rule[$2] += 1;
    # }END{
    #     for( i in rule) {
    #         printf("%s\n", i) | "sort"
    #     }
    # }' $(get_filelist) | awk -v dnsport=${dns_port} '{
    #     printf("server=/%s/%s#%s\n", $1, "127.0.0.1", dnsport);
    #     printf("ipset=/%s/%s\n", $1, "gfwlist");
    # }' > ${gfwlist_file}
    # LOGGER "已生成 ${gfwlist_file} 文件！ 文件大小: $(du -sm ${gfwlist_file}|awk '{print $1}') MB ! 记录数: $(wc -l ${gfwlist_file}|awk '/^server/{ print $1}') 条."
    # run_dnsmasq restart
#}

# 废弃操作
#start_dns() {
    # if [ "$clash_trans" = "off" ]; then
    #     LOGGER "透明代理模式已关闭！不启动DNS转发请求"
    #     return 0
    # fi
    # for fn in wblist.conf gfwlist.conf; do
    #     if [ ! -f /jffs/configs/dnsmasq.d/${fn} ]; then
    #         LOGGER "添加软链接 ${KSHOME}/clash/${fn} 到 dnsmasq.d 目录下"
    #         ln -sf ${KSHOME}/clash/${fn} /jffs/configs/dnsmasq.d/${fn}
    #     fi
    # done

    # run_dnsmasq restart
#}
# 废弃操作
#stop_dns() {
    
    # LOGGER "删除gfwlist.conf与wblist.conf文件:"
    # for fn in wblist.conf gfwlist.conf; do
    #     rm -f /jffs/configs/dnsmasq.d/${fn}
    # done
    # LOGGER "开始重启dnsmasq,DNS解析"
    # run_dnsmasq restart
#}

# 废弃操作
#run_dnsmasq() {
    # case "$1" in
    # start | stop | restart)
    #     LOGGER "执行 $1 dnsmasq 操作"
    #     service $1_dnsmasq
    #     ;;
    # *)
    #     LOGGER "无效的 dnsmasq 操作"
    #     ;;
    # esac
#}

start() {
    # 1. 启动服务进程
    # 2. 配置iptables策略
    if [ "$clash_enable" = "off" ]; then
        echo "Clash开关处于关闭状态，无法启动Clash"
        return 0
    fi
    echo "启动 $app_name"
    if status >/dev/null 2>&1; then
        LOGGER "$app 已经运行了"
    else
        LOGGER "开始启动 ${app_name} :"
        nohup ${CMD} >/dev/null 2>&1 &
        sleep 1
        dbus set ${app_name}_enable="on"
    fi
    if status >/dev/null 2>&1; then
        LOGGER "启动 ${CMD} 成功！"
    else
        LOGGER "启动 ${CMD} 失败！"
    fi
    [ ! -L "/www/ext/dashboard" ] && ln -sf /koolshare/${app_name}/dashboard /www/ext/dashboard
    add_iptables
    # if [ "$clash_gfwlist_mode" = "on" ] ; then
    #     # start_dns
    # fi
    add_cron
}

stop() {
    # 1. 停止服务进程
    # 2. 清理iptables策略
    echo "停止 $app_name"
    if status >/dev/null 2>&1; then
        LOGGER "停止 ${app_name} ..."
        killall ${app_name}
        dbus set ${app_name}_enable="off"
    fi
    del_iptables  2>/dev/null
    if status >/dev/null 2>&1; then
        LOGGER "停止 ${CMD} 失败！"
    else
        LOGGER "停止 ${CMD} 成功！"
    fi
    # stop_dns
    del_cron
}

########## config part ###########

# DIY节点 列表
list_nodes() {
    filename="$config_file"
    node_list=$(yq e '.proxies[].name' $filename| awk '!/test/{ printf("%s ", $0)}')
    LOGGER "DIY节点列表: [${node_list}]"
    dbus set clash_name_list="$node_list"
}

# DIY节点 添加节点(一个或多个)
add_nodes() {
    tmp_node_file="/koolshare/clash/tmp_node.yaml"
    # 替换掉回车、多行文本变量页面加载时会出错！
    dbus set clash_node_list="$(echo "$clash_node_list" | sed 's/\n/\t/g')"
    node_list="$clash_node_list"
    if [ "$node_list" = "" ] ; then
        LOGGER "想啥呢！节点可不会凭空产生！你得传入 ss:// 或 ssr:// 或者 vmess:// 前缀的URI链接！"
        return 1
    fi

    # 生成节点文件
    uri_decoder -uri "$node_list" -db "/koolshare/clash/Country.mmdb" > ${tmp_node_file}
    if [ "$?" != "0" ] ; then
        LOGGER "抱歉！你添加的链接解析失败啦！给个正确的链接吧！"
    fi
    LOGGER "成功导入DIY代理节点"

    cp $config_file $config_file.old
    # d : 深度合并数组
    yq ea -i 'select(fi==0) *d select(fi==1)' ${config_file} ${tmp_node_file}
    if [ "$?" != "0" ] ; then
        LOGGER "怎么会这样! 添加DIY代理节点失败啦！"
        return 2
    fi
    LOGGER "添加DIY节点成功！"
    list_nodes
}

# DIY节点 删除一个节点
delete_one_node() {
    filename="$config_file"
    cp $config_file $config_file.old
    LOGGER "开始删除DIY节点 (${clash_delete_name})："
    f=${clash_delete_name} yq e -i 'del(.proxies[]|select(.name == strenv(f)))' $filename
    f=${clash_delete_name} yq e -i 'del(.proxy-groups[].proxies[]|select(. == strenv(f)))' $filename
    LOGGER "节点删除完成!"
    list_nodes
}

# DIY节点 全部删除
delete_all_nodes() {
    filename="$config_file"
    cp $config_file $config_file.old
    LOGGER "开始清理所有DIY节点："
    # for fn in `yq e '.proxies[].name' $filename|grep -v test`
    for fn in ${clash_name_list}
    do
        # 保留 test 节点，删掉后添加节点会很出问题的哦！
        if [ $fn != "test" ] ; then
            f="$fn" yq e -i 'del(.proxies[]|select(.name == strenv(f)))' $filename
            f="$fn" yq e -i 'del(.proxy-groups[].proxies[]|select(. == strenv(f)))' $filename
        fi
    done
    LOGGER "清理DIY节点完毕！让世界回归平静！"
    list_nodes
}

#############  provider 订阅源管理

# 更新订阅源：文件类型
update_provider_file() {
    
    if [ "$clash_provider_file" = "" ]; then
        LOGGER "文件类型订阅源URL地址没设置，就不更新啦！ clash_provider_file=[$clash_provider_file]!"
        return 1
    fi
    curl --insecure ${CURL_OPTS} -o $temp_provider_file ${clash_provider_file} >/dev/null 2>&1
    if [ "$?" != "0" ]; then
        LOGGER "下载订阅源URL信息失败!可能原因：1.URL地址被屏蔽！2.使用代理不稳定. 重新尝试一次。"
        return 2
    fi
    LOGGER "下载订阅源文件成功! URL=[${clash_provider_file}]."

    # 格式化处理yaml文件，只保留proxies信息
    check_format=$(yq e '.proxies[0].name' $temp_provider_file)
    if [ "$check_format" = "null" ]; then
        LOGGER "节点订阅源配置文件yaml格式错误： ${temp_provider_file}"
        LOGGER "错误原因：没找到 proxies 代理节点配置！ 没有代理节点怎么科学上网呢？"
        LOGGER "订阅源文件格式请参考： https://github.com/Dreamacro/clash/wiki/configuration#proxy-providers "
        return 3
    fi

    yq e '{ "proxies": .proxies}' $temp_provider_file > ${update_file}.new
    if [ "$?" != "0" ] ; then
        LOGGER "更新节点错误！[$?]！订阅源配置可能存在问题！"
        rm -f ${update_file}.new
        return 4
    else
        mv ${update_file} ${update_file}.old
        mv ${update_file}.new  ${update_file}
    fi

    if cru l | grep update_provider_local >/dev/null; then
        LOGGER "已经添加了调度! $(cru l | grep update_provider_local)"
    else
        cru a "update_provider_local" "0 * * * * /koolshare/scripts/clash_control.sh update_provider_file >/dev/null 2>&1"
        LOGGER "成功添加更新调度配置： $(cru l| grep update_provider_local)"
    fi
    
    if [ "$clash_provider_file" != "$clash_provider_file_old" ]; then
        LOGGER "更新了订阅源！ 旧地址：[$clash_provider_file_old]"
        dbus set clash_provider_file_old=$clash_provider_file
    fi

    LOGGER "还不错！更新订阅源成功了！"
    LOGGER "成功导入代理节点：$(yq e '.proxies[].type' ${update_file} | awk '{a[$1]++}END{for(i in a)printf("%s:%.0f ,",i,a[i])}')"
    rm -f $temp_provider_file
}

update_geoip() {
    #
    geoip_file="${KSHOME}/clash/Country.mmdb"
    cp ${geoip_file} ${geoip_file}.bak
    # curl ${CURL_OPTS} -o ${geoip_file} -L  https://cdn.jsdelivr.net/gh/Dreamacro/maxmind-geoip@release/Country.mmdb
    curl ${CURL_OPTS} -o ${geoip_file} -L  https://cdn.jsdelivr.net/gh/Hackl0us/GeoIP2-CN@release/Country.mmdb
    if [ "$?" != "0" ] ; then
        LOGGER "下载「$geoip_file」文件失败！"
        mv -f ${geoip_file}.bak ${geoip_file}
        return 1
    fi
    rm ${geoip_file}.bak
    LOGGER "「$geoip_file」文件更新成功！"
}

all_ruleset() {
    cat <<END
https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/direct.txt
https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/proxy.txt
https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/reject.txt
https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/private.txt
https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/apple.txt
https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/icloud.txt
https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/google.txt
https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/gfw.txt
https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/greatfire.txt
https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/tld-not-cn.txt
https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/telegramcidr.txt
https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/lancidr.txt
https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/cncidr.txt
END

}

# 更新规则集
update_ruleset() {
    outdir="${KSHOME}/clash/ruleset"
    all_ruleset | while read dn_url
    do
        fn=`basename ${dn_url}|sed 's/txt/yaml/g'`
        cp ${outdir}/$fn ${outdir}/${fn}.bak
        curl ${CURL_OPTS} -o ${outdir}/$fn ${dn_url}
        if [ "$?" != "0" ] ; then
            mv -f ${outdir}/${fn}.bak ${outdir}/${fn}
            LOGGER "更新[$fn]失败."
        else
            rm -f ${outdir}/${fn}.bak
            LOGGER "更新[$fn]成功."
        fi
    done
}

# 切换gfwlist黑名单模式(使用dnsmasq过滤黑名单URL规则请求到代理处理)
switch_gfwlist_mode(){
    gfw_status="关闭"
    if [ "$clash_gfwlist_mode" = "on" ] ; then
        gfw_status="启用"
    fi
    LOGGER "${gfw_status} 黑名单模式： dnsmasq过滤黑名单URL规则请求到代理中！"
}

# 切换模式： 透明代理开关 + 组节点切换开关
switch_trans_mode() {
    if [ "$clash_group_type" != "$clash_select_type" ]; then
        LOGGER 切换了组节点模式为: "$clash_select_type"
        yq e -i '.proxy-groups[1].type = strenv(clash_select_type)' $config_file
        dbus set clash_group_type=$clash_select_type
    fi
}

# 更新新版本clash客户端可执行程序
update_clash_bin() {
    cd /tmp
    new_ver=$clash_new_version
    old_version=$clash_version
    
    # 专业版更新
    download_url="$(curl ${CURL_OPTS} https://github.com/Dreamacro/clash/releases/tag/premium| awk '/premium.clash-linux-armv5/{ gsub(/href=|["]/,""); print "https://github.com"$2 }'|head -1)"
    bin_file=$(basename $download_url)
    LOGGER "新版本地址：${download_url}"
    # bin_file="clash-linux-${ARCH}-${new_ver}"
    # download_url="https://github.com/Dreamacro/clash/releases/download/${new_ver}/${bin_file}.gz"
    curl ${CURL_OPTS} -o ${bin_file}.gz -L $download_url && gzip -d ${bin_file}.gz && chmod +x ${bin_file} && mv ${KSHOME}/bin/${app_name} /tmp/${app_name}.${old_version} && mv ${bin_file} ${KSHOME}/bin/${app_name}
    if [ "$?" != "0" ]; then
        LOGGER "更新出现了点问题!"
        [[ -f /tmp/${app_name}.${old_version} ]] && mv /tmp/${app_name}.${old_version} ${KSHOME}/bin/${app_name}
        if [ -f ${KSHOME}/bin/${app_name} ]; then
            LOGGER "更新 ${KSHOME}/bin/${app_name} 失败啦！"
            LOGGER 当前Clash版本信息: $(${KSHOME}/bin/${app_name} -v)
            LOGGER "别急！先把更新失败原因找到再想更新的事儿吧！"
        else
            LOGGER "太牛啦！如果走到这里，说明Clash可执行程序搞的不翼而飞啦！谁吃了呢？"
        fi
        return 1
    else
        # 更新成功啦
        LOGGER "更新到新版本！"
        dbus set clash_version=$clash_new_version
        dbus remove clash_new_version
        rm -f /tmp/${app_name}.${old_version}
    fi
}

######## 执行主要动作信息  ########
do_action() {
    # web界面配置操作
    LOGGER "执行动作 ${clash_action} ..."
    case "$clash_action" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    update_provider_url | update_provider_file | update_clash_bin | switch_trans_mode|switch_gfwlist_mode)
        # 需要重启的操作分类
        $clash_action
        if [ "$?" != "0" ]; then
            return $?
        fi
        stop
        start
        ;;
    get_proc_status|add_nodes|delete_one_node|delete_all_nodes|update_ruleset|update_geoip)
        # 不需要重启操作
        $clash_action
        ;;
    *)
        LOGGER "无效的操作！ clash_action:[$clash_action]"
        ;;
    esac
    # 执行完成动作后，清理动作.
    dbus remove clash_action
}

# 命令行参数处理
# main 与 do_action 类似， 但 do_action 根据 clash_action 选择要执行什么操作
main() {
    str_cmd=${1:-"do_action"}
    case "${str_cmd}" in
    start | stop | status | do_action | add_iptables | del_iptables | get_proc_status|update_provider_file|list_nodes)
        ${str_cmd}
        ;;
    restart)
        stop
        start
        ;;
    *)
        usage
        ;;
    esac
}

main $@
