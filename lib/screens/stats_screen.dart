import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/providers/providers.dart';
import '../services/di_container.dart';
import '../utils/translations.dart';
import '../widgets/review_line_chart.dart';
import '../widgets/stage_pie_chart.dart';
import '../widgets/study_heatmap.dart';
import '../widgets/stats_cards.dart';

/// 统计页面 — 完善版
/// 包含：词汇量卡片、连续打卡、学习日历热力图、今日数据、复习趋势图、记忆阶段饼图、成就系统
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _dailyData = [];
  Map<DateTime, int> _heatmapData = {};
  bool _isLoading = true;
  WordBookProvider? _wordBookProvider;

  @override
  void initState() {
    super.initState();
    _loadStats();
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
    if (mounted) _loadStats();
  }

  @override
  void dispose() {
    _wordBookProvider?.removeListener(_onProviderChanged);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final statsRepository = context.read<DIContainer>().statsRepository;
    final stats = await statsRepository.getStudyStats();
    final dailyData = await statsRepository.getDailyReviewStats(days: 365);

    // 构建热力图数据
    final heatmapData = <DateTime, int>{};
    for (final d in dailyData) {
      final date = d['date'] as DateTime;
      final key = DateTime(date.year, date.month, date.day);
      heatmapData[key] = (heatmapData[key] ?? 0) + (d['count'] as int);
    }

    if (mounted) {
      setState(() {
        _stats = stats;
        _dailyData = dailyData;
        _heatmapData = heatmapData;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.t('学习统计', 'Study Stats')),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            onPressed: () => _showAchievements(context),
            tooltip: Translations.t('成就', 'Achievements'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. 词汇量 + 进度
                  VocabularyCard(stats: _stats, colorScheme: colorScheme),
                  const SizedBox(height: 12),

                  // 2. 连续打卡
                  StreakCard(stats: _stats, colorScheme: colorScheme),
                  const SizedBox(height: 12),

                  // 3. 今日数据
                  TodayStatsCard(stats: _stats, colorScheme: colorScheme),
                  const SizedBox(height: 12),

                  // 4. 学习日历热力图
                  StudyHeatmap(data: _heatmapData, colorScheme: colorScheme),
                  const SizedBox(height: 12),

                  // 5. 复习趋势折线图
                  ReviewLineChart(dailyData: _dailyData, colorScheme: colorScheme),
                  const SizedBox(height: 12),

                  // 6. 记忆阶段饼图
                  if (_stats['stages'] != null)
                    StagePieChart(
                      stages: Map<String, int>.from(_stats['stages']),
                      colorScheme: colorScheme,
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }


  void _showAchievements(BuildContext context) {
    final achievements = _getAchievements();
    final unlockedCount = achievements.where((a) => a['unlocked'] as bool).length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            // 顶部标题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      Translations.t('成就中心', 'Achievements'),
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unlockedCount / ${achievements.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 成就网格
            Expanded(
              child: achievements.isEmpty
                  ? Center(
                      child: Text(
                        Translations.t('暂无成就', 'No achievements yet'),
                        style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                      ),
                    )
                  : GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
    final streak = _stats['streak'] ?? 0;
    final learned = _stats['learnedWords'] ?? 0;
    final todayNew = _stats['todayNew'] ?? 0;
    final todayReview = _stats['todayReview'] ?? 0;

    return [
      {'icon': Icons.school, 'label': Translations.t('初次见面', 'First Step'), 'unlocked': learned > 0},
      {'icon': Icons.local_fire_department, 'label': Translations.t('3天连续', '3-Day Streak'), 'unlocked': streak >= 3},
      {'icon': Icons.star, 'label': Translations.t('7天连续', '7-Day Streak'), 'unlocked': streak >= 7},
      {'icon': Icons.emoji_events, 'label': Translations.t('30天连续', '30-Day Streak'), 'unlocked': streak >= 30},
      {'icon': Icons.workspace_premium, 'label': Translations.t('百天连续', '100-Day Streak'), 'unlocked': streak >= 100},
      {'icon': Icons.menu_book, 'label': Translations.t('学习10词', '10 Words'), 'unlocked': learned >= 10},
      {'icon': Icons.auto_stories, 'label': Translations.t('学习50词', '50 Words'), 'unlocked': learned >= 50},
      {'icon': Icons.library_books, 'label': Translations.t('学习100词', '100 Words'), 'unlocked': learned >= 100},
      {'icon': Icons.psychology, 'label': Translations.t('学习500词', '500 Words'), 'unlocked': learned >= 500},
      {'icon': Icons.today, 'label': Translations.t('今日新学', 'Today New'), 'unlocked': todayNew > 0},
      {'icon': Icons.celebration, 'label': Translations.t('高效达人', 'Efficient'), 'unlocked': todayNew >= 20},
      {'icon': Icons.autorenew, 'label': Translations.t('复习达人', 'Review Master'), 'unlocked': todayReview >= 50},
    ];
  }
}

// ========== 成就详情组件 ==========

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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked
            ? Colors.amber.withValues(alpha: 0.08)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? Colors.amber.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? Colors.amber.withValues(alpha: 0.2)
                  : colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 28,
              color: isUnlocked ? Colors.amber : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isUnlocked ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                  fontWeight: isUnlocked ? FontWeight.w600 : FontWeight.normal,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!isUnlocked) ...[
            const SizedBox(height: 4),
            Icon(
              Icons.lock_outline,
              size: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ],
      ),
    );
  }
}
