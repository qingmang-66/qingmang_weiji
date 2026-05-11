import json
import os

dir = r'C:\qingmang_weiji\assets\wordbooks'
for f in ['cet4_full.json', 'cet6_full.json', 'kaoyan_full.json']:
    path = os.path.join(dir, f)
    with open(path, 'r', encoding='utf-8') as file:
        data = json.load(file)
    name = f.replace('_full.json', '').upper()
    print(f'{name}: {len(data)} 词')
    # 显示样本
    if data:
        print(f'  样本: {data[0]["word"]} - {data[0]["definition"][:50]}...')
print('\n词库文件大小:')
for f in ['cet4_full.json', 'cet6_full.json', 'kaoyan_full.json']:
    path = os.path.join(dir, f)
    size = os.path.getsize(path) / 1024
    print(f'  {f}: {size:.1f} KB')