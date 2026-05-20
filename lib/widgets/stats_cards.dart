import 'package:flutter/material.dart';
import '../utils/translations.dart';

/// 词汇量卡片
class VocabularyCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final ColorScheme colorScheme;

  const VocabularyCard({
    super.key,
    required this.stats,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final learned = stats['learnedWords'] ?? 0;
    final total = stats['totalWords'] ?? 0;
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
    final stages = stats['stages'] as Map<String, int>? ?? {};
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
}

/// 连续打卡卡片
class StreakCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final ColorScheme colorScheme;

  const StreakCard({
    super.key,
    required this.stats,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final streak = stats['streak'] ?? 0;
    final todayNew = stats['todayNew'] ?? 0;
    final todayReview = stats['todayReview'] ?? 0;
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
                  Translations.t('连续打卡', 'Streak'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.timeline,
                    label: Translations.t('连续天数', 'Days'),
                    value: '$streak',
                    color: Colors.orange,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.today,
                    label: Translations.t('今日学习', 'Today'),
                    value: '$todayTotal',
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 今日数据卡片
class TodayStatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final ColorScheme colorScheme;

  const TodayStatsCard({
    super.key,
    required this.stats,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final todayNew = stats['todayNew'] ?? 0;
    final todayReview = stats['todayReview'] ?? 0;
    final masteryRate = stats['masteryRate'] ?? 0;

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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.add_circle_outline,
                    label: Translations.t('新词', 'New'),
                    value: '$todayNew',
                    color: colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.replay,
                    label: Translations.t('复习', 'Review'),
                    value: '$todayReview',
                    color: colorScheme.tertiary,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.check_circle_outline,
                    label: Translations.t('掌握率', 'Mastery'),
                    value: '${masteryRate.toStringAsFixed(0)}%',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 统计项
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.8),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
