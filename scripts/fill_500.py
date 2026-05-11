import json, time, requests
import warnings
warnings.filterwarnings('ignore')

print('读取词库...')
words = json.load(open('assets/wordbooks/cet4_full.json', 'r', encoding='utf-8'))
print(f'共 {len(words)} 个词，填充前 500 个...')

success = 0
for i, w in enumerate(words[:500]):
    word = w.get('word', '')
    current_def = w.get('definition', '')
    
    # 跳过已有有效释义的
    if current_def and '释义待补充' not in current_def and len(current_def.strip()) > 5:
        continue
    
    try:
        url = f'https://dict.youdao.com/suggest?num=1&ver=3.0&doctype=json&le=en&q={word}'
        r = requests.get(url, timeout=6, verify=False)
        data = r.json()
        entries = data.get('data', {}).get('entries', [])
        if entries:
            w['definition'] = entries[0].get('explain', '')[:80]
            success += 1
            if (i+1) % 50 == 0:
                print(f'进度: {i+1}/500, 成功: {success}')
    except:
        pass
    time.sleep(0.12)

json.dump(words, open('assets/wordbooks/cet4_full.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print(f'完成! 成功填充 {success} 个词')