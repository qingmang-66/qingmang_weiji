import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/review_forecast.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import 'liquid_glass.dart';

/// 双风格卡片底盘：玻璃模式用玻璃表面，经典模式保留渐变描边
Widget _cardSurface(
  BuildContext context,
  bool isDark, {
  required Widget child,
}) {
  if (context.isLiquidGlass) {
    return GlassSurface(
      borderRadius: FluidTheme.cardBorderRadius,
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
      border: Border.all(color: FluidTheme.getBorderColor(isDark), width: 1),
    ),
    child: child,
  );
}

class ReviewForecastCard extends StatelessWidget {
  final ReviewForecast forecast;

  const ReviewForecastCard({super.key, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

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
                      colors: FluidTheme.warningFluidGradient,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.upcoming_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr.reviewForecastTitle,
                    style: FluidTheme.labelLarge(
                      isDark,
                    ).copyWith(color: textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.tr.reviewForecastDesc,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textSecondary),
            ),
            const SizedBox(height: 16),
            _buildSummary(context, isDark, textPrimary, textSecondary),
            const SizedBox(height: 18),
            if (forecast.days.isEmpty || forecast.total == 0)
              _buildEmptyState(context, isDark, textSecondary)
            else
              _buildBars(context, isDark, textPrimary, textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Row(
      children: [
        _SummaryItem(
          label: context.tr.total,
          value: '${forecast.total}',
          isDark: isDark,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(width: 12),
        _SummaryItem(
          label: context.tr.dailyAvg,
          value: '${forecast.average}',
          isDark: isDark,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(width: 12),
        _SummaryItem(
          label: context.tr.peak,
          value: '${forecast.peak}',
          isDark: isDark,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    Color textSecondary,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: FluidTheme.getMutedOverlayColor(isDark),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, color: textSecondary, size: 32),
          const SizedBox(height: 8),
          Text(
            context.tr.noUpcomingReviews,
            style: FluidTheme.bodySmall(isDark).copyWith(color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBars(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final maxCount = forecast.peak <= 0 ? 1 : forecast.peak;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: forecast.days.map((day) {
        final ratio = day.count / maxCount;
        final height = 18.0 + ratio * 74.0;
        final isToday = _isSameDate(day.date, DateTime.now());

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${day.count}',
                  style: FluidTheme.bodySmall(isDark).copyWith(
                    color: day.count > 0
                        ? FluidTheme.warningFluidGradient[0]
                        : textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  height: height,
                  width: 18,
                  decoration: BoxDecoration(
                    gradient: day.count > 0
                        ? LinearGradient(
                            colors: FluidTheme.warningFluidGradient,
                          )
                        : null,
                    color: day.count > 0
                        ? null
                        : FluidTheme.getMutedOverlayColor(isDark),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isToday
                          ? FluidTheme.primaryFluidGradient[0]
                          : FluidTheme.getBorderColor(isDark),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isToday
                      ? context.tr.today
                      : '${day.date.month}/${day.date.day}',
                  style: FluidTheme.bodySmall(isDark).copyWith(
                    color: isToday ? textPrimary : textSecondary,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: FluidTheme.getMutedOverlayColor(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FluidTheme.getBorderColor(isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: FluidTheme.labelLarge(
                isDark,
              ).copyWith(color: textPrimary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
