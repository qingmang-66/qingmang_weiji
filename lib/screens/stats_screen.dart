import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/providers/providers.dart';
import '../services/di_container.dart';
import '../services/study_plan_service.dart';
import '../services/repositories/stats_repository.dart';
import '../theme/fluid_theme.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_card.dart';
import '../utils/translations.dart';
import '../widgets/review_line_chart.dart';
import '../widgets/review_forecast_card.dart';
import '../widgets/stage_pie_chart.dart';
import '../widgets/study_calendar.dart';
import '../widgets/stats_cards.dart';
import '../widgets/today_advice_card.dart';

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
  WeeklyReport? _monthlyReport;
  WordBookProvider? _wordBookProvider;
  final StatsRepository _statsRepository = DIContainer.instance.statsRepository;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadStatsAsync();
  }

  Future<void> _loadStatsAsync() async {
    final stats = await _statsRepository.getStudyStats();
    if (mounted) {
      setState(() {
        _stats = stats;
      });
    }

    final dailyData = await _statsRepository.getDailyReviewStats(days: 30);
    if (mounted) {
      setState(() {
        _dailyData = dailyData;
      });
    }

    final heatmapData = await _statsRepository.getHeatmapData();
    if (mounted) {
      setState(() {
        _heatmapData = heatmapData;
      });
    }

    final reviewForecast = await _statsRepository.getReviewForecast(days: 7);
    if (mounted) {
      setState(() {
        _reviewForecast = reviewForecast;
      });
    }

    final todayTask = await DIContainer.instance.studyPlanService
        .getTodayTask();
    if (mounted) {
      setState(() {
        _todayTask = todayTask;
      });
    }

    final reportService = DIContainer.instance.weeklyReportService;
    final weeklyReport = await reportService.buildCurrentWeekReport();
    final monthlyReport = await reportService.buildCurrentMonthReport();
    if (mounted) {
      setState(() {
        _weeklyReport = weeklyReport;
        _monthlyReport = monthlyReport;
      });
    }

    final wordBookProvider = _wordBookProvider;
    final currentBook = wordBookProvider?.currentBook;
    if (!mounted) return;
    final settings = Provider.of<StudySettingsProvider>(context, listen: false);
    if (currentBook?.id != null) {
      final progress = await DIContainer.instance.reviewRepository
          .getWordBookProgress(currentBook!.id!);
      if (mounted) {
        setState(() {
          _todayAdvice = TodayAdvice.fromCounts(
            dueWords: progress.dueWords,
            todayNewWords: wordBookProvider?.todayNewCount ?? 0,
            dailyNewLimit: settings.dailyNewWords,
            unlearnedWords: progress.unlearnedWords,
          );
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newProvider = Provider.of<WordBookProvider>(context, listen: false);
    if (newProvider != _wordBookProvider) {
      _wordBookProvider?.removeListener(_onProviderChanged);
      _wordBookProvider = newProvider;
      _wordBookProvider?.addListener(_onProviderChanged);
    }
  }

  void _onProviderChanged() {
    if (mounted) _loadStatsAsync();
  }

  @override
  void dispose() {
    _wordBookProvider?.removeListener(_onProviderChanged);
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

    return FluidBackground(
      child: CustomScrollView(
        controller: _scrollController,
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
                onPressed: () => _showAchievements(context),
                tooltip: context.tr.achievementsLabel,
              ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.all(padding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluidCardTitle(
            text: '本周学习报告',
            icon: Icons.summarize_outlined,
            gradientColors: FluidTheme.secondaryFluidGradient,
          ),
          const SizedBox(height: 12),
          if (report == null)
            Text(
              '正在生成周报...',
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textSecondary),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _buildWeeklyMetric(
                    isDark,
                    '新学',
                    '${report.newWords}',
                    textPrimary,
                    textSecondary,
                  ),
                ),
                Expanded(
                  child: _buildWeeklyMetric(
                    isDark,
                    '复习',
                    '${report.reviewWords}',
                    textPrimary,
                    textSecondary,
                  ),
                ),
                Expanded(
                  child: _buildWeeklyMetric(
                    isDark,
                    '学习天数',
                    '${report.studyDays}/7',
                    textPrimary,
                    textSecondary,
                  ),
                ),
                Expanded(
                  child: _buildWeeklyMetric(
                    isDark,
                    '平均质量',
                    '${report.qualityPercent}%',
                    textPrimary,
                    textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '高频错词 Top ${report.frequentWrongWords.length}',
              style: FluidTheme.labelLarge(isDark).copyWith(color: textPrimary),
            ),
            const SizedBox(height: 8),
            if (report.frequentWrongWords.isEmpty)
              Text(
                '本周暂无高频错词，继续保持。',
                style: FluidTheme.bodySmall(
                  isDark,
                ).copyWith(color: textSecondary),
              )
            else
              ...report.frequentWrongWords
                  .take(5)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: FluidTheme.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item.wrongCount}',
                              style: FluidTheme.bodySmall(
                                isDark,
                              ).copyWith(color: FluidTheme.error),
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
                        ],
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlyReportCard(bool isDark) {
    final report = _monthlyReport;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final progressHint = report == null
        ? '正在生成月报...'
        : '本月累计 ${report.totalWords} 次学习，新学 ${report.newWords} 个，复习 ${report.reviewWords} 个。';

    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluidCardTitle(
            text: '月度学习报告',
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
              '学习天数 ${report.studyDays} 天 · 计划完成 ${report.planCompletedDays} 天 · 平均质量 ${report.qualityPercent}%',
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyMetric(
    bool isDark,
    String label,
    String value,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: FluidTheme.headingSmall(isDark).copyWith(color: textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: FluidTheme.bodySmall(isDark).copyWith(color: textSecondary),
        ),
      ],
    );
  }

  void _showAchievements(BuildContext context) {
    final achievements = _getAchievements();
    final unlockedCount = achievements
        .where((a) => a['unlocked'] as bool)
        .length;
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: FluidTheme.getDialogSurfaceColor(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: FluidTheme.getBorderColor(isDark)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              decoration: BoxDecoration(
                color: FluidTheme.getMutedOverlayColor(isDark),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  FluidGradientContainer(
                    colors: FluidTheme.warningFluidGradient,
                    borderRadius: FluidTheme.smallBorderRadius,
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr.achievementCenter,
                      style: FluidTheme.headingSmall(
                        isDark,
                      ).copyWith(color: textPrimary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: FluidTheme.warningFluidGradient,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unlockedCount / ${achievements.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            Expanded(
              child: achievements.isEmpty
                  ? Center(
                      child: Text(
                        context.tr.noAchievementsYet,
                        style: FluidTheme.bodyMedium(
                          isDark,
                        ).copyWith(color: textSecondary),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: achievements.length,
                      itemBuilder: (ctx, i) {
                        final a = achievements[i];
                        return _AchievementDetail(
                          icon: a['icon'] as IconData,
                          label: a['label'] as String,
                          isUnlocked: a['unlocked'] as bool,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getAchievements() {
    final totalWords = _stats['totalWords'] ?? 0;
    final learnedWords = _stats['learnedWords'] ?? 0;
    final streak = _stats['streak'] ?? 0;
    final reviews = _stats['totalReviews'] ?? 0;
    final favorites = _stats['favoriteCount'] ?? 0;
    final customSets = _stats['customSetCount'] ?? 0;
    final weeklyReport = _weeklyReport;

    return [
      {
        'icon': Icons.school,
        'label': context.tr.beginnerAchiever,
        'unlocked': learnedWords >= 10,
      },
      {
        'icon': Icons.menu_book,
        'label': context.tr.vocabExpert,
        'unlocked': learnedWords >= 100,
      },
      {
        'icon': Icons.auto_stories,
        'label': context.tr.vocabMaster,
        'unlocked': learnedWords >= 500,
      },
      {
        'icon': Icons.local_fire_department,
        'label': context.tr.streak3Days,
        'unlocked': streak >= 3,
      },
      {
        'icon': Icons.whatshot,
        'label': context.tr.streak7Days,
        'unlocked': streak >= 7,
      },
      {
        'icon': Icons.emoji_events,
        'label': context.tr.streak30Days,
        'unlocked': streak >= 30,
      },
      {
        'icon': Icons.replay,
        'label': context.tr.reviewNovice,
        'unlocked': reviews >= 10,
      },
      {
        'icon': Icons.repeat,
        'label': context.tr.reviewExpert,
        'unlocked': reviews >= 100,
      },
      {
        'icon': Icons.star,
        'label': context.tr.perfectionist,
        'unlocked': learnedWords >= totalWords * 0.9 && totalWords > 0,
      },
      {'icon': Icons.bookmark, 'label': '收藏整理者', 'unlocked': favorites >= 20},
      {
        'icon': Icons.folder_special,
        'label': '词集策划者',
        'unlocked': customSets >= 3,
      },
      {
        'icon': Icons.flag_circle,
        'label': '计划执行者',
        'unlocked': weeklyReport != null && weeklyReport.planCompletedDays >= 5,
      },
      {
        'icon': Icons.summarize,
        'label': '周报达人',
        'unlocked': weeklyReport != null && weeklyReport.studyDays >= 5,
      },
    ];
  }
}

/// 成就详情组件
class _AchievementDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isUnlocked;

  const _AchievementDetail({
    required this.icon,
    required this.label,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final lockedColor = FluidTheme.getTextTertiaryColor(isDark);
    final unlockedTextColor = FluidTheme.getTextPrimaryColor(isDark);

    return FluidCard(
      enableShimmer: isUnlocked,
      enableBorderGradient: isUnlocked,
      borderColors: isUnlocked ? FluidTheme.warningFluidGradient : null,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: isUnlocked
                ? FluidTheme.warningFluidGradient[0]
                : lockedColor,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isUnlocked ? unlockedTextColor : lockedColor,
            ),
          ),
        ],
      ),
    );
  }
}
