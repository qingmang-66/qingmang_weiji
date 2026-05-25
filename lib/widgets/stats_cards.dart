import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/translations.dart';
import '../theme/fluid_theme.dart';
import '../services/providers/theme_provider.dart';

/// 词汇量卡片 - 流体渐变风格
class VocabularyCard extends StatelessWidget {
  final Map<String, dynamic> stats;

  const VocabularyCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final learned = stats['learnedWords'] ?? 0;
    final total = stats['totalWords'] ?? 0;
    final estimatedVocab = _estimateVocabulary(learned);
    final progress = total > 0 ? (learned / total).clamp(0.0, 1.0) : 0.0;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.03),
                ]
              : [
                  Colors.white.withValues(alpha: 0.9),
                  Colors.white.withValues(alpha: 0.7),
                ],
        ),
        borderRadius: BorderRadius.circular(FluidTheme.cardBorderRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: FluidTheme.primaryFluidGradient,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.language,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Translations.t('词汇量', 'Vocabulary'),
                  style: FluidTheme.labelLarge.copyWith(color: textColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: estimatedVocab),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors: FluidTheme.primaryFluidGradient,
                          ).createShader(bounds);
                        },
                        child: Text(
                          '$value',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        Translations.t('估算词汇量', 'Estimated Vocabulary'),
                        style: FluidTheme.bodySmall.copyWith(
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Translations.t('学习进度', 'Progress'),
                  style: FluidTheme.bodySmall.copyWith(
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '$learned / $total',
                  style: FluidTheme.labelMedium.copyWith(color: textColor),
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
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      FluidTheme.primaryFluidGradient[0],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: FluidTheme.primaryFluidGradient[0],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _getVocabLevel(estimatedVocab),
                      style: FluidTheme.bodySmall.copyWith(
                        color: textColor.withValues(alpha: 0.6),
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
    final mastered =
        (stages['掌握'] ?? 0) * 1.0 +
        (stages['熟悉'] ?? 0) * 0.8 +
        (stages['巩固'] ?? 0) * 0.5;
    return (learnedWords * 0.6 + mastered).round();
  }

  String _getVocabLevel(int vocab) {
    if (vocab <= 0) {
      return Translations.t('开始学习吧！', 'Start learning!');
    }
    if (vocab < 500) {
      return Translations.t('入门级 — 继续加油！', 'Beginner — Keep going!');
    }
    if (vocab < 1000) {
      return Translations.t(
        '基础级 — 已超越大部分初学者',
        'Elementary — Beyond most beginners',
      );
    }
    if (vocab < 2000) {
      return Translations.t(
        'CET-4 水平 — 日常英语无障碍',
        'CET-4 Level — Daily English fluent',
      );
    }
    if (vocab < 3500) {
      return Translations.t(
        'CET-6 水平 — 可应对多数场景',
        'CET-6 Level — Most situations',
      );
    }
    if (vocab < 5000) {
      return Translations.t('雅思 7+ 水平 — 英语流利', 'IELTS 7+ — Fluent English');
    }
    return Translations.t('专八水平 — 接近母语者', 'Near-native level');
  }
}

/// 连续打卡卡片 - 流体渐变风格
class StreakCard extends StatelessWidget {
  final Map<String, dynamic> stats;

  const StreakCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final streak = stats['streak'] ?? 0;
    final totalStudyDays = stats['totalStudyDays'] ?? 0;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.03),
                ]
              : [
                  Colors.white.withValues(alpha: 0.9),
                  Colors.white.withValues(alpha: 0.7),
                ],
        ),
        borderRadius: BorderRadius.circular(FluidTheme.cardBorderRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: FluidTheme.warningFluidGradient,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_fire_department,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Translations.t('连续打卡', 'Streak'),
                    style: FluidTheme.bodySmall.copyWith(
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors: FluidTheme.warningFluidGradient,
                          ).createShader(bounds);
                        },
                        child: Text(
                          '$streak',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          Translations.t('天', 'days'),
                          style: FluidTheme.bodySmall.copyWith(
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Translations.t('累计学习', 'Total'),
                  style: FluidTheme.bodySmall.copyWith(
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalStudyDays ${Translations.t('天', 'days')}',
                  style: FluidTheme.labelLarge.copyWith(color: textColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
