from bs4 import BeautifulSoup
import subprocess
import requests

out_bytes = subprocess.check_output(['sh', '/jffs/scripts/getip.sh'])
ip = out_bytes.decode('utf-8').replace('\n', '')

login_url = 'http://47.98.217.39/lfradius/home.php?a=userlogin&c=login'

record_url = 'http://47.98.217.39/lfradius/home.php/user/online'

header = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.190 Safari/537.36',
    'Content-Type': 'application/x-www-form-urlencoded',
    'Referer': 'http://47.98.217.39/lfradius/login.php?c=login&a=showlogin',
    }

### 改这里
data = 'username=账号&password=密码'
result = requests.post(login_url, headers=header, data=data)
cookie = result.cookies.get_dict()
result = requests.get(record_url, headers=header, cookies=cookie)

result = BeautifulSoup(result.text, features="html.parser")
table = result.table
for i in table.find_all('button'):
    if ip in i['onclick'].split(',')[1].replace(')', '').replace('\'', ''):
        logout_url = 'http://47.98.217.39' + i['onclick'].split(',')[1].replace(')', '').replace('\'', '')
        result = requests.get(logout_url, headers=header, cookies=cookie)
