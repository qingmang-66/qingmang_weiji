import 'weakness_level.dart';

/// 每周学习报告
///
/// 包含本周学习的完整统计数据和 vs 上周的趋势对比。
class WeeklyReport {
  /// 本周新学单词数（review_records 中 repetitions=1 的去重 word_id 数）
  final int newWords;

  /// 本周复习单词数（review_records 中 repetitions>1 的去重 word_id 数）
  final int reviewWords;

  /// 本周学习天数（review_records 按 date(last_review) 去重）
  final int studyDays;

  /// 平均复习质量（0~5）
  final double averageQuality;

  /// 计划完成天数（daily_task_snapshots 中 completed_at 不为空）
  final int planCompletedDays;

  /// 高频错词 Top N（旧字段，保留向后兼容）
  final List<FrequentWrongWord> frequentWrongWords;

  /// 薄弱词 Top N（新字段，来自薄弱词库评分）
  final List<WeeklyTopWeakWord> topWeakWords;

  /// 本周被学习过的自定义词集数
  final int customSetsStudied;

  /// 本周被学习过的收藏组数
  final int favoritesStudied;

  /// 本周完成的会话总数（session_mastery_records）
  final int totalSessions;

  /// 本周平均掌握度（session_mastery_records.session_score 的 AVG，0~1）
  final double avgSessionScore;

  /// 本周平均 ease_factor（review_records 中 ease_factor 不为空的 AVG）
  final double avgEaseFactor;

  /// 本周起始日（周一 00:00:00）
  final DateTime weekStart;

  /// 本周结束日（下周一 00:00:00）
  final DateTime weekEnd;

  /// vs 上周趋势
  final WeeklyTrend trend;

  const WeeklyReport({
    required this.newWords,
    required this.reviewWords,
    required this.studyDays,
    required this.averageQuality,
    required this.planCompletedDays,
    required this.frequentWrongWords,
    this.topWeakWords = const [],
    this.customSetsStudied = 0,
    this.favoritesStudied = 0,
    this.totalSessions = 0,
    this.avgSessionScore = 0,
    this.avgEaseFactor = 0,
    required this.weekStart,
    required this.weekEnd,
    this.trend = const WeeklyTrend(),
  });

  /// 空报告兜底
  factory WeeklyReport.empty() {
    final now = DateTime.now();
    // 计算本周一
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 7));
    return WeeklyReport(
      newWords: 0,
      reviewWords: 0,
      studyDays: 0,
      averageQuality: 0,
      planCompletedDays: 0,
      frequentWrongWords: const [],
      weekStart: start,
      weekEnd: end,
    );
  }

  /// 总学习词数 = 新学 + 复习
  int get totalWords => newWords + reviewWords;

  /// 质量百分比（0~100）
  int get qualityPercent => (averageQuality / 5 * 100).round().clamp(0, 100);

  /// 格式化的周日期范围
  String get formattedWeekRange {
    final sameYear = weekStart.year == weekEnd.year;
    if (sameYear) {
      return '${weekStart.year}/${weekStart.month}/${weekStart.day} - ${weekEnd.month}/${weekEnd.day}';
    }
    return '${weekStart.year}/${weekStart.month}/${weekStart.day} - ${weekEnd.year}/${weekEnd.month}/${weekEnd.day}';
  }
}

/// vs 上周趋势对比
///
/// 所有 delta 正数 = 进步，零 = 持平，负数 = 下降。
class WeeklyTrend {
  final int newWordsDelta;
  final int reviewWordsDelta;
  final int studyDaysDelta;
  final double qualityDelta;
  final int planCompletedDelta;

  const WeeklyTrend({
    this.newWordsDelta = 0,
    this.reviewWordsDelta = 0,
    this.studyDaysDelta = 0,
    this.qualityDelta = 0,
    this.planCompletedDelta = 0,
  });

  /// 总方向：综合各维度 delta 判断整体趋势
  ///
  /// 质量变化权重：qualityDelta * 10（质量0.5分变化≈5个单词量权重）
  WeeklyTrendDirection get direction {
    final score =
        newWordsDelta +
        reviewWordsDelta +
        studyDaysDelta +
        planCompletedDelta +
        (qualityDelta * 10).round();
    if (score > 0) {
      return WeeklyTrendDirection.improved;
    } else if (score < 0) {
      return WeeklyTrendDirection.declined;
    }
    return WeeklyTrendDirection.stable;
  }
}

/// 趋势方向
enum WeeklyTrendDirection { improved, stable, declined }

/// 周报中的薄弱词条目（来自薄弱词库评分）
class WeeklyTopWeakWord {
  final int wordId;
  final String word;
  final String definition;
  final double weaknessScore;
  final WeaknessLevel level;

  const WeeklyTopWeakWord({
    required this.wordId,
    required this.word,
    required this.definition,
    required this.weaknessScore,
    required this.level,
  });
}

/// 高频错词排行条目（旧类型，保留向后兼容）
class FrequentWrongWord {
  final int wordId;
  final String word;
  final String definition;
  final int wrongCount;
  final DateTime? lastWrongTime;

  const FrequentWrongWord({
    required this.wordId,
    required this.word,
    required this.definition,
    required this.wrongCount,
    required this.lastWrongTime,
  });
}
