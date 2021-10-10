#获取设备ip
# grep -v 192.168.50.1 为过滤本机ip，自己看着改
ip=`ifconfig -a | grep inet | grep -v inet6 | grep -v 127.0.0.1 | grep -v 192.168.50.1 | awk '{print $2}' | tr -d "addr:"`
#登录
#参数自己改
curl -X POST -d "action=login&user=账号&pwd=密码&usrmac=设备mac&ip=$ip&success=http://10.99.99.99:8080/webauth/success.html#&fail=http://10.99.99.99:8080/webauth/fail.html#&clear=http://10.99.99.99:8080/webauth/clear.html#" -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.100 Safari/537.36' http://10.99.99.99:8010/cgi-bin/webauth/ajax_webauth