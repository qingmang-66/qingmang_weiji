import urllib.request

url = 'https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})

print('获取文件大小...')
try:
    with urllib.request.urlopen(req, timeout=10) as response:
        size = response.headers.get('Content-Length', 0)
        print(f'文件大小：{int(size)/1024/1024:.1f} MB')
        if int(size) > 50 * 1024 * 1024:
            print('文件太大，建议使用分批下载')
        else:
            print('文件大小可接受')
except Exception as e:
    print(f'错误：{e}')