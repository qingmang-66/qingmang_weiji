import json, time, requests

words = json.load(open('assets/wordbooks/cet4_full.json', 'r', encoding='utf-8'))

for i, w in enumerate(words[:10]):
    word = w['word']
    url = f'https://dict.youdao.com/suggest?num=1&ver=3.0&doctype=json&le=en&q={word}'
    r = requests.get(url, timeout=8, verify=False)
    data = r.json()
    entries = data.get('data', {}).get('entries', [])
    if entries:
        w['definition'] = entries[0].get('explain', '')[:80]
        print(f'{i+1}. {word}: {w["definition"][:40]}')
    time.sleep(0.2)

json.dump(words, open('assets/wordbooks/cet4_full.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print('Done!')