import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/providers/providers.dart';
import '../services/di_container.dart';
import '../services/study_plan_service.dart';
import '../services/weekly_report_service.dart';
import '../services/repositories/stats_repository.dart';
import '../theme/fluid_theme.dart';
import '../widgets/fluid_card.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../widgets/review_line_chart.dart';
import '../widgets/review_forecast_card.dart';
import '../widgets/stage_pie_chart.dart';
import '../widgets/study_calendar.dart';
import '../widgets/stats_cards.dart';
import '../widgets/today_advice_card.dart';
import '../widgets/weak_vocabulary_summary_card.dart';
import '../utils/page_transitions.dart';
import 'achievement_center_screen.dart';
import 'weekly_report_detail_screen.dart';

class StatsLoadController<T> {
  StatsLoadController({required this.load, required this.apply});

  final Future<T> Function(int? bookId) load;
  final void Function(T result) apply;
  int? _bookId;
  bool _initialized = false;
  int _generation = 0;
  Object? _activeRequest;
  Future<void>? _inFlight;
  bool _disposed = false;

  Future<void> updateBook(int? bookId) {
    if (_initialized && _bookId == bookId) {
      return _inFlight ?? Future<void>.value();
    }
    _initialized = true;
    _bookId = bookId;
    return _start();
  }

  Future<void> refresh() => _inFlight ?? _start();

  Future<void> _start() {
    final generation = ++_generation;
    final request = Object();
    _activeRequest = request;
    final future = load(_bookId)
        .then((result) {
          if (!_disposed && generation == _generation) apply(result);
        })
        .whenComplete(() {
          if (_activeRequest == request) {
            _activeRequest = null;
            _inFlight = null;
          }
        });
    _inFlight = future;
    return future;
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _activeRequest = null;
    _inFlight = null;
  }
}

class _StatsSnapshot {
  const _StatsSnapshot({
    required this.stats,
    required this.dailyData,
    required this.heatmapData,
    required this.reviewForecast,
    required this.todayAdvice,
    required this.todayTask,
    required this.weeklyReport,
    required this.monthlyReport,
  });

  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> dailyData;
  final Map<DateTime, int> heatmapData;
  final ReviewForecast reviewForecast;
  final TodayAdvice todayAdvice;
  final TodayTask? todayTask;
  final WeeklyReport? weeklyReport;
  final MonthlySummary? monthlyReport;
}

/// 统计页面 - 流体渐变风格
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _dailyData = [];
  Map<DateTime, int> _heatmapData = {};
  ReviewForecast _reviewForecast = const ReviewForecast(days: []);
  TodayAdvice _todayAdvice = const TodayAdvice(
    type: TodayAdviceType.doneToday,
    dueWords: 0,
    todayNewWords: 0,
    dailyNewLimit: 20,
    unlearnedWords: 0,
  );
  TodayTask? _todayTask;
  WeeklyReport? _weeklyReport;
  MonthlySummary? _monthlyReport;
  WordBookProvider? _wordBookProvider;
  late final StatsLoadController<_StatsSnapshot> _loader;
  final StatsRepository _statsRepository = DIContainer.instance.statsRepository;
  final ScrollController _scrollController = ScrollController();
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loader = StatsLoadController(load: _loadStats, apply: _applyStats);
  }

  Future<_StatsSnapshot> _loadStats(int? bookId) async {
    try {
      final wordBookProvider = _wordBookProvider;
      final settings = Provider.of<StudySettingsProvider>(
        context,
        listen: false,
      );
      final reportRepo = DIContainer.instance.weeklyReportRepository;

      final results = await Future.wait([
        _statsRepository.getStudyStats(),
        _statsRepository.getDailyReviewStats(days: 30),
        _statsRepository.getHeatmapData(),
        _statsRepository.getReviewForecast(days: 7),
        DIContainer.instance.studyPlanService.getTodayTask(),
        reportRepo.loadCurrentWeek(),
        reportRepo.loadCurrentMonth(),
        if (bookId != null)
          DIContainer.instance.reviewRepository.getWordBookProgress(bookId),
      ]);
      TodayAdvice todayAdvice = _todayAdvice;
      if (bookId != null && results.length > 7) {
        final progress = results[7] as WordBookProgress;
        todayAdvice = TodayAdvice.fromCounts(
          dueWords: progress.dueWords,
          todayNewWords: wordBookProvider?.todayNewCount ?? 0,
          dailyNewLimit: settings.dailyNewWords,
          unlearnedWords: progress.unlearnedWords,
        );
      }
      return _StatsSnapshot(
        stats: results[0] as Map<String, dynamic>,
        dailyData: results[1] as List<Map<String, dynamic>>,
        heatmapData: results[2] as Map<DateTime, int>,
        reviewForecast: results[3] as ReviewForecast,
        todayAdvice: todayAdvice,
        todayTask: results[4] as TodayTask?,
        weeklyReport: results[5] as WeeklyReport?,
        monthlyReport: results[6] as MonthlySummary?,
      );
    } catch (e) {
      _applyLoadError(e);
      rethrow;
    }
  }

  void _applyStats(_StatsSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _loadFailed = false;
      _stats = snapshot.stats;
      _dailyData = snapshot.dailyData;
      _heatmapData = snapshot.heatmapData;
      _reviewForecast = snapshot.reviewForecast;
      _todayTask = snapshot.todayTask;
      _weeklyReport = snapshot.weeklyReport;
      _monthlyReport = snapshot.monthlyReport;
      _todayAdvice = snapshot.todayAdvice;
    });
  }

  void _applyLoadError(Object error) {
    debugPrint('统计加载失败: $error');
    if (!mounted) return;
    setState(() => _loadFailed = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newProvider = Provider.of<WordBookProvider>(context, listen: false);
    if (newProvider != _wordBookProvider) {
      _wordBookProvider?.removeListener(_onProviderChanged);
      _wordBookProvider = newProvider;
      _wordBookProvider?.addListener(_onProviderChanged);
      _loader.updateBook(newProvider.currentBook?.id);
    }
  }

  void _onProviderChanged() {
    if (mounted) _loader.updateBook(_wordBookProvider?.currentBook?.id);
  }

  @override
  void dispose() {
    _wordBookProvider?.removeListener(_onProviderChanged);
    _loader.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final padding = isWideScreen ? 24.0 : 16.0;
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    // 首页 Tab 外层已有顶部 SafeArea
    return FluidPage(
      top: false,
      child: RefreshIndicator(
        onRefresh: _loader.refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                context.tr.studyStats,
                style: FluidTheme.headingMedium(
                  isDark,
                ).copyWith(color: textPrimary),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.emoji_events,
                    color: FluidTheme.warningFluidGradient[0],
                  ),
                  onPressed: () {
                    //触发成就检测后跳转成就中心
                    DIContainer.instance.achievementRepository
                        .loadAndCheck()
                        .catchError((e) {
                          debugPrint('成就检测失败: $e');
                          return const <AchievementProgress>[];
                        });
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AchievementCenterScreen(),
                      ),
                    );
                  },
                  tooltip: context.tr.achievementsLabel,
                ),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.all(padding),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loadFailed) ...[
                    FluidCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '统计数据加载失败',
                            style: FluidTheme.headingSmall(
                              isDark,
                            ).copyWith(color: textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '请检查网络或稍后重试',
                            style: FluidTheme.bodyMedium(isDark),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _loader.refresh(),
                              child: const Text('重试'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TodayAdviceCard(advice: _todayAdvice),
                  const SizedBox(height: 12),
                  _buildPlanCompletionCard(isDark),
                  const SizedBox(height: 12),
                  _buildWeeklyReportCard(isDark),
                  const SizedBox(height: 12),
                  _buildMonthlyReportCard(isDark),
                  const SizedBox(height: 12),
                  VocabularyCard(stats: _stats),
                  const SizedBox(height: 12),
                  StreakCard(stats: _stats),
                  const SizedBox(height: 12),
                  StudyCalendar(data: _heatmapData),
                  const SizedBox(height: 12),
                  ReviewLineChart(dailyData: _dailyData),
                  const SizedBox(height: 12),
                  ReviewForecastCard(forecast: _reviewForecast),
                  const SizedBox(height: 12),
                  const WeakVocabularySummaryCard(),
                  const SizedBox(height: 12),
                  if (_stats['stages'] != null)
                    StagePieChart(
                      stages: Map<String, int>.from(_stats['stages']),
                    ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCompletionCard(bool isDark) {
    final task = _todayTask;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final target = (task?.targetNewWords ?? 0) + (task?.targetReviewWords ?? 0);
    final completed =
        (task?.completedNewWords ?? 0) + (task?.completedReviewWords ?? 0);
    final progress = target <= 0 ? 1.0 : (completed / target).clamp(0.0, 1.0);

    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluidCardTitle(
            text: context.tr.planProgress,
            icon: Icons.flag_circle_outlined,
            gradientColors: FluidTheme.primaryFluidGradient,
          ),
          const SizedBox(height: 12),
          Text(
            task?.plan?.name ?? context.tr.noPlanYet,
            style: FluidTheme.labelLarge(isDark).copyWith(color: textPrimary),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: FluidTheme.primaryFluidGradient[0].withValues(
              alpha: 0.12,
            ),
            valueColor: AlwaysStoppedAnimation<Color>(
              FluidTheme.primaryFluidGradient[0],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completed/$target · ${context.tr.todayTask}',
            style: FluidTheme.bodySmall(isDark).copyWith(color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyReportCard(bool isDark) {
    final report = _weeklyReport;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(20),
      onTap: report != null
          ? () {
              Navigator.push(
                context,
                PageTransitions.slideFromRight(
                  page: WeeklyReportDetailScreen(initialReport: report),
                ),
              );
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FluidCardTitle(
                text: context.tr.weeklyReport,
                icon: Icons.summarize_outlined,
                gradientColors: FluidTheme.secondaryFluidGradient,
              ),
              const Spacer(),
              if (report != null) ...[
                Text(
                  report.formattedWeekRange,
                  style: FluidTheme.bodySmall(
                    isDark,
                  ).copyWith(color: textSecondary),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: FluidTheme.getTextTertiaryColor(isDark),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (report == null)
            Text(
              context.tr.loadingWeeklyReport,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textSecondary),
            )
          else ...[
            _buildWeeklyMetricsGrid(report, isDark, textPrimary, textSecondary),
            const SizedBox(height: 16),
            _buildTopWeakWordsSection(
              report,
              isDark,
              textPrimary,
              textSecondary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyMetricsGrid(
    WeeklyReport report,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final trend = report.trend;
    final metrics = [
      _WeeklyMetric(
        label: context.tr.newWords,
        value: '${report.newWords}',
        delta: trend.newWordsDelta,
        deltaUnit: context.tr.unitWords,
      ),
      _WeeklyMetric(
        label: context.tr.reviewedWords,
        value: '${report.reviewWords}',
        delta: trend.reviewWordsDelta,
        deltaUnit: context.tr.unitWords,
      ),
      _WeeklyMetric(
        label: context.tr.studyDaysLabel,
        value: '${report.studyDays}/7',
        delta: trend.studyDaysDelta,
        deltaUnit: context.tr.unitDays,
      ),
      _WeeklyMetric(
        label: context.tr.averageQuality,
        value: '${report.qualityPercent}%',
        delta: (trend.qualityDelta / 5 * 100).round().clamp(-100, 100),
        deltaUnit: '%',
      ),
      _WeeklyMetric(
        label: context.tr.planCompletedDays,
        value: '${report.planCompletedDays}/7',
        delta: trend.planCompletedDelta,
        deltaUnit: context.tr.unitDays,
      ),
      _WeeklyMetric(
        label: context.tr.totalSessions,
        value: '${report.totalSessions}',
        delta: null,
        deltaUnit: '',
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            for (int i = 0; i < 3; i++)
              Expanded(
                child: _buildMetricItem(
                  metrics[i],
                  isDark,
                  textPrimary,
                  textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (int i = 3; i < 6; i++)
              Expanded(
                child: _buildMetricItem(
                  metrics[i],
                  isDark,
                  textPrimary,
                  textSecondary,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricItem(
    _WeeklyMetric metric,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final delta = metric.delta;
    Color? deltaColor;
    IconData? deltaIcon;
    String deltaText = '';

    if (delta != null) {
      if (delta > 0) {
        deltaColor = FluidTheme.success;
        deltaIcon = Icons.arrow_upward;
        deltaText = '+$delta${metric.deltaUnit}';
      } else if (delta < 0) {
        deltaColor = FluidTheme.error;
        deltaIcon = Icons.arrow_downward;
        deltaText = '$delta${metric.deltaUnit}';
      } else {
        deltaColor = textSecondary;
        deltaIcon = Icons.horizontal_rule;
        deltaText = context.tr.trendStable;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              metric.value,
              style: FluidTheme.numberSmall(isDark, color: textPrimary),
            ),
            if (delta != null) ...[
              const SizedBox(width: 4),
              Icon(deltaIcon, size: 12, color: deltaColor),
              const SizedBox(width: 1),
              Text(
                deltaText,
                style: FluidTheme.bodySmall(isDark).copyWith(color: deltaColor),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          metric.label,
          style: FluidTheme.bodySmall(isDark).copyWith(color: textSecondary),
        ),
      ],
    );
  }

  Widget _buildTopWeakWordsSection(
    WeeklyReport report,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final topWeak = report.topWeakWords;
    if (topWeak.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr.topWeakWords,
          style: FluidTheme.labelLarge(isDark).copyWith(color: textPrimary),
        ),
        const SizedBox(height: 8),
        ...topWeak
            .take(5)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _weaknessColor(item.level),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.word,
                            style: FluidTheme.labelMedium(
                              isDark,
                            ).copyWith(color: textPrimary),
                          ),
                          if (item.definition.isNotEmpty)
                            Text(
                              item.definition,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FluidTheme.bodySmall(
                                isDark,
                              ).copyWith(color: textSecondary),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      item.weaknessScore.toStringAsFixed(1),
                      style: FluidTheme.bodySmall(
                        isDark,
                      ).copyWith(color: _weaknessColor(item.level)),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Color _weaknessColor(WeaknessLevel level) {
    return level.color;
  }

  Widget _buildMonthlyReportCard(bool isDark) {
    final report = _monthlyReport;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final progressHint = report == null
        ? context.tr.generatingMonthlyReport
        : context.tr.monthlySummary(
            report.totalWords,
            report.newWords,
            report.reviewWords,
          );

    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluidCardTitle(
            text: context.tr.monthlyReport,
            icon: Icons.calendar_month_outlined,
            gradientColors: FluidTheme.primaryFluidGradient,
          ),
          const SizedBox(height: 12),
          Text(
            progressHint,
            style: FluidTheme.bodyMedium(isDark).copyWith(color: textPrimary),
          ),
          if (report != null) ...[
            const SizedBox(height: 10),
            Text(
              context.tr.monthlySubtitle(
                report.studyDays,
                report.planCompletedDays,
                report.qualityPercent,
              ),
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeeklyMetric {
  final String label;
  final String value;
  final int? delta;
  final String deltaUnit;

  const _WeeklyMetric({
    required this.label,
    required this.value,
    this.delta,
    this.deltaUnit = '',
  });
}
