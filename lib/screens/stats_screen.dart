import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/providers/providers.dart';
import '../services/di_container.dart';
import '../services/repositories/stats_repository.dart';
import '../theme/fluid_theme.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_card.dart';
import '../utils/translations.dart';
import '../widgets/review_line_chart.dart';
import '../widgets/stage_pie_chart.dart';
import '../widgets/study_calendar.dart';
import '../widgets/stats_cards.dart';

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
              Translations.t('学习统计', 'Study Stats'),
              style: FluidTheme.headingMedium.copyWith(color: textPrimary),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.emoji_events,
                  color: FluidTheme.warningFluidGradient[0],
                ),
                onPressed: () => _showAchievements(context),
                tooltip: Translations.t('成就', 'Achievements'),
              ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.all(padding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                VocabularyCard(stats: _stats),
                const SizedBox(height: 12),
                StreakCard(stats: _stats),
                const SizedBox(height: 12),
                StudyCalendar(data: _heatmapData),
                const SizedBox(height: 12),
                ReviewLineChart(dailyData: _dailyData),
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
                      Translations.t('成就中心', 'Achievements'),
                      style: FluidTheme.headingSmall.copyWith(
                        color: textPrimary,
                      ),
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
                        Translations.t('暂无成就', 'No achievements yet'),
                        style: FluidTheme.bodyMedium.copyWith(
                          color: textSecondary,
                        ),
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

    return [
      {'icon': Icons.school, 'label': '初学者', 'unlocked': learnedWords >= 10},
      {
        'icon': Icons.menu_book,
        'label': '词汇达人',
        'unlocked': learnedWords >= 100,
      },
      {
        'icon': Icons.auto_stories,
        'label': '词汇大师',
        'unlocked': learnedWords >= 500,
      },
      {
        'icon': Icons.local_fire_department,
        'label': '连续3天',
        'unlocked': streak >= 3,
      },
      {'icon': Icons.whatshot, 'label': '连续7天', 'unlocked': streak >= 7},
      {'icon': Icons.emoji_events, 'label': '连续30天', 'unlocked': streak >= 30},
      {'icon': Icons.replay, 'label': '复习新手', 'unlocked': reviews >= 10},
      {'icon': Icons.repeat, 'label': '复习达人', 'unlocked': reviews >= 100},
      {
        'icon': Icons.star,
        'label': '完美主义者',
        'unlocked': learnedWords >= totalWords * 0.9 && totalWords > 0,
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
