import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/weekly_report.dart';
import 'package:qingmang_weiji/services/daos/stats_dao.dart';
import 'package:qingmang_weiji/services/daos/weak_vocabulary_dao.dart';
import 'package:qingmang_weiji/services/weak_vocabulary_service.dart';
import 'package:qingmang_weiji/services/weekly_report_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WeeklyReportService', () {
    late Database db;
    late StatsDao statsDao;
    late WeakVocabularyDao weakVocabularyDao;
    late WeakVocabularyService weakVocabularyService;
    late WeeklyReportService service;

    setUp(() async {
      db = await openDatabase(
        ':memory:',
        version: 1,
        onCreate: (db, version) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('''
            CREATE TABLE words (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word TEXT NOT NULL,
              definition TEXT,
              word_book_id INTEGER DEFAULT 1
            )
          ''');
          await db.execute('''
            CREATE TABLE review_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL,
              quality INTEGER DEFAULT 0,
              repetitions INTEGER DEFAULT 0,
              last_review TEXT NOT NULL,
              ease_factor REAL,
              next_review TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE wrong_words (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL,
              wrong_count INTEGER DEFAULT 1,
              first_wrong_time TEXT,
              last_wrong_time TEXT,
              strength REAL DEFAULT 1.0
            )
          ''');
          await db.execute('''
            CREATE TABLE wrong_words_strength (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL,
              is_wrong INTEGER NOT NULL DEFAULT 0,
              viewed_answer INTEGER NOT NULL DEFAULT 0,
              review_mode TEXT,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE daily_task_snapshots (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              completed_at TEXT,
              new_count INTEGER DEFAULT 0,
              review_count INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE session_mastery_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL,
              session_score REAL NOT NULL,
              date TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE custom_word_sets (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              last_studied_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE favorites (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER NOT NULL,
              group_name TEXT DEFAULT '默认收藏',
              created_at TEXT NOT NULL,
              last_studied_at TEXT
            )
          ''');
        },
      );
      statsDao = StatsDao(Future.value(db));
      weakVocabularyDao = WeakVocabularyDao(Future.value(db));
      weakVocabularyService = WeakVocabularyService(dao: weakVocabularyDao);
      service = WeeklyReportService(
        statsDao: statsDao,
        weakVocabularyService: weakVocabularyService,
        cacheTtl: const Duration(minutes: 5),
      );
    });

    tearDown(() async {
      await db.close();
    });

    DateTime mondayOf(DateTime date) {
      final dayOnly = DateTime(date.year, date.month, date.day);
      return dayOnly.subtract(Duration(days: dayOnly.weekday - 1));
    }

    test('空数据时周报各项指标为0', () async {
      final report = await service.buildCurrentWeekReport();
      expect(report.newWords, 0);
      expect(report.reviewWords, 0);
      expect(report.studyDays, 0);
      expect(report.averageQuality, 0);
      expect(report.planCompletedDays, 0);
      expect(report.totalSessions, 0);
      expect(report.frequentWrongWords, isEmpty);
      expect(report.topWeakWords, isEmpty);
    });

    test('新学词数正确统计（repetitions=1且quality>0）', () async {
      final weekStart = mondayOf(DateTime.now());
      final inWeek = weekStart.add(const Duration(days: 1));
      final wordId = await db.insert('words', {
        'word': 'test',
        'definition': '测试',
      });
      await db.insert('review_records', {
        'word_id': wordId,
        'quality': 4,
        'repetitions': 1,
        'last_review': inWeek.toIso8601String(),
      });
      final report = await service.buildCurrentWeekReport();
      expect(report.newWords, 1);
      expect(report.reviewWords, 0);
    });

    test('复习词数正确统计（repetitions>1且quality>0）', () async {
      final weekStart = mondayOf(DateTime.now());
      final inWeek = weekStart.add(const Duration(days: 2));
      final wordId = await db.insert('words', {
        'word': 'review',
        'definition': '复习',
      });
      await db.insert('review_records', {
        'word_id': wordId,
        'quality': 3,
        'repetitions': 3,
        'last_review': inWeek.toIso8601String(),
      });
      final report = await service.buildCurrentWeekReport();
      expect(report.reviewWords, 1);
      expect(report.newWords, 0);
    });

    test('学习天数按去重日期统计', () async {
      final weekStart = mondayOf(DateTime.now());
      final day1 = weekStart.add(const Duration(days: 1));
      final day2 = weekStart.add(const Duration(days: 2));
      final wordId = await db.insert('words', {
        'word': 'day',
        'definition': '天',
      });
      await db.insert('review_records', {
        'word_id': wordId,
        'quality': 4,
        'repetitions': 1,
        'last_review': day1.toIso8601String(),
      });
      await db.insert('review_records', {
        'word_id': wordId,
        'quality': 3,
        'repetitions': 2,
        'last_review': day1.add(const Duration(hours: 5)).toIso8601String(),
      });
      await db.insert('review_records', {
        'word_id': wordId,
        'quality': 5,
        'repetitions': 3,
        'last_review': day2.toIso8601String(),
      });
      final report = await service.buildCurrentWeekReport();
      expect(report.studyDays, 2);
    });

    test('平均质量正确计算', () async {
      final weekStart = mondayOf(DateTime.now());
      final inWeek = weekStart.add(const Duration(days: 1));
      final w1 = await db.insert('words', {'word': 'a', 'definition': ''});
      final w2 = await db.insert('words', {'word': 'b', 'definition': ''});
      final w3 = await db.insert('words', {'word': 'c', 'definition': ''});
      await db.insert('review_records', {
        'word_id': w1,
        'quality': 5,
        'repetitions': 1,
        'last_review': inWeek.toIso8601String(),
      });
      await db.insert('review_records', {
        'word_id': w2,
        'quality': 3,
        'repetitions': 1,
        'last_review': inWeek.toIso8601String(),
      });
      await db.insert('review_records', {
        'word_id': w3,
        'quality': 1,
        'repetitions': 1,
        'last_review': inWeek.toIso8601String(),
      });
      final report = await service.buildCurrentWeekReport();
      expect(report.averageQuality, closeTo(3.0, 0.1));
    });

    test('计划完成天数正确统计', () async {
      final weekStart = mondayOf(DateTime.now());
      for (int i = 0; i < 3; i++) {
        final day = weekStart.add(Duration(days: i));
        final dateStr =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        await db.insert('daily_task_snapshots', {
          'date': dateStr,
          'completed_at': day.add(const Duration(hours: 8)).toIso8601String(),
        });
      }
      // 一条未完成的
      final uncompletedDay = weekStart.add(const Duration(days: 4));
      final uncompletedDate =
          '${uncompletedDay.year}-${uncompletedDay.month.toString().padLeft(2, '0')}-${uncompletedDay.day.toString().padLeft(2, '0')}';
      await db.insert('daily_task_snapshots', {'date': uncompletedDate});
      final report = await service.buildCurrentWeekReport();
      expect(report.planCompletedDays, 3);
    });

    test('趋势对比：本周比上周进步时方向为improved', () async {
      final thisMonday = mondayOf(DateTime.now());
      final lastMonday = thisMonday.subtract(const Duration(days: 7));
      // 上周数据（少）
      final lastWordId = await db.insert('words', {
        'word': 'old',
        'definition': '',
      });
      await db.insert('review_records', {
        'word_id': lastWordId,
        'quality': 3,
        'repetitions': 1,
        'last_review': lastMonday
            .add(const Duration(days: 1))
            .toIso8601String(),
      });
      // 本周数据（多）
      for (int i = 0; i < 5; i++) {
        final wId = await db.insert('words', {'word': 'w$i', 'definition': ''});
        await db.insert('review_records', {
          'word_id': wId,
          'quality': 4,
          'repetitions': 1,
          'last_review': thisMonday
              .add(Duration(days: i % 3))
              .toIso8601String(),
        });
      }
      final report = await service.buildCurrentWeekReport();
      expect(report.trend.newWordsDelta, greaterThan(0));
      expect(report.trend.direction, WeeklyTrendDirection.improved);
    });

    test('趋势对比：本周比上周退步时方向为declined', () async {
      final thisMonday = mondayOf(DateTime.now());
      final lastMonday = thisMonday.subtract(const Duration(days: 7));
      // 上周数据（多）
      for (int i = 0; i < 6; i++) {
        final wId = await db.insert('words', {
          'word': 'old$i',
          'definition': '',
        });
        await db.insert('review_records', {
          'word_id': wId,
          'quality': 4,
          'repetitions': 1,
          'last_review': lastMonday
              .add(Duration(days: i % 3))
              .toIso8601String(),
        });
      }
      // 本周数据（少，只有1个，且质量低）
      final wId = await db.insert('words', {'word': 'now', 'definition': ''});
      await db.insert('review_records', {
        'word_id': wId,
        'quality': 1,
        'repetitions': 1,
        'last_review': thisMonday
            .add(const Duration(days: 1))
            .toIso8601String(),
      });
      final report = await service.buildCurrentWeekReport();
      expect(report.trend.newWordsDelta, lessThan(0));
      expect(report.trend.direction, WeeklyTrendDirection.declined);
    });

    test('缓存机制：连续两次调用返回同一实例（未过期）', () async {
      final weekStart = mondayOf(DateTime.now());
      final inWeek = weekStart.add(const Duration(days: 1));
      final wordId = await db.insert('words', {
        'word': 'cache',
        'definition': '',
      });
      await db.insert('review_records', {
        'word_id': wordId,
        'quality': 4,
        'repetitions': 1,
        'last_review': inWeek.toIso8601String(),
      });
      final report1 = await service.buildCurrentWeekReport();
      final report2 = await service.buildCurrentWeekReport();
      expect(identical(report1, report2), isTrue);
    });

    test('缓存机制：forceRefresh 时重新生成', () async {
      final weekStart = mondayOf(DateTime.now());
      final inWeek = weekStart.add(const Duration(days: 1));
      final wordId = await db.insert('words', {
        'word': 'cache',
        'definition': '',
      });
      await db.insert('review_records', {
        'word_id': wordId,
        'quality': 4,
        'repetitions': 1,
        'last_review': inWeek.toIso8601String(),
      });
      final report1 = await service.buildCurrentWeekReport();
      final report2 = await service.buildCurrentWeekReport(forceRefresh: true);
      expect(identical(report1, report2), isFalse);
    });

    test('invalidate 清除缓存后重新生成', () async {
      final weekStart = mondayOf(DateTime.now());
      final inWeek = weekStart.add(const Duration(days: 1));
      final wordId = await db.insert('words', {
        'word': 'inv',
        'definition': '',
      });
      await db.insert('review_records', {
        'word_id': wordId,
        'quality': 4,
        'repetitions': 1,
        'last_review': inWeek.toIso8601String(),
      });
      final report1 = await service.buildCurrentWeekReport();
      service.invalidate();
      final report2 = await service.buildCurrentWeekReport();
      expect(identical(report1, report2), isFalse);
    });

    test('周报包含正确的日期范围', () async {
      final report = await service.buildCurrentWeekReport();
      final expectedStart = mondayOf(DateTime.now());
      final expectedEnd = expectedStart.add(const Duration(days: 7));
      expect(report.weekStart.year, expectedStart.year);
      expect(report.weekStart.month, expectedStart.month);
      expect(report.weekStart.day, expectedStart.day);
      expect(
        report.weekEnd.difference(expectedEnd).inSeconds.abs(),
        lessThan(1),
      );
    });

    test('质量百分比在0-100范围内', () async {
      final weekStart = mondayOf(DateTime.now());
      final inWeek = weekStart.add(const Duration(days: 1));
      final wId = await db.insert('words', {'word': 'qp', 'definition': ''});
      await db.insert('review_records', {
        'word_id': wId,
        'quality': 5,
        'repetitions': 1,
        'last_review': inWeek.toIso8601String(),
      });
      final report = await service.buildCurrentWeekReport();
      expect(report.qualityPercent, inInclusiveRange(0, 100));
    });

    test('薄弱词库失败时周报仍能生成（不阻塞）', () async {
      final weekStart = mondayOf(DateTime.now());
      final inWeek = weekStart.add(const Duration(days: 1));
      final wId = await db.insert('words', {'word': 'safe', 'definition': ''});
      await db.insert('review_records', {
        'word_id': wId,
        'quality': 4,
        'repetitions': 1,
        'last_review': inWeek.toIso8601String(),
      });
      // 即使薄弱词库没有数据，周报也应该正常返回
      final report = await service.buildCurrentWeekReport();
      expect(report, isNotNull);
      expect(report.newWords, 1);
    });

    test('平均ease_factor正确返回', () async {
      final weekStart = mondayOf(DateTime.now());
      final inWeek = weekStart.add(const Duration(days: 1));
      final w1 = await db.insert('words', {'word': 'ef1', 'definition': ''});
      final w2 = await db.insert('words', {'word': 'ef2', 'definition': ''});
      await db.insert('review_records', {
        'word_id': w1,
        'quality': 4,
        'repetitions': 2,
        'last_review': inWeek.toIso8601String(),
        'ease_factor': 2.5,
      });
      await db.insert('review_records', {
        'word_id': w2,
        'quality': 3,
        'repetitions': 3,
        'last_review': inWeek.toIso8601String(),
        'ease_factor': 2.0,
      });
      final report = await service.buildCurrentWeekReport();
      expect(report.avgEaseFactor, closeTo(2.25, 0.1));
    });

    test('收藏组学习统计使用last_studied_at而不是不存在的added_at', () async {
      final weekStart = mondayOf(DateTime.now());
      final inWeek = weekStart.add(const Duration(days: 1));
      final outWeek = weekStart.subtract(const Duration(days: 1));
      final w1 = await db.insert('words', {'word': 'fav1', 'definition': ''});
      final w2 = await db.insert('words', {'word': 'fav2', 'definition': ''});
      final w3 = await db.insert('words', {'word': 'fav3', 'definition': ''});
      await db.insert('favorites', {
        'word_id': w1,
        'group_name': '默认收藏',
        'created_at': outWeek.toIso8601String(),
        'last_studied_at': inWeek.toIso8601String(),
      });
      await db.insert('favorites', {
        'word_id': w2,
        'group_name': '默认收藏',
        'created_at': inWeek.toIso8601String(),
        'last_studied_at': null,
      });
      await db.insert('favorites', {
        'word_id': w3,
        'group_name': '生词',
        'created_at': inWeek.toIso8601String(),
        'last_studied_at': outWeek.toIso8601String(),
      });

      final count = await statsDao.getFavoritesStudied(
        start: weekStart,
        end: weekStart.add(const Duration(days: 7)),
      );

      expect(count, 1);
    });
  });
}
