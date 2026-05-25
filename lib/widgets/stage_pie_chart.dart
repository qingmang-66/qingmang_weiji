import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';

/// 记忆阶段饼图 - 流体渐变风格
/// 环形图（donut chart）+ 动画
class StagePieChart extends StatefulWidget {
  final Map<String, int> stages;

  const StagePieChart({super.key, required this.stages});

  @override
  State<StagePieChart> createState() => _StagePieChartState();
}

class _StagePieChartState extends State<StagePieChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _anim;
  int _touchedIndex = -1;

  static const stageColors = {
    '新学': Color(0xFF64B5F6),
    '初步': Color(0xFFFFB74D),
    '巩固': Color(0xFF81C784),
    '熟悉': Color(0xFFBA68C8),
    '掌握': Color(0xFFE57373),
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _anim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stages = widget.stages;
    final isEmpty = stages.isEmpty || stages.values.every((v) => v == 0);
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final textTertiary = FluidTheme.getTextTertiaryColor(isDark);

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
                    Icons.donut_small,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '记忆阶段分布',
                  style: FluidTheme.labelLarge.copyWith(color: textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isEmpty)
              _buildEmptyState(textSecondary, textTertiary)
            else
              AnimatedBuilder(
                animation: _anim,
                builder: (context, child) => _buildChart(stages, isDark),
              ),
            const SizedBox(height: 16),
            ...stages.entries.where((e) => e.value > 0).map((e) {
              final color = stageColors[e.key] ?? const Color(0xFF5B6AFF);
              final total = stages.values.fold(0, (a, b) => a + b);
              final percent = total > 0 ? (e.value / total * 100) : 0;
              final isTouched =
                  stages.keys.toList().indexOf(e.key) == _touchedIndex;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isTouched
                      ? color.withValues(alpha: isDark ? 0.15 : 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isTouched
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${e.value}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textSecondary, Color textTertiary) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 40, color: textTertiary),
            const SizedBox(height: 8),
            Text(
              '开始学习后查看分布',
              style: FluidTheme.bodySmall.copyWith(color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(Map<String, int> stages, bool isDark) {
    final total = stages.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final sections = <PieChartSectionData>[];
    final keys = stages.keys.toList();
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final value = stages[key]!;
      if (value == 0) continue;

      final color = stageColors[key] ?? const Color(0xFF5B6AFF);
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 62.0 : 52.0;

      sections.add(
        PieChartSectionData(
          value: value.toDouble() * _anim.value,
          title: isTouched
              ? '${(value / total * 100).toStringAsFixed(0)}%'
              : '',
          color: color,
          radius: radius,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
          ),
          badgeWidget: isTouched
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1a1a2e) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color, width: 1),
                  ),
                  child: Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                )
              : null,
          badgePositionPercentageOffset: 1.3,
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 55,
          sectionsSpace: 2,
          startDegreeOffset: -90,
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null) {
                  _touchedIndex = -1;
                  return;
                }
                final touchedSection = pieTouchResponse.touchedSection;
                if (touchedSection == null) {
                  _touchedIndex = -1;
                  return;
                }
                _touchedIndex = touchedSection.touchedSectionIndex;
              });
            },
          ),
        ),
      ),
    );
  }
}
