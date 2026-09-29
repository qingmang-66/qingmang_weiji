import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/daily_study_detail.dart';
import '../models/weekly_report.dart';
import 'daos/stats_dao.dart';
import 'weak_vocabulary_service.dart';

/// 周期学习报告服务
///
/// 周=最近7天、月=最近30天，均以逐日明细为核心，
/// 通过 [StatsDao] 聚合数据、[WeakVocabularyService] 获取薄弱词排行。
class WeeklyReportService {
  final StatsDao _statsDao;
  final WeakVocabularyService _weakVocabularyService;
  final Duration cacheTtl;

  // 本周报告缓存
  WeeklyReport? _cachedCurrent;
  DateTime? _cachedCurrentTime;

  StreamSubscription<WeakVocabularyEvent>? _weakVocabSubscription;

  WeeklyReportService({
    required StatsDao statsDao,
    required WeakVocabularyService weakVocabularyService,
    this.cacheTtl = const Duration(minutes: 5),
  }) : _statsDao = statsDao,
       _weakVocabularyService = weakVocabularyService {
    _subscribeToWeakVocabularyEvents();
  }

  /// 订阅薄弱词库事件，数据变化时自动刷新缓存
  void _subscribeToWeakVocabularyEvents() {
    _weakVocabSubscription = _weakVocabularyService.events.listen((event) {
      if (event.type == WeakVocabularyEventType.invalidated) {
        invalidate();
      }
    });
  }

  /// 构建本周报告（自然周：周一 00:00 ~ 下周一 00:00，含今天，带缓存）。
  ///
  /// 与 [WeeklyReportDetailScreen] 的口径一致：详情页按"周一到周日"翻周，
  /// 这里以前按"最近 7 天"滚动，导致首页周报卡片与详情页的"本周"不是同一个区间，
  /// 用户点进详情后发现数字对不上。
  Future<WeeklyReport> buildCurrentWeekReport({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // weekday: Monday=1 ... Sunday=7
    // 用日历构造而非 subtract(Duration)：绝对时长跨夏令时会推移钟点
    final start = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    if (!forceRefresh && _cachedCurrent != null && _cachedCurrentTime != null) {
      final fresh = now.difference(_cachedCurrentTime!) < cacheTtl;
      //TTL 之内还要校验缓存的就是"本周"：周日 23:58 构建的缓存在
      //周一 00:02 仍新鲜，但区间已是上一周
      final sameWeek = _cachedCurrent!.weekStart == start;
      if (fresh && sameWeek) return _cachedCurrent!;
    }
    final end = DateTime(start.year, start.month, start.day + 7);

    final result = await _buildReport(start: start, end: end);
    _cachedCurrent = result;
    _cachedCurrentTime = DateTime.now();
    return result;
  }

  /// 构建指定起始日的周报告（供周报详情页翻周查看，不缓存）。
  ///
  /// 用日历构造 `start + 7 天` 而不是 `add(Duration(days: 7))`：跨夏令时切换
  /// 日时，绝对时长会让本地钟点推移 1 小时，导致区间多/少一天。
  Future<WeeklyReport> buildWeekReport(DateTime weekStart) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = DateTime(start.year, start.month, start.day + 7);
    return _buildReport(start: start, end: end);
  }

  /// 构建月报（自然月：本月 1 日 00:00 ~ 下月 1 日 00:00）
  Future<MonthlySummary> buildCurrentMonthReport() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    final details = await _statsDao.getDailyDetails(start: start, end: end);
    return MonthlySummary(dailyDetails: details);
  }

  /// 构建任意区间的逐日明细（统计页按日/周/月回看历史周期）
  Future<List<DailyStudyDetail>> buildRangeDetails({
    required DateTime start,
    required DateTime end,
  }) {
    return _statsDao.getDailyDetails(start: start, end: end);
  }

  /// 清除缓存
  void invalidate() {
    _cachedCurrent = null;
    _cachedCurrentTime = null;
  }

  /// 释放资源
  void dispose() {
    _weakVocabSubscription?.cancel();
    _weakVocabSubscription = null;
  }

  /// 内部：构建指定范围的周期报告
  Future<WeeklyReport> _buildReport({
    required DateTime start,
    required DateTime end,
  }) async {
    final dailyDetails = await _statsDao.getDailyDetails(
      start: start,
      end: end,
    );

    final planCompletedDays = await _statsDao.getWeeklyPlanCompletion(
      start: start,
      end: end,
    );

    //薄弱词 Top 10，查询失败不阻塞报告生成
    List<WeeklyTopWeakWord> topWeakWords = [];
    List<FrequentWrongWord> frequentWrongWords = [];
    try {
      final overview = await _weakVocabularyService.getOverview();
      topWeakWords = overview.entries
          .take(10)
          .map(
            (e) => WeeklyTopWeakWord(
              wordId: e.word.id ?? 0,
              word: e.word.word,
              definition: e.word.definition,
              weaknessScore: e.score,
              level: e.level,
            ),
          )
          .toList(growable: false);
      //向后兼容：也填充旧字段
      frequentWrongWords = overview.entries
          .take(10)
          .map(
            (e) => FrequentWrongWord(
              wordId: e.word.id ?? 0,
              word: e.word.word,
              definition: e.word.definition,
              wrongCount: e.wrongCount,
              lastWrongTime: e.lastWrongTime,
            ),
          )
          .toList(growable: false);
    } catch (e, st) {
      //薄弱词库查询失败时跳过错词排行（debugPrint 在 release 模式被剥离，正常）
      debugPrint('WeeklyReportService: 薄弱词库查询失败，跳过错词排行: $e\n$st');
    }

    return WeeklyReport(
      dailyDetails: dailyDetails,
      topWeakWords: topWeakWords,
      frequentWrongWords: frequentWrongWords,
      planCompletedDays: planCompletedDays,
      weekStart: start,
      weekEnd: end,
    );
  }
}

/// 月度报告：最近30天逐日明细
///
/// 汇总计算复用 [DailyDetailsAggregator]，避免与 [WeeklyReport] 重复实现。
class MonthlySummary with DailyDetailsAggregator {
  @override
  final List<DailyStudyDetail> dailyDetails;

  const MonthlySummary({required this.dailyDetails});
}
