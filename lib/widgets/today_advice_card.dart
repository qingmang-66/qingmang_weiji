import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/today_advice.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../widgets/liquid_glass.dart';
import '../utils/translations.dart';

class TodayAdviceCard extends StatefulWidget {
  final TodayAdvice advice;
  const TodayAdviceCard({super.key, required this.advice});
  @override
  State<TodayAdviceCard> createState() => _TodayAdviceCardState();
}

class _TodayAdviceCardState extends State<TodayAdviceCard> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final content = Row(
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
    );
    // 玻璃模式用玻璃表面，经典模式保留渐变描边卡片
    Widget card;
    if (context.isLiquidGlass) {
      card = GlassSurface(
        borderRadius: FluidTheme.cardBorderRadius,
        padding: const EdgeInsets.all(16),
        child: content,
      );
    } else {
      card = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: FluidTheme.getSurfaceGradientColors(isDark),
          ),
          borderRadius: BorderRadius.circular(FluidTheme.cardBorderRadius),
          border: Border.all(
            color: FluidTheme.getBorderColor(isDark),
            width: 1,
          ),
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: content),
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? FluidTheme.cardHoverScale : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: card,
      ),
    );
  }

  IconData _icon() {
    return switch (widget.advice.type) {
      TodayAdviceType.reviewFirst => Icons.replay,
      TodayAdviceType.learnNewWords => Icons.school_outlined,
      TodayAdviceType.waitForReview => Icons.event_available_outlined,
    };
  }

  List<Color> _gradientColors() {
    return switch (widget.advice.type) {
      TodayAdviceType.reviewFirst => FluidTheme.warningFluidGradient,
      TodayAdviceType.learnNewWords => FluidTheme.primaryFluidGradient,
      TodayAdviceType.waitForReview => FluidTheme.primaryFluidGradient,
    };
  }

  String _description(BuildContext context) {
    return switch (widget.advice.type) {
      TodayAdviceType.reviewFirst =>
        '${context.tr.todayAdviceReview} ${context.tr.dueReviewsLabel} ${widget.advice.dueWords}${context.tr.wordsSuffix}',
      TodayAdviceType.learnNewWords =>
        '${context.tr.todayAdviceNewWords} ${context.tr.remainingUnlearned} ${widget.advice.unlearnedWords}${context.tr.wordsSuffix}',
      TodayAdviceType.waitForReview => context.tr.todayAdviceWaitReview,
    };
  }
}
