import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/today_advice.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';

class TodayAdviceCard extends StatelessWidget {
  final TodayAdvice advice;

  const TodayAdviceCard({super.key, required this.advice});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: FluidTheme.getSurfaceGradientColors(isDark),
        ),
        borderRadius: BorderRadius.circular(FluidTheme.cardBorderRadius),
        border: Border.all(color: FluidTheme.getBorderColor(isDark), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _gradientColors()),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_icon(), color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr.todayAdviceTitle,
                    style: FluidTheme.labelLarge(
                      isDark,
                    ).copyWith(color: textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _description(context),
                    style: FluidTheme.bodySmall(
                      isDark,
                    ).copyWith(color: textSecondary, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon() {
    return switch (advice.type) {
      TodayAdviceType.reviewFirst => Icons.replay,
      TodayAdviceType.learnNewWords => Icons.school_outlined,
      TodayAdviceType.doneToday => Icons.task_alt,
      TodayAdviceType.waitForReview => Icons.event_available_outlined,
    };
  }

  List<Color> _gradientColors() {
    return switch (advice.type) {
      TodayAdviceType.reviewFirst => FluidTheme.warningFluidGradient,
      TodayAdviceType.learnNewWords => FluidTheme.primaryFluidGradient,
      TodayAdviceType.doneToday => FluidTheme.successFluidGradient,
      TodayAdviceType.waitForReview => FluidTheme.primaryFluidGradient,
    };
  }

  String _description(BuildContext context) {
    return switch (advice.type) {
      TodayAdviceType.reviewFirst =>
        '${context.tr.todayAdviceReview} ${context.tr.dueReviewsLabel} ${advice.dueWords}${context.tr.wordsSuffix}',
      TodayAdviceType.learnNewWords =>
        '${context.tr.todayAdviceNewWords} ${context.tr.remainingUnlearned} ${advice.unlearnedWords}${context.tr.wordsSuffix}',
      TodayAdviceType.doneToday => context.tr.todayAdviceDone,
      TodayAdviceType.waitForReview => context.tr.todayAdviceWaitReview,
    };
  }
}
