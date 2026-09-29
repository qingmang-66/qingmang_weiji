/// 逐日学习明细
///
/// 每天一行的事实数据：新学词数、练习词数、记住词数、
/// 填错词数、作答次数与错误次数，正确率/错误率由此推导。
class DailyStudyDetail {
  final DateTime date;

  /// 当日新学词数（review_records.first_learned_at 落在当天）
  final int newWords;

  /// 当日练习词数（session_mastery_records 当天出现的词数）
  final int practicedWords;

  /// 当日记住的词数（当天至少答对一次）
  final int rememberedWords;

  /// 当日填错的词数（当天有答错记录的词数）
  final int wrongWords;

  /// 当日总作答次数
  final int attempts;

  /// 当日总错误次数
  final int wrongCount;

  const DailyStudyDetail({
    required this.date,
    this.newWords = 0,
    this.practicedWords = 0,
    this.rememberedWords = 0,
    this.wrongWords = 0,
    this.attempts = 0,
    this.wrongCount = 0,
  });

  /// 正确率（0~1），无作答时为 0
  double get correctRate =>
      attempts <= 0 ? 0 : (attempts - wrongCount) / attempts;

  /// 错误率（0~1）
  double get wrongRate => attempts <= 0 ? 0 : wrongCount / attempts;

  /// 当日是否有任何学习活动
  bool get hasActivity => newWords > 0 || practicedWords > 0 || attempts > 0;

  /// 正确率百分比文本，如 "85%"
  String get correctRateText => '${(correctRate * 100).round()}%';

  /// MM/dd 短日期
  String get shortDateText =>
      '${date.month}/${date.day.toString().padLeft(2, '0')}';
}

/// 逐日明细聚合 mixin
///
/// 复用 [DailyStudyDetail] 列表的汇总计算（周报/月报共用），
/// 避免 WeeklyReport / MonthlySummary 各自重复实现同一组 getter。
mixin DailyDetailsAggregator {
  List<DailyStudyDetail> get dailyDetails;

  int get newWords => dailyDetails.fold(0, (sum, d) => sum + d.newWords);

  int get practicedWords =>
      dailyDetails.fold(0, (sum, d) => sum + d.practicedWords);

  int get rememberedWords =>
      dailyDetails.fold(0, (sum, d) => sum + d.rememberedWords);

  int get wrongWords => dailyDetails.fold(0, (sum, d) => sum + d.wrongWords);

  int get attempts => dailyDetails.fold(0, (sum, d) => sum + d.attempts);

  int get wrongCount => dailyDetails.fold(0, (sum, d) => sum + d.wrongCount);

  int get totalWords => newWords + practicedWords;

  int get studyDays => dailyDetails.where((d) => d.hasActivity).length;

  double get correctRate =>
      attempts <= 0 ? 0 : (attempts - wrongCount) / attempts;

  double get wrongRate => attempts <= 0 ? 0 : wrongCount / attempts;

  int get correctRatePercent => (correctRate * 100).round().clamp(0, 100);
}
