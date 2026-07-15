import 'dart:async';

import '../models/weekly_report.dart';
import 'daos/stats_dao.dart';
import 'weak_vocabulary_service.dart';

/// 每周学习报告服务
///
/// 通过 [StatsDao] 聚合 review_records / session_mastery_records 数据，
/// 通过 [WeakVocabularyService] 获取薄弱词排行，生成完整的周报。
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

  /// 构建本周报告（带缓存和 vs 上周趋势）
  Future<WeeklyReport> buildCurrentWeekReport({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedCurrent != null && _cachedCurrentTime != null) {
      final fresh = DateTime.now().difference(_cachedCurrentTime!) < cacheTtl;
      if (fresh) return _cachedCurrent!;
    }
    final now = DateTime.now();
    final weekStart = _mondayOf(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final prevStart = weekStart.subtract(const Duration(days: 7));
    final prevEnd = weekStart;

    final current = await _buildReport(start: weekStart, end: weekEnd);
    final previous = await _buildReport(start: prevStart, end: prevEnd);
    final trend = _buildTrend(current, previous);
    final result = WeeklyReport(
      newWords: current.newWords,
      reviewWords: current.reviewWords,
      studyDays: current.studyDays,
      averageQuality: current.averageQuality,
      planCompletedDays: current.planCompletedDays,
      frequentWrongWords: current.frequentWrongWords,
      topWeakWords: current.topWeakWords,
      customSetsStudied: current.customSetsStudied,
      favoritesStudied: current.favoritesStudied,
      totalSessions: current.totalSessions,
      avgSessionScore: current.avgSessionScore,
      avgEaseFactor: current.avgEaseFactor,
      weekStart: weekStart,
      weekEnd: weekEnd,
      trend: trend,
    );
    _cachedCurrent = result;
    _cachedCurrentTime = DateTime.now();
    return result;
  }

  /// 构建上周报告
  Future<WeeklyReport> buildLastWeekReport() async {
    final now = DateTime.now();
    final thisMonday = _mondayOf(now);
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    return _buildReport(start: lastMonday, end: thisMonday);
  }

  /// 构建指定日期所在周的报告（无趋势）
  Future<WeeklyReport> buildWeekReport(DateTime date) async {
    final monday = _mondayOf(date);
    final sunday = monday.add(const Duration(days: 7));
    return _buildReport(start: monday, end: sunday);
  }

  /// 构建月报（轻量文本形式，不重构逻辑）
  Future<MonthlySummary> buildCurrentMonthReport() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);
    return _buildMonthSummary(start: monthStart, end: monthEnd);
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

  /// 内部：构建指定时间范围的周报
  Future<WeeklyReport> _buildReport({
    required DateTime start,
    required DateTime end,
  }) async {
    // 1. 从 StatsDao 获取聚合数据
    final aggregate = await _statsDao.getWeeklyAggregate(
      start: start,
      end: end,
    );
    final avgEaseFactor = await _statsDao.getWeeklyEaseFactor(
      start: start,
      end: end,
    );
    final planCompletedDays = await _statsDao.getWeeklyPlanCompletion(
      start: start,
      end: end,
    );

    // 2. 收藏/词集统计（委托 StatsDao）
    final customSetsStudied = await _statsDao.getCustomSetsStudied(
      start: start,
      end: end,
    );
    final favoritesStudied = await _statsDao.getFavoritesStudied(
      start: start,
      end: end,
    );

    // 3. 从薄弱词库获取 Top 10 薄弱词
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
      // 向后兼容：也填充旧字段
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
    } catch (e) {
      // 薄弱词库查询失败时不阻塞周报生成
      assert(() {
        // ignore: avoid_print
        print('WeeklyReportService: 薄弱词库查询失败，跳过错词排行: $e');
        return true;
      }());
    }

    return WeeklyReport(
      newWords: aggregate['newWords'] as int,
      reviewWords: aggregate['reviewWords'] as int,
      studyDays: aggregate['studyDays'] as int,
      averageQuality: aggregate['averageQuality'] as double,
      planCompletedDays: planCompletedDays,
      frequentWrongWords: frequentWrongWords,
      topWeakWords: topWeakWords,
      customSetsStudied: customSetsStudied,
      favoritesStudied: favoritesStudied,
      totalSessions: aggregate['totalSessions'] as int,
      avgSessionScore: aggregate['avgSessionScore'] as double,
      avgEaseFactor: avgEaseFactor,
      weekStart: start,
      weekEnd: end,
    );
  }

  /// 内部：构建月度汇总（轻量文本形式）
  Future<MonthlySummary> _buildMonthSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final aggregate = await _statsDao.getWeeklyAggregate(
      start: start,
      end: end,
    );
    final planCompletedDays = await _statsDao.getWeeklyPlanCompletion(
      start: start,
      end: end,
    );
    return MonthlySummary(
      newWords: aggregate['newWords'] as int,
      reviewWords: aggregate['reviewWords'] as int,
      studyDays: aggregate['studyDays'] as int,
      averageQuality: aggregate['averageQuality'] as double,
      planCompletedDays: planCompletedDays,
    );
  }

  /// 计算 vs 上周趋势
  WeeklyTrend _buildTrend(WeeklyReport current, WeeklyReport previous) {
    return WeeklyTrend(
      newWordsDelta: current.newWords - previous.newWords,
      reviewWordsDelta: current.reviewWords - previous.reviewWords,
      studyDaysDelta: current.studyDays - previous.studyDays,
      qualityDelta: current.averageQuality - previous.averageQuality,
      planCompletedDelta:
          current.planCompletedDays - previous.planCompletedDays,
    );
  }

  /// 计算本周一 00:00:00
  DateTime _mondayOf(DateTime date) {
    final dayOnly = DateTime(date.year, date.month, date.day);
    return dayOnly.subtract(Duration(days: dayOnly.weekday - 1));
  }
}

/// 月度汇总（轻量文本形式，不包含趋势对比）
class MonthlySummary {
  final int newWords;
  final int reviewWords;
  final int studyDays;
  final double averageQuality;
  final int planCompletedDays;

  const MonthlySummary({
    required this.newWords,
    required this.reviewWords,
    required this.studyDays,
    required this.averageQuality,
    required this.planCompletedDays,
  });

  int get totalWords => newWords + reviewWords;
  int get qualityPercent => (averageQuality / 5 * 100).round().clamp(0, 100);
}
