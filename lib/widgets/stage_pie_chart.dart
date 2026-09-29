import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/memory_stage.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import 'liquid_glass.dart';

/// 双风格卡片底盘：玻璃模式用玻璃表面（大卡带噪点），经典模式保留渐变描边
Widget _cardSurface(
  BuildContext context,
  bool isDark, {
  required Widget child,
}) {
  if (context.isLiquidGlass) {
    return GlassSurface(
      borderRadius: FluidTheme.cardBorderRadius,
      grain: true,
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

  // 使用 MemoryStage 枚举名称作为 key，与数据库输出一致，不受语言切换影响
  static const Map<String, Color> _stageColors = {
    'newLearned': Color(0xFF64B5F6),
    'initial': Color(0xFFFFB74D),
    'consolidating': Color(0xFF81C784),
    'familiar': Color(0xFFBA68C8),
    'mastered': Color(0xFFE57373),
  };

  /// 将 stage key（枚举名称）转换为当前语言的显示文本
  String _stageDisplayName(String stageKey) {
    final stage = MemoryStage.values.firstWhere(
      (s) => s.name == stageKey,
      orElse: () => MemoryStage.newLearned,
    );
    return stage.displayName(context);
  }

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
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final textTertiary = FluidTheme.getTextTertiaryColor(isDark);

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
                    Icons.donut_small,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr.memoryStages,
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isEmpty)
              _buildEmptyState(textSecondary, textTertiary, isDark)
            else
              AnimatedBuilder(
                animation: _anim,
                builder: (context, child) => _buildChart(stages, isDark),
              ),
            const SizedBox(height: 16),
            ...stages.entries.where((e) => e.value > 0).map((e) {
              final color =
                  _stageColors[e.key] ?? FluidTheme.primaryFluidGradient[0];
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
                        _stageDisplayName(e.key),
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

  Widget _buildEmptyState(
    Color textSecondary,
    Color textTertiary,
    bool isDark,
  ) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 40, color: textTertiary),
            const SizedBox(height: 8),
            Text(
              context.tr.startToSeeDistribution,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textSecondary),
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

      final color = _stageColors[key] ?? FluidTheme.primaryFluidGradient[0];
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
          titleStyle:
              FluidTheme.numberStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                letterSpacing: 0.7,
              ).copyWith(
                shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
              ),
          badgeWidget: isTouched
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: FluidTheme.getDialogSurfaceColor(isDark),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color, width: 1),
                  ),
                  child: Text(
                    '$value',
                    style: FluidTheme.numberStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
                      letterSpacing: 0.6,
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
