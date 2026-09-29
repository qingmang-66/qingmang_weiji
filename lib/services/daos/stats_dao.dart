import 'package:sqflite/sqflite.dart';
import 'dao_handle.dart';
import '../../models/daily_study_detail.dart';
import '../../models/review_forecast.dart';

/// 统计数据访问对象
class StatsDao {
  final Future<Database> Function() _dbFuture;

  StatsDao(Object dbHandle) : _dbFuture = normalizeDbHandle(dbHandle);

  /// 获取学习总览统计
  ///
  /// 时间字段约定：所有时间戳都以本地时间 `DateTime.toIso8601String()`
  /// 写入（无时区后缀），SQLite 字符串字典序与实际时间序一致，
  /// 不存在 UTC/本地跨时区错位问题。
  /// sqflite 共享单 connection，因此并行 rawQuery 在底层仍串行执行，
  /// 但用 Future.wait 表达"彼此独立"的意图，未来切到支持并发的引擎立即获益。
  Future<Map<String, dynamic>> getStudyStats() async {
    final db = await _dbFuture();
    final today = DateTime.now();
    final todayStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).toIso8601String();
    final dueArgs = [DateTime.now().toIso8601String()];

    //彼此独立、可并行的查询
    final totalWordsF = db.rawQuery('SELECT COUNT(*) as total FROM words');
    //与 totalReviews/getOverallStats 口径一致：只计入真正作答过（quality > 0）的词，
    //否则 createInitialRecord 生成的 quality=0 初始记录会把"未复习的新词"也算作已学
    final learnedWordsF = db.rawQuery(
      'SELECT COUNT(DISTINCT word_id) as learned FROM review_records WHERE quality > 0',
    );
    final totalReviewsF = db.rawQuery(
      'SELECT COUNT(*) as review_count FROM review_records WHERE quality > 0',
    );
    final dueWordsF = db.rawQuery(
      'SELECT COUNT(*) as due FROM review_records WHERE next_review <= ?',
      dueArgs,
    );
    final streakF = _calculateStreak(db);
    final stageF = db.rawQuery('''
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

    //"今日"统计依赖同一 todayStart，放到 await 后做以保证读到的本地日期一致
    final results = await Future.wait([
      totalWordsF,
      learnedWordsF,
      totalReviewsF,
      dueWordsF,
      streakF,
      stageF,
    ]);
    final c0 =
        (results[0] as List<Map<String, dynamic>>).first['total'] as int? ?? 0;
    final c1 =
        (results[1] as List<Map<String, dynamic>>).first['learned'] as int? ??
        0;
    final c2 =
        (results[2] as List<Map<String, dynamic>>).first['review_count']
            as int? ??
        0;
    final c3 =
        (results[3] as List<Map<String, dynamic>>).first['due'] as int? ?? 0;

    // 使用 MemoryStage 枚举名称作为 key，确保跨语言一致性
    final stages = <String, int>{
      'newLearned': 0,
      'initial': 0,
      'consolidating': 0,
      'familiar': 0,
      'mastered': 0,
    };
    final stageResult = results[5] as List<Map<String, dynamic>>;
    for (final row in stageResult) {
      final stage = row['stage'] as String?;
      final cnt = row['cnt'] as int? ?? 0;
      if (stage != null && stages.containsKey(stage)) {
        stages[stage] = cnt;
      }
    }

    //今日新学/今日复习：依赖 todayStart，与上一批一起执行会跨越本地跨天风险，
    //因此在 Future.wait 之后再做，todayStart 仍是同一本地日期
    final todayNewResult = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT word_id) as today_new FROM review_records
      WHERE last_review >= ? AND quality > 0
        AND (
          (first_learned_at >= ?)
          OR (first_learned_at IS NULL AND repetitions = 1)
        )
    ''',
      [todayStart, todayStart],
    );

    final todayReviewResult = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT word_id) as today_review FROM review_records
      WHERE last_review >= ? AND quality > 0
        AND (
          (first_learned_at IS NOT NULL AND first_learned_at < ?)
          OR (first_learned_at IS NULL AND repetitions > 1)
        )
    ''',
      [todayStart, todayStart],
    );

    return {
      'totalWords': c0,
      'learnedWords': c1,
      'totalReviews': c2,
      'dueWords': c3,
      'todayNew': (todayNewResult.first['today_new'] as int?) ?? 0,
      'todayReview': (todayReviewResult.first['today_review'] as int?) ?? 0,
      'streak': results[4] as int,
      'stages': stages,
    };
  }

  /// 计算连续学习天数（从今天或昨天开始向前连续追溯）
  Future<int> _calculateStreak(Database db) async {
    //原实现在列上套 date() 且无 WHERE，会对整张 review_records 全表扫描 + 去重。
    //改为「范围条件 + substr」：条件可命中 idx_review_last_review，
    //substr 取出的 yyyy-MM-dd 与下方 formatDate 的格式一致。
    //连续天数的上界：取 3 年窗口（远大于真实连击），
    //用索引范围扫描替代原来的全表扫描
    const maxDays = 1100;
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: maxDays));
    final startStr =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final records = await db.rawQuery(
      '''
      SELECT DISTINCT substr(last_review, 1, 10) as study_date FROM review_records
      WHERE last_review >= ? AND quality > 0
      ORDER BY study_date DESC LIMIT $maxDays
    ''',
      [startStr],
    );
    if (records.isEmpty) return 0;

    //date() 对非法/空字符串返回 NULL：直接 as String 会抛 TypeError，
    //用 whereType 过滤掉脏行（只影响脏数据本身的统计，不影响其它日期）
    final dateStrings = records
        .map((r) => r['study_date'])
        .whereType<String>()
        .toSet();

    String formatDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
    final db = await _dbFuture();
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
      WHERE last_review >= ? AND quality > 0
      GROUP BY date(last_review)
      ORDER BY study_date ASC
    ''',
      [startDateStr],
    );

    final Map<String, int> dateCountMap = {};
    for (final row in result) {
      //date() 对非法值返回 NULL，硬转会抛 TypeError 让整页统计崩溃
      final date = row['study_date'];
      if (date is! String) continue;
      dateCountMap[date] = (row['count'] as int?) ?? 0;
    }

    final List<Map<String, dynamic>> dailyData = [];
    //从 startDate 的次日到"今天"（共 days 天）：旧实现生成的是
    //今天-days … 今天-1，永远不含当天，当日复习在柱状图上恒为 0
    for (int i = 1; i <= days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyData.add({'date': date, 'count': dateCountMap[dateStr] ?? 0});
    }

    return dailyData;
  }

  Future<ReviewForecast> getReviewForecast({int days = 7}) async {
    final db = await _dbFuture();
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
      //date() 对非法 next_review 返回 NULL，硬转会抛 TypeError 让整个复习预测崩溃
      final date = row['review_date'];
      if (date is! String) continue;
      countMap[date] = (row['count'] as int?) ?? 0;
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

  /// 逐日学习明细：新词数来自 review_records.first_learned_at，
  /// 练习/记住/填错/作答来自 session_mastery_records 按天聚合，
  /// 范围内每一天都会返回（无数据的天为全零）
  Future<List<DailyStudyDetail>> getDailyDetails({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _dbFuture();
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();
    final startDateStr = _formatDate(start);
    final endDateStr = _formatDate(end);

    //新词按天
    final newByDay = <String, int>{};
    final newRows = await db.rawQuery(
      '''
      SELECT date(first_learned_at) as d, COUNT(*) as c
      FROM review_records
      WHERE first_learned_at >= ? AND first_learned_at < ?
        AND first_learned_at IS NOT NULL
      GROUP BY date(first_learned_at)
      ''',
      [startStr, endStr],
    );
    for (final row in newRows) {
      final d = row['d'] as String?;
      if (d != null) newByDay[d] = row['c'] as int? ?? 0;
    }

    //练习明细按天
    final practiceByDay = <String, Map<String, int>>{};
    final practiceRows = await db.rawQuery(
      '''
      SELECT
        date as d,
        COUNT(*) as practiced,
        SUM(CASE WHEN attempt_count > wrong_count THEN 1 ELSE 0 END) as remembered,
        SUM(CASE WHEN wrong_count > 0 THEN 1 ELSE 0 END) as wrong_words,
        SUM(attempt_count) as attempts,
        SUM(wrong_count) as wrongs
      FROM session_mastery_records
      WHERE date >= ? AND date < ?
      GROUP BY date
      ''',
      [startDateStr, endDateStr],
    );
    for (final row in practiceRows) {
      final d = row['d'] as String?;
      if (d == null) continue;
      practiceByDay[d] = {
        'practiced': row['practiced'] as int? ?? 0,
        'remembered': row['remembered'] as int? ?? 0,
        'wrong_words': row['wrong_words'] as int? ?? 0,
        'attempts': row['attempts'] as int? ?? 0,
        'wrongs': row['wrongs'] as int? ?? 0,
      };
    }

    //范围内逐天填充
    final details = <DailyStudyDetail>[];
    var day = DateTime(start.year, start.month, start.day);
    final lastDay = DateTime(end.year, end.month, end.day);
    while (day.isBefore(lastDay)) {
      final key = _formatDate(day);
      final p = practiceByDay[key];
      details.add(
        DailyStudyDetail(
          date: day,
          newWords: newByDay[key] ?? 0,
          practicedWords: p?['practiced'] ?? 0,
          rememberedWords: p?['remembered'] ?? 0,
          wrongWords: p?['wrong_words'] ?? 0,
          attempts: p?['attempts'] ?? 0,
          wrongCount: p?['wrongs'] ?? 0,
        ),
      );
      day = day.add(const Duration(days: 1));
    }
    return details;
  }

  /// 获取指定周的计划完成天数
  ///
  /// 按天去重统计 completed_at 不为空的快照：表的唯一键是 (plan_id, date)，
  /// 多个进行中计划同日各完成一次会有多行，COUNT(*) 会把同一天计多次、
  /// 一周的值可能超过 7。
  Future<int> getWeeklyPlanCompletion({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _dbFuture();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT date) as completed_days FROM daily_task_snapshots
      WHERE date >= ? AND date < ? AND completed_at IS NOT NULL
      ''',
      [_formatDate(start), _formatDate(end)],
    );
    return (result.first['completed_days'] as int?) ?? 0;
  }

  Future<Map<String, dynamic>> getOverallStats(int bookId) async {
    final db = await _dbFuture();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    //next_review 存的是 ISO 字符串，直接比较即可命中索引，勿在列上套 datetime()
    final dueRows = await db.rawQuery(
      '''SELECT COUNT(*) FROM review_records r
         INNER JOIN words w ON r.word_id = w.id
         WHERE w.word_book_id = ? AND r.next_review <= ?''',
      [bookId, today.toIso8601String()],
    );
    //今日复习数同样改为范围比较（date(列) = 常量 无法命中 idx_review_last_review）
    //learned/total/avg 三项与 getStudyStats 口径对齐：只计入 quality > 0 的作答
    final aggRows = await db.rawQuery(
      '''SELECT
           (SELECT COUNT(*) FROM words WHERE word_book_id = ?) AS total_words,
           COUNT(DISTINCT CASE WHEN r.quality > 0 THEN r.word_id END) AS learned_words,
           SUM(CASE WHEN r.last_review >= ? AND r.last_review < ? AND r.quality > 0 THEN 1 ELSE 0 END) AS today_review,
           SUM(CASE WHEN r.quality > 0 THEN 1 ELSE 0 END) AS total_reviews,
           AVG(CASE WHEN r.quality > 0 THEN r.quality END) AS avg_q
         FROM review_records r
         INNER JOIN words w ON r.word_id = w.id
         WHERE w.word_book_id = ?''',
      [
        bookId,
        todayStart.toIso8601String(),
        todayEnd.toIso8601String(),
        bookId,
      ],
    );
    final agg = aggRows.first;
    return {
      'total_words': (agg['total_words'] as int?) ?? 0,
      'learned_words': (agg['learned_words'] as int?) ?? 0,
      'today_review': (agg['today_review'] as int?) ?? 0,
      'due_words': Sqflite.firstIntValue(dueRows) ?? 0,
      'total_reviews': (agg['total_reviews'] as int?) ?? 0,
      'avg_quality': (agg['avg_q'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<List<Map<String, dynamic>>> getQualityDistribution(int bookId) async {
    final db = await _dbFuture();
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
            'quality': (row['quality'] as int?) ?? 0,
            'count': (row['count'] as int?) ?? 0,
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> getIntervalDistribution(int bookId) async {
    final db = await _dbFuture();
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
            'interval': (row['interval'] as int?) ?? 0,
            'count': (row['count'] as int?) ?? 0,
          },
        )
        .toList();
  }

  /// 获取热力图数据（过去一年每天的复习数量）
  Future<Map<DateTime, int>> getHeatmapData() async {
    final db = await _dbFuture();
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day);
    final startDate = endDate.subtract(const Duration(days: 365));
    final startDateStr =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

    final result = await db.rawQuery(
      '''
      SELECT date(last_review) as study_date, COUNT(*) as count
      FROM review_records
      WHERE last_review >= ? AND quality > 0
      GROUP BY date(last_review)
      ORDER BY study_date ASC
    ''',
      [startDateStr],
    );

    final Map<DateTime, int> heatmapData = {};
    for (final row in result) {
      //date() 对非法/空字符串返回 NULL，硬转 String + int.parse 会抛
      //TypeError/FormatException 让整页热力图崩溃，这里逐行跳过脏数据
      final dateStr = row['study_date'];
      if (dateStr is! String) continue;
      final parts = dateStr.split('-');
      if (parts.length != 3) continue;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) continue;
      heatmapData[DateTime(y, m, d)] = (row['count'] as int?) ?? 0;
    }

    return heatmapData;
  }
}
