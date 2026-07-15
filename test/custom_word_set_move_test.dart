import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/daos/custom_word_set_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late CustomWordSetDao dao;
  late int sourceId;
  late int targetId;
  late int wordId;

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('''
      CREATE TABLE custom_word_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_studied_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE custom_word_set_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        set_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        added_at TEXT NOT NULL,
        UNIQUE(set_id, word_id),
        FOREIGN KEY (set_id) REFERENCES custom_word_sets(id) ON DELETE CASCADE,
        FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
      )
    ''');
    final oldTime = DateTime(2020).toIso8601String();
    sourceId = await db.insert('custom_word_sets', {
      'name': '源词集',
      'created_at': oldTime,
      'updated_at': oldTime,
    });
    targetId = await db.insert('custom_word_sets', {
      'name': '目标词集',
      'created_at': oldTime,
      'updated_at': oldTime,
    });
    wordId = await db.insert('words', {'word': 'move'});
    await db.insert('custom_word_set_items', {
      'set_id': sourceId,
      'word_id': wordId,
      'sort_order': 1,
      'added_at': oldTime,
    });
    dao = CustomWordSetDao(Future.value(db));
  });

  tearDown(() async {
    await db.close();
  });

  test('移动成功原子完成添加删除并更新两个词集时间', () async {
    await dao.moveWords(sourceId, targetId, [wordId]);

    expect(await dao.getWordCount(sourceId), 0);
    expect(await dao.getWordCount(targetId), 1);
    final source = await db.query(
      'custom_word_sets',
      where: 'id = ?',
      whereArgs: [sourceId],
    );
    final target = await db.query(
      'custom_word_sets',
      where: 'id = ?',
      whereArgs: [targetId],
    );
    expect(source.single['updated_at'], isNot(DateTime(2020).toIso8601String()));
    expect(target.single['updated_at'], isNot(DateTime(2020).toIso8601String()));
  });

  test('移动中删除失败时回滚目标添加和更新时间', () async {
    await db.execute('''
      CREATE TRIGGER fail_source_delete
      BEFORE DELETE ON custom_word_set_items
      WHEN OLD.set_id = $sourceId
      BEGIN
        SELECT RAISE(ABORT, 'delete failed');
      END
    ''');
    final before = await db.query('custom_word_sets', orderBy: 'id');

    await expectLater(
      dao.moveWords(sourceId, targetId, [wordId]),
      throwsA(isA<DatabaseException>()),
    );

    expect(await dao.getWordCount(sourceId), 1);
    expect(await dao.getWordCount(targetId), 0);
    final after = await db.query('custom_word_sets', orderBy: 'id');
    expect(after.map((row) => row['updated_at']), before.map((row) => row['updated_at']));
  });
}
