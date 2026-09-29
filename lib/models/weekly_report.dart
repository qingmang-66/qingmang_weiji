import 'daily_study_detail.dart';
import 'weakness_level.dart';

/// 周期学习报告（周=最近7天，月=最近30天）
///
/// 以逐日明细为核心：每天一行事实数据（学习/练习/记住/填错/正确率），
/// 汇总指标由明细推导（见 [DailyDetailsAggregator]），另附薄弱词排行。
class WeeklyReport with DailyDetailsAggregator {
  /// 逐日明细（按日期升序）
  @override
  final List<DailyStudyDetail> dailyDetails;

  /// 薄弱词 Top N（来自薄弱词库评分）
  final List<WeeklyTopWeakWord> topWeakWords;

  /// 高频错词排行（旧字段，保留向后兼容，新代码请用 [topWeakWords]）
  @Deprecated('Use topWeakWords; this list will be removed in a future release')
  final List<FrequentWrongWord> frequentWrongWords;

  /// 本周期学习计划完成的天数（来自每日快照）
  final int planCompletedDays;

  /// 周期起点（含）
  final DateTime weekStart;

  /// 周期终点（不含）
  final DateTime weekEnd;

  const WeeklyReport({
    required this.dailyDetails,
    this.topWeakWords = const [],
    @Deprecated(
      'Use topWeakWords; this list will be removed in a future release',
    )
    this.frequentWrongWords = const [],
    this.planCompletedDays = 0,
    required this.weekStart,
    required this.weekEnd,
  });

  /// 空报告兜底
  factory WeeklyReport.empty() {
    final now = DateTime.now();
    final end = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 7));
    return WeeklyReport(dailyDetails: const [], weekStart: start, weekEnd: end);
  }

  /// 格式化的周期日期范围
  String get formattedWeekRange {
    final endInclusive = weekEnd.subtract(const Duration(days: 1));
    final sameYear = weekStart.year == endInclusive.year;
    if (sameYear) {
      return '${weekStart.year}/${weekStart.month}/${weekStart.day} - ${endInclusive.month}/${endInclusive.day}';
    }
    return '${weekStart.year}/${weekStart.month}/${weekStart.day} - ${endInclusive.year}/${endInclusive.month}/${endInclusive.day}';
  }
}

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
