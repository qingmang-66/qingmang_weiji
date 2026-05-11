#!/usr/bin/env python3
# 下载现成词库
import requests, json, warnings
warnings.filterwarnings('ignore')

urls = [
    ('https://raw.githubusercontent.com/kyr0/Word-List/master/gaokao.txt', 'gaokao_raw.txt'),
    ('https://raw.githubusercontent.com/kyr0/Word-List/master/kaoyan.txt', 'kaoyan_raw.txt'),
]

for url, fname in urls:
    try:
        r = requests.get(url, timeout=15, verify=False)
        if r.status_code == 200:
            with open(f'C:/qingmang_weiji/assets/words/{fname}', 'wb') as f:
                f.write(r.content)
            print(f'✅ 下载 {fname}')
        else:
            print(f'❌ {fname}: {r.status_code}')
    except Exception as e:
        print(f'❌ {fname}: {e}')