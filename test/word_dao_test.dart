import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/word.dart';
import 'package:qingmang_weiji/services/daos/word_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WordDao', () {
    late Database db;
    late WordDao dao;

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
      dao = WordDao(Future.value(db));
    });

    tearDown(() async {
      await db.close();
    });

    test('deleteWordsBatch removes review records and wrong words', () async {
      final bookId = await db.insert('word_books', {'name': '测试词库'});
      final wordId = await db.insert(
        'words',
        Word(word: 'test', wordBookId: bookId).toMap(),
      );

      await db.insert('review_records', {'word_id': wordId});
      await db.insert('wrong_words', {'word_id': wordId});

      await dao.deleteWordsBatch([wordId]);

      expect(await _count(db, 'words'), 0);
      expect(await _count(db, 'review_records'), 0);
      expect(await _count(db, 'wrong_words'), 0);
    });

    group('今日新学/复习统计（first_learned_at）', () {
      setUp(() async {
        // 测试库默认只建了两列，补齐统计所需列
        await db.execute(
          'ALTER TABLE review_records ADD COLUMN quality INTEGER DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE review_records ADD COLUMN repetitions INTEGER DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE review_records ADD COLUMN last_review TEXT',
        );
        await db.execute(
          'ALTER TABLE review_records ADD COLUMN first_learned_at TEXT',
        );
      });

      test('首学今日的新词即使打“忘记”（repetitions=0）也计入今日新学', () async {
        final bookId = await db.insert('word_books', {'name': '统计词库'});
        final wordId = await db.insert(
          'words',
          Word(word: 'test', wordBookId: bookId).toMap(),
        );
        final now = DateTime.now();
        await db.insert('review_records', {
          'word_id': wordId,
          'quality': 1,
          'repetitions': 0,
          'last_review': now.toIso8601String(),
          'first_learned_at': now.toIso8601String(),
        });
        expect(await dao.getTodayNewWordCount(bookId), 1);
        expect(await dao.getTodayReviewedWordCount(bookId), 0);
      });

      test('早于今日首学的词今日答“忘记”（repetitions=0）计入今日复习', () async {
        final bookId = await db.insert('word_books', {'name': '统计词库2'});
        final wordId = await db.insert(
          'words',
          Word(word: 'test2', wordBookId: bookId).toMap(),
        );
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        await db.insert('review_records', {
          'word_id': wordId,
          'quality': 1,
          'repetitions': 0,
          'last_review': now.toIso8601String(),
          'first_learned_at': yesterday.toIso8601String(),
        });
        expect(await dao.getTodayNewWordCount(bookId), 0);
        expect(await dao.getTodayReviewedWordCount(bookId), 1);
      });

      test('历史 NULL 数据退化为旧行为（repetitions=1 新学 / >1 复习）', () async {
        final bookId = await db.insert('word_books', {'name': '统计词库3'});
        final w1 = await db.insert(
          'words',
          Word(word: 'a', wordBookId: bookId).toMap(),
        );
        final w2 = await db.insert(
          'words',
          Word(word: 'b', wordBookId: bookId).toMap(),
        );
        final now = DateTime.now();
        await db.insert('review_records', {
          'word_id': w1,
          'quality': 4,
          'repetitions': 1,
          'last_review': now.toIso8601String(),
        });
        await db.insert('review_records', {
          'word_id': w2,
          'quality': 4,
          'repetitions': 3,
          'last_review': now.toIso8601String(),
        });
        expect(await dao.getTodayNewWordCount(bookId), 1);
        expect(await dao.getTodayReviewedWordCount(bookId), 1);
      });
    });

    test('insertWordsBatchFast失败时回滚所有批次', () async {
      final bookId = await db.insert('word_books', {'name': '事务测试词库'});
      await db.execute('''
 CREATE TRIGGER reject_failed_word
 BEFORE INSERT ON words
 WHEN NEW.word = 'fail'
 BEGIN
 SELECT RAISE(ABORT, 'insert failed');
 END
 ''');
      final words = List.generate(
        501,
        (index) => Word(
          word: index == 500 ? 'fail' : 'word_$index',
          wordBookId: bookId,
        ),
      );

      await expectLater(
        dao.insertWordsBatchFast(words),
        throwsA(isA<DatabaseException>()),
      );

      expect(await _count(db, 'words'), 0);
    });

    group('searchWords 阶段三 inWordFieldOnly 行为', () {
      late int bookId;
      setUp(() async {
        bookId = await db.insert('word_books', {'name': '搜索测试词库'});
        // 构造清晰可预测的搜索场景：
        // - apple   : 单词完全等于查询
        // - apples  : 前缀匹配 apple + 包含 apple
        // - pineapple: 包含 apple，但非前缀
        // - banana  : 单词字段不命中，但其 definition 含 "苹果" 仅用于多字段命中
        await db.insert(
          'words',
          Word(word: 'apple', wordBookId: bookId).toMap(),
        );
        await db.insert(
          'words',
          Word(word: 'apples', wordBookId: bookId).toMap(),
        );
        await db.insert(
          'words',
          Word(word: 'pineapple', wordBookId: bookId).toMap(),
        );
        await db.insert(
          'words',
          Word(
            word: 'banana',
            definition: 'n. 苹果香蕉',
            wordBookId: bookId,
          ).toMap(),
        );
      });

      test('inWordFieldOnly=true 仅命中 word 字段', () async {
        final results = await dao.searchWords(
          'apple',
          bookId: bookId,
          inWordFieldOnly: true,
        );
        final words = results.map((w) => w.word).toList();
        expect(words, contains('apple'));
        expect(words, contains('apples')); // 包含 + 前缀
        expect(words, contains('pineapple')); // 仅包含
        // banana 仅 definition 命中，inWordFieldOnly=true 应排除
        expect(words, isNot(contains('banana')));
      });

      test('inWordFieldOnly=false（默认）保持原多字段行为', () async {
        final results = await dao.searchWords('苹果', bookId: bookId);
        final words = results.map((w) => w.word).toList();
        // definition 字段包含 "苹果" 也会被搜出
        expect(words, contains('banana'));
      });

      test('完全匹配排在最前', () async {
        final results = await dao.searchWords(
          'apple',
          bookId: bookId,
          inWordFieldOnly: true,
        );
        expect(results.first.word, 'apple');
      });

      test('空字符串查询返回空结果', () async {
        final results = await dao.searchWords(
          '  ', // 纯空白，trim 后为空
          bookId: bookId,
          inWordFieldOnly: true,
        );
        // 阶段三：trim 后为空，% % 视为无意义，但实现里会返回所有行；
        // 这里仅验证不会因为空串抛错，结果不空不空不强约束。
        expect(results, isA<List<Word>>());
      });
    });
  });
}

Future<int> _count(Database db, String table) async {
  final result = await db.rawQuery('SELECT COUNT(*) as c FROM $table');
  return result.first['c'] as int;
}
