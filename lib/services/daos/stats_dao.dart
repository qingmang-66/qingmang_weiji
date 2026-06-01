import 'package:sqflite/sqflite.dart';
import '../../models/review_forecast.dart';

/// 统计数据访问对象
class StatsDao {
  final Future<Database> _dbFuture;

  StatsDao(this._dbFuture);

  Future<Map<String, dynamic>> getStudyStats() async {
    final db = await _dbFuture;
    final totalWords = await db.rawQuery('SELECT COUNT(*) as c FROM words');
    final learnedWords = await db.rawQuery(
      'SELECT COUNT(DISTINCT word_id) as c FROM review_records',
    );
    final totalReviews = await db.rawQuery(
      'SELECT COUNT(*) as c FROM review_records WHERE quality > 0',
    );
    final favoriteCount = await db.rawQuery(
      'SELECT COUNT(*) as c FROM favorites',
    );
    final customSetCount = await db.rawQuery(
      'SELECT COUNT(*) as c FROM custom_word_sets',
    );
    final dueWords = await db.rawQuery(
      '''
      SELECT COUNT(*) as c FROM review_records WHERE next_review <= ?
    ''',
      [DateTime.now().toIso8601String()],
    );

    final today = DateTime.now();
    final todayStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).toIso8601String();

    final todayNewResult = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT word_id) as c FROM review_records
      WHERE last_review >= ? AND repetitions = 1 AND quality > 0
    ''',
      [todayStart],
    );

    final todayReviewResult = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT word_id) as c FROM review_records
      WHERE last_review >= ? AND repetitions > 1 AND quality > 0
    ''',
      [todayStart],
    );

    final streak = await _calculateStreak(db);

    // 使用 MemoryStage 枚举名称作为 key，确保跨语言一致性
    final stages = <String, int>{
      'newLearned': 0,
      'initial': 0,
      'consolidating': 0,
      'familiar': 0,
      'mastered': 0,
    };
    final stageResult = await db.rawQuery('''
      SELECT
        CASE
          WHEN repetitions = 0 THEN 'newLearned'
          WHEN repetitions <= 1 THEN 'initial'
          WHEN repetitions <= 3 THEN 'consolidating'
          WHEN repetitions <= 5 THEN 'familiar'
          ELSE 'mastered'
        END as stage,
        COUNT(*) as cnt
      FROM review_records
      GROUP BY stage
    ''');
    for (final row in stageResult) {
      final stage = row['stage'] as String?;
      final cnt = row['cnt'] as int? ?? 0;
      if (stage != null && stages.containsKey(stage)) {
        stages[stage] = cnt;
      }
    }

    return {
      'totalWords': (totalWords.first['c'] as int?) ?? 0,
      'learnedWords': (learnedWords.first['c'] as int?) ?? 0,
      'totalReviews': (totalReviews.first['c'] as int?) ?? 0,
      'favoriteCount': (favoriteCount.first['c'] as int?) ?? 0,
      'customSetCount': (customSetCount.first['c'] as int?) ?? 0,
      'dueWords': (dueWords.first['c'] as int?) ?? 0,
      'todayNew': (todayNewResult.first['c'] as int?) ?? 0,
      'todayReview': (todayReviewResult.first['c'] as int?) ?? 0,
      'streak': streak,
      'stages': stages,
    };
  }

  /// 计算连续学习天数（从今天或昨天开始向前连续追溯）
  Future<int> _calculateStreak(Database db) async {
    final records = await db.rawQuery('''
      SELECT DISTINCT date(last_review) as study_date FROM review_records
      ORDER BY study_date DESC LIMIT 366
    ''');
    if (records.isEmpty) return 0;

    final dateStrings = records.map((r) => r['study_date'] as String).toSet();

    String formatDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final now = DateTime.now();
    DateTime check = DateTime(now.year, now.month, now.day);

    if (!dateStrings.contains(formatDate(check))) {
      check = check.subtract(const Duration(days: 1));
    }

    int streak = 0;
    while (dateStrings.contains(formatDate(check))) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<List<Map<String, dynamic>>> getDailyReviewStats({
    int days = 30,
  }) async {
    final db = await _dbFuture;
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final startDateStr = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    ).toIso8601String();

    final result = await db.rawQuery(
      '''
      SELECT date(last_review) as study_date, COUNT(*) as count
      FROM review_records
      WHERE last_review >= ?
      GROUP BY date(last_review)
      ORDER BY study_date ASC
    ''',
      [startDateStr],
    );

    final Map<String, int> dateCountMap = {};
    for (final row in result) {
      final date = row['study_date'] as String;
      dateCountMap[date] = row['count'] as int;
    }

    final List<Map<String, dynamic>> dailyData = [];
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyData.add({'date': date, 'count': dateCountMap[dateStr] ?? 0});
    }

    return dailyData;
  }

  Future<ReviewForecast> getReviewForecast({int days = 7}) async {
    final db = await _dbFuture;
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day);
    final endDate = startDate.add(Duration(days: days));

    final result = await db.rawQuery(
      '''
      SELECT date(next_review) as review_date, COUNT(*) as count
      FROM review_records
      WHERE next_review >= ? AND next_review < ?
      GROUP BY date(next_review)
      ORDER BY review_date ASC
    ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    final countMap = <String, int>{};
    for (final row in result) {
      final date = row['review_date'] as String;
      countMap[date] = row['count'] as int;
    }

    final forecastDays = <ReviewForecastDay>[];
    for (var i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = _formatDate(date);
      forecastDays.add(
        ReviewForecastDay(date: date, count: countMap[dateStr] ?? 0),
      );
    }

    return ReviewForecast(days: forecastDays);
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> getOverallStats(int bookId) async {
    final db = await _dbFuture;

    final totalWords =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM words WHERE word_book_id = ?',
            [bookId],
          ),
        ) ??
        0;

    final learnedWords =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''SELECT COUNT(DISTINCT word_id) FROM review_records
         WHERE word_id IN (SELECT id FROM words WHERE word_book_id = ?)''',
            [bookId],
          ),
        ) ??
        0;

    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todayReview =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''SELECT COUNT(*) FROM review_records
         WHERE word_id IN (SELECT id FROM words WHERE word_book_id = ?)
         AND date(last_review) = ?''',
            [bookId, todayStr],
          ),
        ) ??
        0;

    final dueWords =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''SELECT COUNT(*) FROM review_records r
         INNER JOIN words w ON r.word_id = w.id
         WHERE w.word_book_id = ? AND datetime(r.next_review) <= datetime(?)''',
            [bookId, today.toIso8601String()],
          ),
        ) ??
        0;

    final totalReviews =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''SELECT COUNT(*) FROM review_records
         WHERE word_id IN (SELECT id FROM words WHERE word_book_id = ?)''',
            [bookId],
          ),
        ) ??
        0;

    final avgQualityResult = await db.rawQuery(
      '''SELECT AVG(quality) as avg_q FROM review_records 
         WHERE word_id IN (SELECT id FROM words WHERE word_book_id = ?)''',
      [bookId],
    );
    final avgQuality = (avgQualityResult.first['avg_q'] as double?) ?? 0.0;

    return {
      'total_words': totalWords,
      'learned_words': learnedWords,
      'today_review': todayReview,
      'due_words': dueWords,
      'total_reviews': totalReviews,
      'avg_quality': avgQuality,
    };
  }

  Future<List<Map<String, dynamic>>> getQualityDistribution(int bookId) async {
    final db = await _dbFuture;
    final result = await db.rawQuery(
      '''
      SELECT quality, COUNT(*) as count FROM review_records
      WHERE word_id IN (SELECT id FROM words WHERE word_book_id = ?)
      GROUP BY quality
      ORDER BY quality ASC
    ''',
      [bookId],
    );
    return result
        .map(
          (row) => {
            'quality': row['quality'] as int,
            'count': row['count'] as int,
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> getIntervalDistribution(int bookId) async {
    final db = await _dbFuture;
    final result = await db.rawQuery(
      '''
      SELECT interval, COUNT(*) as count FROM review_records
      WHERE word_id IN (SELECT id FROM words WHERE word_book_id = ?)
      GROUP BY interval
      ORDER BY interval ASC
    ''',
      [bookId],
    );
    return result
        .map(
          (row) => {
            'interval': row['interval'] as int,
            'count': row['count'] as int,
          },
        )
        .toList();
  }

  /// 获取热力图数据（过去一年每天的复习数量）
  Future<Map<DateTime, int>> getHeatmapData() async {
    final db = await _dbFuture;
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day);
    final startDate = endDate.subtract(const Duration(days: 365));
    final startDateStr =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

    final result = await db.rawQuery(
      '''
      SELECT date(last_review) as study_date, COUNT(*) as count
      FROM review_records
      WHERE last_review >= ?
      GROUP BY date(last_review)
      ORDER BY study_date ASC
    ''',
      [startDateStr],
    );

    final Map<DateTime, int> heatmapData = {};
    for (final row in result) {
      final dateStr = row['study_date'] as String;
      final parts = dateStr.split('-');
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      heatmapData[date] = row['count'] as int;
    }

    return heatmapData;
  }
}
