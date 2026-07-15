import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/weakness_level.dart';
import 'package:qingmang_weiji/services/daos/weak_vocabulary_dao.dart';
import 'package:qingmang_weiji/services/weak_vocabulary_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WeakVocabularyService', () {
    late Database db;
    late WeakVocabularyService service;

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
          await db.execute('''
            CREATE TABLE session_mastery_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL,
              date TEXT NOT NULL,
              session_score REAL NOT NULL,
              attempt_count INTEGER NOT NULL,
              wrong_count INTEGER NOT NULL,
              reveal_count INTEGER NOT NULL,
              retry_count INTEGER NOT NULL,
              correct_streak INTEGER NOT NULL,
              best_mode_weight REAL NOT NULL,
              has_high_weight_verification INTEGER NOT NULL,
              has_only_recall_verification INTEGER NOT NULL,
              has_only_quiz_verification INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE review_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL,
              quality INTEGER DEFAULT 0,
              interval INTEGER DEFAULT 1,
              ease_factor REAL DEFAULT 2.5,
              repetitions INTEGER DEFAULT 0,
              next_review TEXT NOT NULL,
              last_review TEXT NOT NULL,
              FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
            )
          ''');
        },
      );
      service = WeakVocabularyService(dao: WeakVocabularyDao(Future.value(db)));
    });

    tearDown(() async {
      await db.close();
    });

    test('聚合错词、强度、掌握度和复习数据并生成严重薄弱词', () async {
      final now = DateTime.now();
      final bookId = await db.insert('word_books', {'name': '测试词库'});
      final wordId = await db.insert('words', {
        'word': 'abandon',
        'phonetic': '/əˈbændən/',
        'definition': '放弃',
        'word_book_id': bookId,
      });
      await db.insert('wrong_words', {
        'word_id': wordId,
        'wrong_count': 8,
        'first_wrong_time': now
            .subtract(const Duration(days: 10))
            .toIso8601String(),
        'last_wrong_time': now.toIso8601String(),
      });
      for (var i = 0; i < 3; i++) {
        await db.insert('wrong_words_strength', {
          'word_id': wordId,
          'is_wrong': i == 2 ? 1 : 0,
          'viewed_answer': 1,
          'review_mode': 'weak',
          'created_at': now
              .subtract(Duration(minutes: 3 - i))
              .toIso8601String(),
        });
      }
      await db.insert('session_mastery_records', {
        'word_id': wordId,
        'date': now.toIso8601String(),
        'session_score': 0.2,
        'attempt_count': 3,
        'wrong_count': 2,
        'reveal_count': 1,
        'retry_count': 1,
        'correct_streak': 0,
        'best_mode_weight': 1.0,
        'has_high_weight_verification': 0,
        'has_only_recall_verification': 0,
        'has_only_quiz_verification': 1,
        'created_at': now.toIso8601String(),
      });
      await db.insert('review_records', {
        'word_id': wordId,
        'quality': 1,
        'interval': 1,
        'ease_factor': 1.4,
        'repetitions': 1,
        'next_review': now.toIso8601String(),
        'last_review': now.toIso8601String(),
      });

      final overview = await service.getOverview(forceRefresh: true);

      expect(overview.totalCount, 1);
      expect(overview.criticalCount, 1);
      expect(overview.entries.single.word.word, 'abandon');
      expect(overview.entries.single.level, WeaknessLevel.critical);
      expect(overview.entries.single.latestReviewWrong, true);
      expect(overview.entries.single.viewedAnswerCount, 3);
      expect(overview.entries.single.score, greaterThanOrEqualTo(80));
    });

    test('invalidate 后重新读取数据库', () async {
      final now = DateTime.now();
      final bookId = await db.insert('word_books', {'name': '测试词库'});
      final wordId = await db.insert('words', {
        'word': 'cache',
        'definition': '缓存',
        'word_book_id': bookId,
      });
      await db.insert('wrong_words', {
        'word_id': wordId,
        'wrong_count': 1,
        'first_wrong_time': now.toIso8601String(),
        'last_wrong_time': now.toIso8601String(),
      });

      final first = await service.getOverview(forceRefresh: true);
      await db.update(
        'wrong_words',
        {'wrong_count': 10},
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
      final cached = await service.getOverview();
      service.invalidate(wordId: wordId);
      final refreshed = await service.getOverview();

      expect(first.entries.single.wrongCount, 1);
      expect(cached.entries.single.wrongCount, 1);
      expect(refreshed.entries.single.wrongCount, 10);
    });
  });
}
