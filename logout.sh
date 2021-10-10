curl -X POST -c cookie -d "username=账号&password=密码" -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.100 Safari/537.36' "http://47.98.217.39/lfradius/home.php?a=userlogin&c=login"

curl -X GET -b cookie -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.100 Safari/537.36' "http://47.98.217.39/lfradius/home.php/user/offline/user/账号"
