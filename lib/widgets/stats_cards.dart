import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/memory_stage.dart';
import '../utils/translations.dart';
import '../theme/fluid_theme.dart';
import '../services/providers/theme_provider.dart';
import 'liquid_glass.dart';

/// 双风格卡片底盘：玻璃模式用玻璃表面，经典模式保留渐变描边
Widget _cardSurface(
  BuildContext context,
  bool isDark, {
  required Widget child,
  bool grain = false,
}) {
  if (context.isLiquidGlass) {
    return GlassSurface(
      borderRadius: FluidTheme.cardBorderRadius,
      grain: grain,
      child: child,
    );
  }
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: FluidTheme.getSurfaceGradientColors(isDark),
      ),
      borderRadius: BorderRadius.circular(FluidTheme.cardBorderRadius),
      border: Border.all(color: FluidTheme.getBorderColor(isDark), width: 1.0),
    ),
    child: child,
  );
}

/// 词汇量卡片 - 流体渐变风格
class VocabularyCard extends StatelessWidget {
  final Map<String, dynamic> stats;

  const VocabularyCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    // 先经 num 收敛再取整：数据源字段可能是 double 或缺失，
    // dynamic 直传 int 形参会抛 TypeError
    final learned = (stats['learnedWords'] as num?)?.toInt() ?? 0;
    final total = (stats['totalWords'] as num?)?.toInt() ?? 0;
    final estimatedVocab = _estimateVocabulary(learned, context);
    final progress = total > 0 ? (learned / total).clamp(0.0, 1.0) : 0.0;
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textColor = FluidTheme.getTextPrimaryColor(isDark);

    return _cardSurface(
      context,
      isDark,
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
                  context.tr.vocabularyLevel,
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: textColor),
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
                            //浅色下用压暗渐变，大数字在浅玻璃上才可读
                            colors: FluidTheme.textGradient(isDark),
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
                        context.tr.estimatedVocabulary,
                        style: FluidTheme.bodySmall(
                          isDark,
                        ).copyWith(color: textColor.withValues(alpha: 0.78)),
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
                  context.tr.studyProgress,
                  style: FluidTheme.bodySmall(
                    isDark,
                  ).copyWith(color: textColor.withValues(alpha: 0.78)),
                ),
                Text(
                  '$learned / $total',
                  style: FluidTheme.labelMedium(
                    isDark,
                  ).copyWith(color: textColor),
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
                    backgroundColor: FluidTheme.getMutedOverlayColor(isDark),
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
                  style: FluidTheme.numberStyle(
                    fontSize: 14,
                    color: FluidTheme.primaryFluidGradient[0],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FluidTheme.getMutedOverlayColor(isDark),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _getVocabLevel(estimatedVocab, context),
                      style: FluidTheme.bodySmall(
                        isDark,
                      ).copyWith(color: textColor.withValues(alpha: 0.78)),
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

  int _estimateVocabulary(int learnedWords, BuildContext context) {
    final stages = stats['stages'] as Map<String, int>? ?? {};
    // 使用 MemoryStage 枚举名称作为 key，与数据库输出一致，不受语言切换影响
    final mastered =
        (stages[MemoryStage.mastered.name] ?? 0) * 1.0 +
        (stages[MemoryStage.familiar.name] ?? 0) * 0.8 +
        (stages[MemoryStage.consolidating.name] ?? 0) * 0.5;
    return (learnedWords * 0.6 + mastered).round();
  }

  String _getVocabLevel(int vocab, BuildContext context) {
    if (vocab <= 0) {
      return context.tr.startLearningHint;
    }
    if (vocab < 500) {
      return context.tr.beginnerLevel;
    }
    if (vocab < 1000) {
      return context.tr.basicLevel;
    }
    if (vocab < 2000) {
      return context.tr.cet4Level;
    }
    if (vocab < 3500) {
      return context.tr.cet6Level;
    }
    if (vocab < 5000) {
      return context.tr.ielts7Level;
    }
    return context.tr.nearNativeLevel;
  }
}

/// 连续打卡卡片 - 流体渐变风格
class StreakCard extends StatelessWidget {
  final Map<String, dynamic> stats;

  const StreakCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    // 同 VocabularyCard：先经 num 收敛再取整，避免 dynamic 直传 int 抛错
    final streak = (stats['streak'] as num?)?.toInt() ?? 0;
    final totalStudyDays = (stats['totalStudyDays'] as num?)?.toInt() ?? 0;
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textColor = FluidTheme.getTextPrimaryColor(isDark);

    return _cardSurface(
      context,
      isDark,
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
                    context.tr.streakCheckIn,
                    style: FluidTheme.bodySmall(
                      isDark,
                    ).copyWith(color: textColor.withValues(alpha: 0.78)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            //琥珀原色在浅色背景上仅 2.15:1，文字用压暗变体
                            colors: isDark
                                ? FluidTheme.warningFluidGradient
                                : const [Color(0xFFB45309)],
                          ).createShader(bounds);
                        },
                        child: Text(
                          '$streak',
                          style: FluidTheme.numberStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          context.tr.days,
                          style: FluidTheme.bodySmall(
                            isDark,
                          ).copyWith(color: textColor.withValues(alpha: 0.78)),
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
                  context.tr.totalStudy,
                  style: FluidTheme.bodySmall(
                    isDark,
                  ).copyWith(color: textColor.withValues(alpha: 0.78)),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalStudyDays ${context.tr.days}',
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: textColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
