import 'package:flutter_test/flutter_test.dart';
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
}

Future<int> _insertWord(Database db, String word) async {
  var books = await db.query('word_books', limit: 1);
  final bookId = books.isEmpty
      ? await db.insert('word_books', {'name': '测试词库'})
      : books.single['id'] as int;
  return db.insert('words', {'word': word, 'word_book_id': bookId});
}
