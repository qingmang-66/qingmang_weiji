import sqlite3
import os

db_path = r'D:\edge\English\ecdict-sqlite-28\stardict.db'
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('SELECT name FROM sqlite_master WHERE type="table"')
    tables = cursor.fetchall()
    print('数据库表:', tables)
    
    # 检查词汇数量
    cursor.execute('SELECT COUNT(*) FROM ec_dict')
    total = cursor.fetchone()[0]
    print(f'总词汇数: {total}')
    
    # 检查 CET-4 标签
    cursor.execute('SELECT COUNT(*) FROM ec_dict WHERE tag LIKE "%cet4%"')
    cet4 = cursor.fetchone()[0]
    print(f'CET-4 词汇: {cet4}')
    
    # 检查 CET-6 标签
    cursor.execute('SELECT COUNT(*) FROM ec_dict WHERE tag LIKE "%cet6%"')
    cet6 = cursor.fetchone()[0]
    print(f'CET-6 词汇: {cet6}')
    
    # 检查 gk 标签（考研）
    cursor.execute('SELECT COUNT(*) FROM ec_dict WHERE tag LIKE "%gk%"')
    gk = cursor.fetchone()[0]
    print(f'考研词汇: {gk}')
    
    # 检查几个样本
    print('\n样本数据:')
    cursor.execute('SELECT word, phonetic, translation, tag FROM ec_dict WHERE tag LIKE "%cet4%" LIMIT 3')
    for row in cursor.fetchall():
        print(f'  {row[0]}: {row[2][:50]}...')
    
    conn.close()
else:
    print('数据库文件不存在')