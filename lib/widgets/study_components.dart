import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../widgets/word_card.dart';
import '../utils/constants.dart';
import '../utils/translations.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';

/// 学习卡片组件
class StudyCard extends StatelessWidget {
  final Word word;
  final int currentIndex;
  final int totalWords;
  final bool showAnswer;
  final AnimationController animController;
  final Animation<double> slideAnimation;
  final Animation<double> fadeAnimation;
  final VoidCallback onShowAnswer;
  final Function(String) onDictionaryQuery;

  const StudyCard({
    super.key,
    required this.word,
    required this.currentIndex,
    required this.totalWords,
    required this.showAnswer,
    required this.animController,
    required this.slideAnimation,
    required this.fadeAnimation,
    required this.onShowAnswer,
    required this.onDictionaryQuery,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 进度条
        //totalWords=0（空词库/空练习直达）时 (currentIndex+1)/totalWords 会
        //得到 NaN，LinearProgressIndicator 的 value 断言（0<=v<=1）直接失败
        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0,
            end: totalWords > 0
                ? ((currentIndex + 1) / totalWords).clamp(0.0, 1.0)
                : 0.0,
          ),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return LinearProgressIndicator(
              value: value,
              backgroundColor: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            );
          },
        ),

        Expanded(
          child: GestureDetector(
            onPanEnd: showAnswer
                ? (details) {
                    final velocity = details.velocity.pixelsPerSecond.dx;
                    if (velocity.abs() > 300) {
                      HapticFeedback.selectionClick();
                    }
                  }
                : null,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AnimatedBuilder(
                animation: animController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, slideAnimation.value),
                    child: Opacity(opacity: fadeAnimation.value, child: child),
                  );
                },
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    WordCard(
                      word: word,
                      showDefinition: showAnswer,
                      onDictionaryQuery: onDictionaryQuery,
                    ),
                    const SizedBox(height: 20),
                    if (!showAnswer)
                      FilledButton.icon(
                        onPressed: onShowAnswer,
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(context.tr.showDefinition),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 回忆质量选择面板
class QualityPanel extends StatelessWidget {
  final bool isReview;
  final Future<void> Function(int) onQualitySelected;

  const QualityPanel({
    super.key,
    required this.isReview,
    required this.onQualitySelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: FluidTheme.getSurfaceGradientColors(isDark),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: FluidTheme.getBorderColor(isDark)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FluidTheme.getTextTertiaryColor(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isReview ? context.tr.recallQuality : context.tr.quizResult,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isReview
                  ? context.tr.recallQualityHint
                  : context.tr.quizResultHint,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (isReview) ...[
                  QualityButton(
                    label: context.tr.forgot,
                    color: Color(AppConstants.qualityColors[1]!),
                    onTap: () => onQualitySelected(1),
                  ),
                  const SizedBox(width: 6),
                  QualityButton(
                    label: context.tr.difficult,
                    color: Color(AppConstants.qualityColors[2]!),
                    onTap: () => onQualitySelected(2),
                  ),
                  const SizedBox(width: 6),
                  QualityButton(
                    label: context.tr.vague,
                    color: Color(AppConstants.qualityColors[3]!),
                    onTap: () => onQualitySelected(3),
                  ),
                  const SizedBox(width: 6),
                  QualityButton(
                    label: context.tr.easy,
                    color: Color(AppConstants.qualityColors[4]!),
                    onTap: () => onQualitySelected(4),
                  ),
                ] else ...[
                  QualityButton(
                    label: context.tr.wrong,
                    color: Color(AppConstants.qualityColors[1]!),
                    onTap: () => onQualitySelected(1),
                  ),
                  const SizedBox(width: 6),
                  QualityButton(
                    label: context.tr.right,
                    color: Color(AppConstants.qualityColors[4]!),
                    onTap: () => onQualitySelected(4),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 质量按钮
class QualityButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QualityButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<QualityButton> createState() => _QualityButtonState();
}

class _QualityButtonState extends State<QualityButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);

    return Expanded(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ElevatedButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            //动画完成回调可能在页面 pop 之后才到：对已 dispose 的
            //controller 调 reverse 会抛 AnimationController 断言
            _controller.forward().then((_) {
              if (!mounted) return;
              _controller.reverse();
              widget.onTap();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color.withValues(
              alpha: isDark ? 0.18 : 0.12,
            ),
            foregroundColor: widget.color,
            disabledBackgroundColor: widget.color.withValues(alpha: 0.08),
            //禁用态本就偏淡，但 0.45 在玻璃上过淡，提到 0.6
            disabledForegroundColor: widget.color.withValues(alpha: 0.6),
            elevation: 0,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
