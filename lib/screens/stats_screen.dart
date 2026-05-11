import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/services.dart';
import '../utils/translations.dart';
import '../widgets/review_line_chart.dart';
import '../widgets/stage_pie_chart.dart';
import '../widgets/study_heatmap.dart';

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
  AppProvider? _appProvider;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newProvider = Provider.of<AppProvider>(context, listen: false);
    if (newProvider != _appProvider) {
      _appProvider?.removeListener(_onProviderChanged);
      _appProvider = newProvider;
      _appProvider!.addListener(_onProviderChanged);
    }
  }

  void _onProviderChanged() {
    if (mounted) _loadStats();
  }

  @override
  void dispose() {
    _appProvider?.removeListener(_onProviderChanged);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await DatabaseService.getStudyStats();
    final dailyData = await DatabaseService.getDailyReviewStats(days: 365);

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
                  _buildVocabularyCard(colorScheme),
                  const SizedBox(height: 12),

                  // 2. 连续打卡
                  _buildStreakCard(colorScheme),
                  const SizedBox(height: 12),

                  // 3. 今日数据
                  _buildTodayCard(colorScheme),
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

  // ========== 1. 词汇量卡片 ==========

  Widget _buildVocabularyCard(ColorScheme colorScheme) {
    final learned = _stats['learnedWords'] ?? 0;
    final total = _stats['totalWords'] ?? 0;
    final estimatedVocab = _estimateVocabulary(learned);
    final progress = total > 0 ? (learned / total).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.language, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  Translations.t('词汇量', 'Vocabulary'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 大数字动画
            Center(
              child: TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: estimatedVocab),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Column(
                    children: [
                      Text(
                        '$value',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                      ),
                      Text(
                        Translations.t('估算词汇量', 'Estimated Vocabulary'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // 进度条：已学 / 总词库
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Translations.t('学习进度', 'Progress'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '$learned / $total',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 等级标签
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getVocabLevel(estimatedVocab),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _estimateVocabulary(int learnedWords) {
    final stages = _stats['stages'] as Map<String, int>? ?? {};
    final mastered = (stages['掌握'] ?? 0) * 1.0 +
                     (stages['熟悉'] ?? 0) * 0.8 +
                     (stages['巩固'] ?? 0) * 0.5;
    return (learnedWords * 0.6 + mastered).round();
  }

  String _getVocabLevel(int vocab) {
    if (vocab <= 0) return Translations.t('开始学习吧！', 'Start learning!');
    if (vocab < 500) return Translations.t('入门级 — 继续加油！', 'Beginner — Keep going!');
    if (vocab < 1000) return Translations.t('基础级 — 已超越大部分初学者', 'Elementary — Beyond most beginners');
    if (vocab < 2000) return Translations.t('CET-4 水平 — 日常英语无障碍', 'CET-4 Level — Daily English fluent');
    if (vocab < 3500) return Translations.t('CET-6 水平 — 可应对多数场景', 'CET-6 Level — Handle most situations');
    if (vocab < 5000) return Translations.t('考研水平 — 学术英语基础', 'Graduate Level — Academic English ready');
    if (vocab < 8000) return Translations.t('雅思/托福水平 — 高阶英语能力', 'IELTS/TOEFL Level — Advanced English');
    return Translations.t('专业级 — 英语达人！', 'Expert Level — English master!');
  }

  // ========== 2. 连续打卡卡片 ==========

  Widget _buildStreakCard(ColorScheme colorScheme) {
    final streak = _stats['streak'] ?? 0;
    final todayNew = _stats['todayNew'] ?? 0;
    final todayReview = _stats['todayReview'] ?? 0;
    final todayTotal = todayNew + todayReview;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orange, size: 22),
                const SizedBox(width: 8),
                Text(
                  Translations.t('连续学习', 'Study Streak'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 两大数字
            Row(
              children: [
                Expanded(
                  child: _buildBigNumber(
                    '$streak',
                    Translations.t('天连续', 'Day Streak'),
                    Colors.orange,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _buildBigNumber(
                    '$todayTotal',
                    Translations.t('今日复习', 'Today Reviewed'),
                    colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 今日细分
            if (todayTotal > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildSubStat(
                      Icons.add_circle,
                      Translations.t('新学', 'New'),
                      '$todayNew',
                      colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _buildSubStat(
                      Icons.replay_circle_filled,
                      Translations.t('复习', 'Review'),
                      '$todayReview',
                      colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // 里程碑进度
            _buildMilestoneProgress(streak, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildBigNumber(String value, String label, Color color) {
    return Column(
      children: [
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: int.tryParse(value) ?? 0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) {
            return Text(
              '$val',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            );
          },
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildSubStat(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneProgress(int streak, ColorScheme colorScheme) {
    final milestones = [3, 7, 14, 30, 60, 100, 365];
    int prevMilestone = 0;
    int nextMilestone = milestones[0];

    for (final m in milestones) {
      if (streak >= m) {
        prevMilestone = m;
        final idx = milestones.indexOf(m);
        nextMilestone = idx < milestones.length - 1 ? milestones[idx + 1] : m;
      }
    }

    if (streak >= milestones.last) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Text(
              Translations.t('🎉 已达成所有里程碑！', '🎉 All milestones achieved!'),
              style: TextStyle(color: Colors.amber.shade700, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final range = nextMilestone - prevMilestone;
    final progress = range > 0 ? ((streak - prevMilestone) / range).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$prevMilestone ${Translations.t('天', 'days')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '$nextMilestone ${Translations.t('天', 'days')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 600),
          builder: (context, value, child) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: Colors.orange,
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          Translations.t('还需 ${nextMilestone - streak} 天达成下一里程碑', '${nextMilestone - streak} days to next milestone'),
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ========== 3. 今日数据卡片 ==========

  Widget _buildTodayCard(ColorScheme colorScheme) {
    final todayNew = _stats['todayNew'] ?? 0;
    final todayReview = _stats['todayReview'] ?? 0;
    final dueWords = _stats['dueWords'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  Translations.t('今日数据', 'Today'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 三个数据项
            Row(
              children: [
                Expanded(
                  child: _buildTodayItem(
                    Icons.add_circle,
                    Translations.t('新学', 'New'),
                    '$todayNew',
                    colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildTodayItem(
                    Icons.replay_circle_filled,
                    Translations.t('复习', 'Review'),
                    '$todayReview',
                    colorScheme.tertiary,
                  ),
                ),
                Expanded(
                  child: _buildTodayItem(
                    Icons.pending_actions,
                    Translations.t('待复习', 'Due'),
                    '$dueWords',
                    dueWords > 0 ? Colors.orange : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            // 新学 vs 复习 对比条
            if (todayNew > 0 || todayReview > 0) ...[
              const SizedBox(height: 16),
              _buildTodayBar(todayNew, todayReview, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTodayItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildTodayBar(int newCount, int reviewCount, ColorScheme colorScheme) {
    final total = newCount + reviewCount;
    if (total == 0) return const SizedBox.shrink();

    final newRatio = newCount / total;
    final reviewRatio = reviewCount / total;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  flex: (newRatio * 100).round(),
                  child: Container(color: colorScheme.primary),
                ),
                Expanded(
                  flex: (reviewRatio * 100).round(),
                  child: Container(color: colorScheme.tertiary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBarLegend(colorScheme.primary, Translations.t('新学', 'New'), '$newCount'),
            const SizedBox(width: 20),
            _buildBarLegend(colorScheme.tertiary, Translations.t('复习', 'Review'), '$reviewCount'),
          ],
        ),
      ],
    );
  }

  Widget _buildBarLegend(Color color, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $value',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ========== 成就弹窗 ==========

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
