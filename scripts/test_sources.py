#!/usr/bin/env python3
# 尝试多个词库源
import requests, warnings
warnings.filterwarnings('ignore')

# 测试各个源
tests = [
    'https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt',
    'https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english.txt',
    'https://raw.githubusercontent.com/naer496/english-word-dataset/main/cet4_cet6_kaoyan.json',
]

for url in tests:
    try:
        r = requests.get(url, timeout=10, verify=False)
        print(f"{url.split('/')[-1]}: {r.status_code}, {len(r.text)} chars")
    except Exception as e:
        print(f"{url.split('/')[-1]}: ❌ {e}")