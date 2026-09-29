import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/daos/wordbook_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WordBookDao', () {
    late Database db;
    late WordBookDao dao;

    setUp(() async {
      db = await openDatabase(
        ':memory:',
        version: 1,
        onCreate: (db, version) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('''
            CREATE TABLE word_books (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              description TEXT,
              is_built_in INTEGER DEFAULT 0,
              total_words INTEGER DEFAULT 0,
              version TEXT,
              sort_order INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE words (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word TEXT NOT NULL,
              word_book_id INTEGER NOT NULL,
              FOREIGN KEY (word_book_id) REFERENCES word_books(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE review_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL,
              FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE wrong_words (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL,
              FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            )
          ''');
        },
      );
      dao = WordBookDao(Future.value(db));
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'deleteWordBook removes all data linked to words in the book',
      () async {
        final bookId = await db.insert('word_books', {'name': '测试词库'});
        final wordId = await db.insert('words', {
          'word': 'test',
          'word_book_id': bookId,
        });
        await db.insert('review_records', {'word_id': wordId});
        await db.insert('wrong_words', {'word_id': wordId});

        await dao.deleteWordBook(bookId);

        expect(await _count(db, 'word_books'), 0);
        expect(await _count(db, 'words'), 0);
        expect(await _count(db, 'review_records'), 0);
        expect(await _count(db, 'wrong_words'), 0);
      },
    );

    test(
      'deleteWordBooksBatch removes all data linked to words in deleted books',
      () async {
        final bookId = await db.insert('word_books', {'name': '测试词库'});
        final wordId = await db.insert('words', {
          'word': 'test',
          'word_book_id': bookId,
        });
        await db.insert('review_records', {'word_id': wordId});
        await db.insert('wrong_words', {'word_id': wordId});

        await dao.deleteWordBooksBatch([bookId]);

        expect(await _count(db, 'word_books'), 0);
        expect(await _count(db, 'words'), 0);
        expect(await _count(db, 'review_records'), 0);
        expect(await _count(db, 'wrong_words'), 0);
      },
    );
    test(
      'resetBookProgress clears progress but keeps words and other books',
      () async {
        final bookId = await db.insert('word_books', {'name': '测试词库'});
        final otherBookId = await db.insert('word_books', {'name': '另一词库'});
        final wordId = await db.insert('words', {
          'word': 'test',
          'word_book_id': bookId,
        });
        final otherWordId = await db.insert('words', {
          'word': 'other',
          'word_book_id': otherBookId,
        });
        await db.insert('review_records', {'word_id': wordId});
        await db.insert('wrong_words', {'word_id': wordId});
        await db.insert('review_records', {'word_id': otherWordId});

        await dao.resetBookProgress(bookId);

        //进度清空，单词与词库保留
        expect(await _count(db, 'review_records'), 1);
        expect(await _count(db, 'wrong_words'), 0);
        expect(await _count(db, 'words'), 2);
        expect(await _count(db, 'word_books'), 2);
        //另一词库的进度不受影响
        final rest = await db.rawQuery(
          'SELECT word_id FROM review_records WHERE word_id = ?',
          [otherWordId],
        );
        expect(rest.length, 1);
      },
    );
  });
}

Future<int> _count(Database db, String table) async {
  final result = await db.rawQuery('SELECT COUNT(*) as c FROM $table');
  return result.first['c'] as int;
}
