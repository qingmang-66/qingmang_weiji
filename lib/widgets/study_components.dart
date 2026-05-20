import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/word.dart';
import '../widgets/word_card.dart';
import '../utils/constants.dart';

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
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (currentIndex + 1) / totalWords),
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
                    child: Opacity(
                      opacity: fadeAnimation.value,
                      child: child,
                    ),
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
                        label: const Text('显示释义'),
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
  final Function(int) onQualitySelected;

  const QualityPanel({
    super.key,
    required this.isReview,
    required this.onQualitySelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
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
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '回忆质量如何？',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              isReview ? '根据本次复习的记忆程度选择' : '根据本次学习的记忆程度选择',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                QualityButton(
                  label: '忘记',
                  color: Color(AppConstants.qualityColors[1]!),
                  onTap: () => onQualitySelected(1),
                ),
                const SizedBox(width: 6),
                QualityButton(
                  label: '困难',
                  color: Color(AppConstants.qualityColors[2]!),
                  onTap: () => onQualitySelected(2),
                ),
                const SizedBox(width: 6),
                QualityButton(
                  label: '模糊',
                  color: Color(AppConstants.qualityColors[3]!),
                  onTap: () => onQualitySelected(3),
                ),
                const SizedBox(width: 6),
                QualityButton(
                  label: '容易',
                  color: Color(AppConstants.qualityColors[4]!),
                  onTap: () => onQualitySelected(4),
                ),
                const SizedBox(width: 6),
                QualityButton(
                  label: '简单',
                  color: Color(AppConstants.qualityColors[5]!),
                  onTap: () => onQualitySelected(5),
                ),
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

class _QualityButtonState extends State<QualityButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ElevatedButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            _controller.forward().then((_) {
              _controller.reverse();
              widget.onTap();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color.withValues(alpha: 0.15),
            foregroundColor: widget.color,
            elevation: 0,
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
