import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/database_service.dart';
import 'package:qingmang_weiji/services/daos/wrong_word_dao.dart';
import 'package:qingmang_weiji/services/wrong_word_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WrongWordDao strength events', () {
    late Database db;
    late WrongWordDao dao;

    setUp(() async {
      db = await openDatabase(
        ':memory:',
        version: 1,
        onCreate: (db, version) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('''
            CREATE TABLE word_books (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE words (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word TEXT NOT NULL,
              phonetic TEXT,
              definition TEXT,
              example TEXT,
              example_translation TEXT,
              word_book_id INTEGER NOT NULL,
              root TEXT,
              suffix TEXT,
              synonym TEXT,
              antonym TEXT,
              derivative TEXT,
              FOREIGN KEY (word_book_id) REFERENCES word_books(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE wrong_words (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL,
              wrong_count INTEGER DEFAULT 1,
              first_wrong_time TEXT,
              last_wrong_time TEXT,
              note TEXT,
              strength REAL DEFAULT 0,
              FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE wrong_words_strength (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL,
              is_wrong INTEGER NOT NULL DEFAULT 0,
              viewed_answer INTEGER NOT NULL DEFAULT 0,
              review_mode TEXT,
              created_at TEXT NOT NULL,
              FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            )
          ''');
        },
      );
      dao = WrongWordDao(Future.value(db));
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> insertWrongWord({int wrongCount = 1}) async {
      final bookId = await db.insert('word_books', {'name': '测试词库'});
      final wordId = await db.insert('words', {
        'word': 'test',
        'definition': '测试',
        'word_book_id': bookId,
      });
      await db.insert('wrong_words', {
        'word_id': wordId,
        'wrong_count': wrongCount,
        'first_wrong_time': DateTime.now().toIso8601String(),
        'last_wrong_time': DateTime.now().toIso8601String(),
      });
      return wordId;
    }

    test('addStrengthEvent 写入错词强度事件', () async {
      final bookId = await db.insert('word_books', {'name': '测试词库'});
      final wordId = await db.insert('words', {
        'word': 'weak',
        'definition': '薄弱',
        'word_book_id': bookId,
      });

      await dao.addStrengthEvent(
        wordId: wordId,
        isWrong: true,
        viewedAnswer: true,
        reviewMode: 'weak_vocabulary',
      );

      final rows = await db.query('wrong_words_strength');
      expect(rows.length, 1);
      expect(rows.single['word_id'], wordId);
      expect(rows.single['is_wrong'], 1);
      expect(rows.single['viewed_answer'], 1);
      expect(rows.single['review_mode'], 'weak_vocabulary');
    });

    test('updateStrength 更新 wrong_words.strength', () async {
      final wordId = await insertWrongWord();

      await dao.updateStrength(wordId, 72.5);

      final rows = await db.query(
        'wrong_words',
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
      expect(rows.single['strength'], 72.5);
    });

    test('reduceWrongCount并发递减不丢失更新', () async {
      final wordId = await insertWrongWord(wrongCount: 5);

      await Future.wait(List.generate(4, (_) => dao.reduceWrongCount(wordId)));

      expect(await dao.getWrongCount(wordId), 1);
    });

    test('reduceWrongCount最低保持1', () async {
      final wordId = await insertWrongWord();

      await dao.reduceWrongCount(wordId);

      expect(await dao.getWrongCount(wordId), 1);
    });
  });

  test('WrongWordService添加失败向调用方传播', () async {
    final db = await DatabaseService.database;
    await db.execute('PRAGMA foreign_keys = ON');
    final invalidWordId = -DateTime.now().microsecondsSinceEpoch;

    await expectLater(
      WrongWordService().addWrongWord(invalidWordId),
      throwsA(isA<DatabaseException>()),
    );
  });
}
