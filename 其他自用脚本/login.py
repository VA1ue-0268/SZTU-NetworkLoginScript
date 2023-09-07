import requests

url0 = 'http://47.98.217.39/lfradius/libs/portal/unify/portal.php/login/cmcc_login'
url1 = 'http://47.98.217.39/lfradius/libs/portal/unify/portal.php/login/cmcc_login_result/'
url2 = 'http://47.98.217.39/lfradius/libs/portal/unify/portal.php/login/success/'
header = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.190 Safari/537.36',
    'Referer': 'http://47.98.217.39/',
    }

# 参数自己改

username = 
password = 

data0 = {
    "usrname": username,
    "passwd": password,
    "treaty": "on",
    "nasid": "3",
    "offline": "0",
    "protal_version": "1",
    "protal_papchap": "pap",
    "usrmac": "48:51:c5:ab:d4:5c",
    "usrip": "10.117.11.4",
    "basip": "172.17.127.254",
    "success": "http://47.98.217.39/lfradius/libs/portal/unify/portal.php/login/success/",
    "fail": "http://47.98.217.39/lfradius/libs/portal/unify/portal.php/login/fail"
}

mes = requests.post(url0, headers=header, data=data0)
# 返回的结果
value = str(mes.text).split('value="')[1].split('"')[0]

data1 = {
    "cmcc_login_value": value
}

mes = requests.post(url0, headers=header, data=data1)
print(str(mes.text))
mes = requests.post(url1, headers=header, data=data1)

print(str(mes.text))

# mes = requests.get(url2)