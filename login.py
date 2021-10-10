import requests

url = 'http://10.99.99.99:8010/cgi-bin/webauth/ajax_webauth'
header = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.190 Safari/537.36',
    'Referer': 'http://47.98.217.39/',
    }

# 参数自己改

data = {
    "action": "login", 
    "user": "账号", 
    "pwd": "密码", 
    "usrmac": "设备mac", 
    "ip": "设备ip", 
    "success": "http://10.99.99.99:8080/webauth/success.html#", 
    "fail": "http://10.99.99.99:8080/webauth/fail.html#", 
    "clear": "http://10.99.99.99:8080/webauth/clear.html#"
}

mes = requests.post(url, headers=header, data=data)
# 返回的结果
print(str(1)+str(mes.status_code)+':'+str(mes.text))