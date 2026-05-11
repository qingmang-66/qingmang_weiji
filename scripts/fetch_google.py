#!/usr/bin/env python3
# 下载 google-10000 常用词
import requests, json, warnings
warnings.filterwarnings('ignore')

url = 'https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english.txt'
print('下载中...')
r = requests.get(url, timeout=30, verify=False)
if r.status_code == 200:
    words = [w.strip() for w in r.text.splitlines() if w.strip()]
    print(f'获取 {len(words)} 个单词')
    
    # 逐个查有道释义
    results = []
    for i, w in enumerate(words[:1000], 1):  # 只抓前1000个作为演示
        try:
            rr = requests.get(f'https://dict.youdao.com/suggest?num=1&ver=3.0&doctype=json&le=en&q={w}', timeout=5, verify=False)
            data = rr.json()
            definition = data.get('data',{}).get('entries',[{}])[0].get('explain','')
            results.append({'word':w,'phonetic':'','definition':definition,'example':'','exampleTranslation':''})
            if i % 50 == 0:
                print(f'进度: {i}/1000')
        except:
            results.append({'word':w,'phonetic':'','definition':f'[释义待补充] {w}', 'example':'','exampleTranslation':''})
    
    # 保存
    with open('C:/qingmang_weiji/assets/wordbooks/google_10000_full.json', 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print(f'✅ 完成! 保存 {len(results)} 条到 google_10000_full.json')
else:
    print(f'❌ 下载失败: {r.status_code}')