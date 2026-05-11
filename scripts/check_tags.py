import sqlite3
db = sqlite3.connect(r'D:\edge\English\ecdict-sqlite-28\stardict.db')
c = db.cursor()

# 检查各种标签组合
c.execute("SELECT COUNT(*) FROM stardict WHERE tag LIKE '%cet4%'")
print('包含 cet4:', c.fetchone()[0])

c.execute("SELECT COUNT(*) FROM stardict WHERE tag LIKE '%cet6%'")
print('包含 cet6:', c.fetchone()[0])

c.execute("SELECT COUNT(*) FROM stardict WHERE tag LIKE '%cet4%cet6%' OR tag LIKE '%cet6%cet4%'")
print('同时包含 cet4 和 cet6:', c.fetchone()[0])

c.execute("SELECT COUNT(*) FROM stardict WHERE tag LIKE '%gk%'")
print('包含 gk (考研):', c.fetchone()[0])

# 查看一些样本
print('\nCET-4 样本 (前5个):')
c.execute("SELECT word, tag FROM stardict WHERE tag LIKE '%cet4%' LIMIT 5")
for row in c.fetchall():
    print(f'  {row[0]}: {row[1]}')

print('\nCET-4 且不含 CET-6 样本 (前5个):')
c.execute("SELECT word, tag FROM stardict WHERE tag LIKE '%cet4%' AND tag NOT LIKE '%cet6%' LIMIT 5")
for row in c.fetchall():
    print(f'  {row[0]}: {row[1]}')

db.close()