import '../utils/date_utils.dart';

/// 学习计划纯逻辑计算
///
/// 这里只放与状态无关的纯函数，便于单元测试覆盖。
class StudyPlanLogic {
  StudyPlanLogic._();

  /// 根据总词数和目标日期估算每日新词任务量。
  ///
  /// 每日量 = ceil(总词数 / 剩余天数)，剩余天数至少为 1，避免除零。
  static int estimateDailyNewTarget({
    required int totalWords,
    required DateTime targetDate,
    required DateTime today,
  }) {
    if (totalWords <= 0) return 0;
    final remainingDays = _remainingDays(targetDate, today);
    // 向上取整
    return (totalWords + remainingDays - 1) ~/ remainingDays;
  }

  /// 根据总词数和每日量估算预计完成天数。
  ///
  /// 完成天数 = ceil(总词数 / 每日量)，每日量为 0 时返回 0。
  static int estimateFinishDays({
    required int totalWords,
    required int dailyNewTarget,
  }) {
    if (totalWords <= 0) return 0;
    if (dailyNewTarget <= 0) return 0;
    return (totalWords + dailyNewTarget - 1) ~/ dailyNewTarget;
  }

  /// 计算计划总体进度（0.0 ~ 1.0）。
  ///
  /// 进度 = 已学新词 / 总词数，封顶 1.0；总词数为 0 时视为完成。
  static double planProgress({
    required int learnedNewWords,
    required int totalWords,
  }) {
    if (totalWords <= 0) return 1.0;
    final progress = learnedNewWords / totalWords;
    return progress > 1.0 ? 1.0 : progress;
  }

  /// 计算目标日期距今天的剩余天数，至少为 1。
  static int _remainingDays(DateTime targetDate, DateTime today) {
    //用日历天数：difference().inDays 在跨夏令时切换日会因 23/25 小时日
    //截断少算 1 天，estimateDailyNewTarget 随之高估每日任务量
    final days = calendarDaysBetween(today, targetDate);
    return days < 1 ? 1 : days;
  }
}
