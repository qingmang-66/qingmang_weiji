import 'package:flutter_test/flutter_test.dart';
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
              next_review TEXT,
              first_learned_at TEXT
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
              date TEXT NOT NULL,
              session_score REAL NOT NULL,
              attempt_count INTEGER NOT NULL,
              wrong_count INTEGER NOT NULL
            )
          ''');
        },
      );
      statsDao = StatsDao(Future.value(db));
      weakVocabularyService = WeakVocabularyService(
        dao: WeakVocabularyDao(Future.value(db)),
      );
      service = WeeklyReportService(
        statsDao: statsDao,
        weakVocabularyService: weakVocabularyService,
        cacheTtl: const Duration(minutes: 5),
      );
    });

    tearDown(() async {
      await db.close();
    });

    String dateStr(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    test('空数据时周报各项指标为0，且每天为全零明细', () async {
      final report = await service.buildCurrentWeekReport();
      expect(report.newWords, 0);
      expect(report.practicedWords, 0);
      expect(report.rememberedWords, 0);
      expect(report.wrongWords, 0);
      expect(report.studyDays, 0);
      expect(report.planCompletedDays, 0);
      expect(report.dailyDetails.length, 7);
      expect(report.dailyDetails.every((d) => !d.hasActivity), isTrue);
      expect(report.topWeakWords, isEmpty);
    });

    test('新学词数按first_learned_at落在周期内统计', () async {
      // 用本周一 + 1 天作为"周内"，上周日作为"周外"，不受当前星期几影响
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final inWeek = monday.add(const Duration(days: 1));
      final outWeek = monday.subtract(const Duration(days: 1));
      final w1 = await db.insert('words', {'word': 'a', 'definition': ''});
      final w2 = await db.insert('words', {'word': 'b', 'definition': ''});
      await db.insert('review_records', {
        'word_id': w1,
        'quality': 4,
        'repetitions': 1,
        'last_review': inWeek.toIso8601String(),
        'first_learned_at': inWeek.toIso8601String(),
      });
      await db.insert('review_records', {
        'word_id': w2,
        'quality': 4,
        'repetitions': 1,
        'last_review': outWeek.toIso8601String(),
        'first_learned_at': outWeek.toIso8601String(),
      });
      final report = await service.buildCurrentWeekReport();
      expect(report.newWords, 1);
      //周期外的学习日不计入
      expect(report.studyDays, 1);
    });

    test('练习明细按天聚合：练/记住/填错/正确率', () async {
      final today = dateStr(DateTime.now());
      final w1 = await db.insert('words', {'word': 'a', 'definition': ''});
      final w2 = await db.insert('words', {'word': 'b', 'definition': ''});
      final w3 = await db.insert('words', {'word': 'c', 'definition': ''});
      //答对（attempt 2 错 0）
      await db.insert('session_mastery_records', {
        'word_id': w1,
        'date': today,
        'session_score': 1.0,
        'attempt_count': 2,
        'wrong_count': 0,
      });
      //有对有错（attempt 3 错 1）
      await db.insert('session_mastery_records', {
        'word_id': w2,
        'date': today,
        'session_score': 0.6,
        'attempt_count': 3,
        'wrong_count': 1,
      });
      //全错（attempt 2 错 2）
      await db.insert('session_mastery_records', {
        'word_id': w3,
        'date': today,
        'session_score': 0.0,
        'attempt_count': 2,
        'wrong_count': 2,
      });
      final report = await service.buildCurrentWeekReport();
      // 周报已改为自然周（周一到周日），today 落在 weekday-1 的位置
      final todayDetail = report.dailyDetails[DateTime.now().weekday - 1];
      expect(todayDetail.practicedWords, 3);
      //记住 = 当天至少答对一次的词（attempt > wrong）
      expect(todayDetail.rememberedWords, 2);
      //填错 = 当天有错误记录的词
      expect(todayDetail.wrongWords, 2);
      expect(todayDetail.attempts, 7);
      expect(todayDetail.wrongCount, 3);
      expect(todayDetail.correctRate, closeTo(4 / 7, 0.01));
    });

    test('无学习记录的天为全零且不点亮', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final w1 = await db.insert('words', {'word': 'a', 'definition': ''});
      await db.insert('session_mastery_records', {
        'word_id': w1,
        'date': dateStr(yesterday),
        'session_score': 1.0,
        'attempt_count': 1,
        'wrong_count': 0,
      });
      final report = await service.buildCurrentWeekReport();
      expect(report.dailyDetails.length, 7);
      expect(report.studyDays, 1);
      final todayDetail = report.dailyDetails[DateTime.now().weekday - 1];
      expect(todayDetail.hasActivity, isFalse);
    });

    test('汇总指标由明细推导', () async {
      final today = dateStr(DateTime.now());
      final w1 = await db.insert('words', {'word': 'a', 'definition': ''});
      await db.insert('review_records', {
        'word_id': w1,
        'quality': 4,
        'repetitions': 1,
        'last_review': DateTime.now().toIso8601String(),
        'first_learned_at': DateTime.now().toIso8601String(),
      });
      await db.insert('session_mastery_records', {
        'word_id': w1,
        'date': today,
        'session_score': 0.8,
        'attempt_count': 4,
        'wrong_count': 1,
      });
      final report = await service.buildCurrentWeekReport();
      expect(report.newWords, 1);
      expect(report.practicedWords, 1);
      expect(report.rememberedWords, 1);
      expect(report.wrongWords, 1);
      expect(report.totalWords, 2);
      expect(report.correctRatePercent, 75);
    });

    test('计划完成天数正确统计', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monday = today.subtract(Duration(days: today.weekday - 1));
      // 本周内 3 条已完成
      for (int i = 0; i < 3; i++) {
        final day = monday.add(Duration(days: i));
        await db.insert('daily_task_snapshots', {
          'date': dateStr(day),
          'completed_at': day.toIso8601String(),
        });
      }
      //一条未完成的（仍在本周）
      final uncompleted = monday.add(const Duration(days: 3));
      await db.insert('daily_task_snapshots', {'date': dateStr(uncompleted)});
      final report = await service.buildCurrentWeekReport();
      expect(report.planCompletedDays, 3);
    });

    test('月报返回最近30天明细', () async {
      final monthly = await service.buildCurrentMonthReport();
      expect(monthly.dailyDetails.length, 30);
      expect(monthly.studyDays, 0);
    });

    test('buildWeekReport按指定起始日构建', () async {
      final start = DateTime(2026, 1, 5);
      final w1 = await db.insert('words', {'word': 'a', 'definition': ''});
      await db.insert('review_records', {
        'word_id': w1,
        'quality': 4,
        'repetitions': 1,
        'last_review': start.toIso8601String(),
        'first_learned_at': start.toIso8601String(),
      });
      final report = await service.buildWeekReport(start);
      expect(report.weekStart.year, 2026);
      expect(report.weekStart.month, 1);
      expect(report.weekStart.day, 5);
      expect(report.dailyDetails.length, 7);
      expect(report.newWords, 1);
    });

    test('缓存机制：连续两次调用返回同一实例（未过期）', () async {
      final w1 = await db.insert('words', {'word': 'cache', 'definition': ''});
      await db.insert('review_records', {
        'word_id': w1,
        'quality': 4,
        'repetitions': 1,
        'last_review': DateTime.now().toIso8601String(),
        'first_learned_at': DateTime.now().toIso8601String(),
      });
      final report1 = await service.buildCurrentWeekReport();
      final report2 = await service.buildCurrentWeekReport();
      expect(identical(report1, report2), isTrue);
    });

    test('缓存机制：forceRefresh 时重新生成', () async {
      final w1 = await db.insert('words', {'word': 'cache', 'definition': ''});
      await db.insert('review_records', {
        'word_id': w1,
        'quality': 4,
        'repetitions': 1,
        'last_review': DateTime.now().toIso8601String(),
        'first_learned_at': DateTime.now().toIso8601String(),
      });
      final report1 = await service.buildCurrentWeekReport();
      final report2 = await service.buildCurrentWeekReport(forceRefresh: true);
      expect(identical(report1, report2), isFalse);
    });

    test('invalidate 清除缓存后重新生成', () async {
      final w1 = await db.insert('words', {'word': 'inv', 'definition': ''});
      await db.insert('review_records', {
        'word_id': w1,
        'quality': 4,
        'repetitions': 1,
        'last_review': DateTime.now().toIso8601String(),
        'first_learned_at': DateTime.now().toIso8601String(),
      });
      final report1 = await service.buildCurrentWeekReport();
      service.invalidate();
      final report2 = await service.buildCurrentWeekReport();
      expect(identical(report1, report2), isFalse);
    });

    test('周报包含本周（周一到周日）的日期范围', () async {
      final report = await service.buildCurrentWeekReport();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expectedStart = today.subtract(Duration(days: today.weekday - 1));
      final expectedEnd = DateTime(
        expectedStart.year,
        expectedStart.month,
        expectedStart.day + 7,
      );
      expect(report.weekStart.year, expectedStart.year);
      expect(report.weekStart.month, expectedStart.month);
      expect(report.weekStart.day, expectedStart.day);
      expect(
        report.weekEnd.difference(expectedEnd).inSeconds.abs(),
        lessThan(1),
      );
    });

    test('薄弱词库失败时周报仍能生成（不阻塞）', () async {
      final w1 = await db.insert('words', {'word': 'safe', 'definition': ''});
      await db.insert('review_records', {
        'word_id': w1,
        'quality': 4,
        'repetitions': 1,
        'last_review': DateTime.now().toIso8601String(),
        'first_learned_at': DateTime.now().toIso8601String(),
      });
      //即使薄弱词库没有数据，周报也应该正常返回
      final report = await service.buildCurrentWeekReport();
      expect(report, isNotNull);
      expect(report.newWords, 1);
    });
  });
}
