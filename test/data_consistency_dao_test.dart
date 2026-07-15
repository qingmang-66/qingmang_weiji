import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/daos/custom_word_set_dao.dart';
import 'package:qingmang_weiji/services/daos/wrong_word_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE word_books (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL,
            word_book_id INTEGER NOT NULL,
            FOREIGN KEY (word_book_id) REFERENCES word_books(id) ON DELETE CASCADE
          )
        ''');
        await database.execute('''
          CREATE TABLE wrong_words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL UNIQUE,
            wrong_count INTEGER NOT NULL DEFAULT 1,
            first_wrong_time TEXT,
            last_wrong_time TEXT,
            note TEXT,
            FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
          )
        ''');
        await database.execute('''
          CREATE TABLE custom_word_sets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_studied_at TEXT
          )
        ''');
        await database.execute('''
          CREATE TABLE custom_word_set_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            set_id INTEGER NOT NULL,
            word_id INTEGER NOT NULL,
            sort_order INTEGER DEFAULT 0,
            added_at TEXT NOT NULL,
            FOREIGN KEY (set_id) REFERENCES custom_word_sets(id) ON DELETE CASCADE,
            FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE,
            UNIQUE(set_id, word_id)
          )
        ''');
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('reduceWrongCount原子递减且最低保持1', () async {
    final wordId = await _insertWord(db, 'wrong');
    await db.insert('wrong_words', {
      'word_id': wordId,
      'wrong_count': 2,
      'first_wrong_time': '2026-01-01T00:00:00.000',
      'last_wrong_time': '2026-01-01T00:00:00.000',
    });
    final dao = WrongWordDao(Future.value(db));

    await Future.wait([
      dao.reduceWrongCount(wordId),
      dao.reduceWrongCount(wordId),
    ]);

    expect(await dao.getWrongCount(wordId), 1);
  });

  test('moveWords成功移动并更新两个词集时间', () async {
    final wordIds = [await _insertWord(db, 'one'), await _insertWord(db, 'two')];
    final sourceId = await _insertSet(db, '源词集');
    final targetId = await _insertSet(db, '目标词集');
    for (var i = 0; i < wordIds.length; i++) {
      await db.insert('custom_word_set_items', {
        'set_id': sourceId,
        'word_id': wordIds[i],
        'sort_order': i + 1,
        'added_at': '2026-01-01T00:00:00.000',
      });
    }
    final dao = CustomWordSetDao(Future.value(db));

    await dao.moveWords(sourceId, targetId, wordIds);

    expect(await dao.getWordCount(sourceId), 0);
    expect(await dao.getWordCount(targetId), 2);
    final sets = await db.query('custom_word_sets', orderBy: 'id');
    expect(sets.every((row) => row['updated_at'] != '2026-01-01T00:00:00.000'), isTrue);
  });

  test('moveWords目标添加失败时回滚源删除和更新时间', () async {
    final firstId = await _insertWord(db, 'first');
    final secondId = await _insertWord(db, 'second');
    final sourceId = await _insertSet(db, '源词集');
    final targetId = await _insertSet(db, '目标词集');
    for (final wordId in [firstId, secondId]) {
      await db.insert('custom_word_set_items', {
        'set_id': sourceId,
        'word_id': wordId,
        'sort_order': wordId,
        'added_at': '2026-01-01T00:00:00.000',
      });
    }
    await db.execute('''
      CREATE TRIGGER reject_second_move
      BEFORE INSERT ON custom_word_set_items
      WHEN NEW.set_id = $targetId AND NEW.word_id = $secondId
      BEGIN
        SELECT RAISE(ABORT, 'move failed');
      END
    ''');
    final dao = CustomWordSetDao(Future.value(db));

    await expectLater(
      dao.moveWords(sourceId, targetId, [firstId, secondId]),
      throwsA(isA<DatabaseException>()),
    );

    expect(await dao.getWordCount(sourceId), 2);
    expect(await dao.getWordCount(targetId), 0);
    final sets = await db.query('custom_word_sets', orderBy: 'id');
    expect(sets.every((row) => row['updated_at'] == '2026-01-01T00:00:00.000'), isTrue);
  });
}

Future<int> _insertWord(Database db, String word) async {
  var books = await db.query('word_books', limit: 1);
  final bookId = books.isEmpty
      ? await db.insert('word_books', {'name': '测试词库'})
      : books.single['id'] as int;
  return db.insert('words', {'word': word, 'word_book_id': bookId});
}

Future<int> _insertSet(Database db, String name) => db.insert('custom_word_sets', {
  'name': name,
  'created_at': '2026-01-01T00:00:00.000',
  'updated_at': '2026-01-01T00:00:00.000',
});
