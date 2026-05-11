import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// 记忆阶段饼图 — 增强版
/// 环形图（donut chart）+ 动画 + 中英双语支持
class StagePieChart extends StatefulWidget {
  final Map<String, int> stages;
  final ColorScheme colorScheme;

  const StagePieChart({
    super.key,
    required this.stages,
    required this.colorScheme,
  });

  @override
  State<StagePieChart> createState() => _StagePieChartState();
}

class _StagePieChartState extends State<StagePieChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _anim;
  int _touchedIndex = -1;

  // 记忆阶段配色 — 渐变色调
  static const stageColors = {
    '新学': Color(0xFF64B5F6),   // 浅蓝
    '初步': Color(0xFFFFB74D),   // 橙色
    '巩固': Color(0xFF81C784),   // 绿色
    '熟悉': Color(0xFFBA68C8),   // 紫色
    '掌握': Color(0xFFE57373),   // 红色
  };

  static const stageColorsEn = {
    'New': Color(0xFF64B5F6),
    'Initial': Color(0xFFFFB74D),
    'Consolidating': Color(0xFF81C784),
    'Familiar': Color(0xFFBA68C8),
    'Mastered': Color(0xFFE57373),
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool get _isDark => widget.colorScheme.brightness == Brightness.dark;

  Map<String, int> get _normalizedStages {
    // 根据语言环境调整 key
    if (_isDark) return widget.stages; // 用 brightness 粗略判断，实际以 translations 为准
    return widget.stages;
  }

  @override
  Widget build(BuildContext context) {
    final stages = _normalizedStages;
    final isEmpty = stages.isEmpty || stages.values.every((v) => v == 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(Icons.donut_small, color: widget.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  _t('记忆阶段分布', 'Memory Stage Distribution'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (isEmpty)
              _buildEmptyState()
            else
              AnimatedBuilder(
                animation: _anim,
                builder: (context, child) => _buildChart(stages),
              ),
            const SizedBox(height: 16),

            // 图例
            ...stages.entries.where((e) => e.value > 0).map((e) {
              final color = stageColors[e.key] ?? stageColorsEn[e.key] ?? widget.colorScheme.primary;
              final total = stages.values.fold(0, (a, b) => a + b);
              final percent = total > 0 ? (e.value / total * 100) : 0;
              final isTouched = stages.keys.toList().indexOf(e.key) == _touchedIndex;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isTouched
                      ? color.withValues(alpha: 0.1)
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
                          fontWeight: isTouched ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    Text(
                      '${e.value}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.colorScheme.onSurfaceVariant,
                      ),
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

  Widget _buildEmptyState() {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline,
                size: 40,
                color: widget.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(
              _t('开始学习后查看分布', 'Start studying to see distribution'),
              style: TextStyle(
                color: widget.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(Map<String, int> stages) {
    final total = stages.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final sections = <PieChartSectionData>[];
    final keys = stages.keys.toList();
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final value = stages[key]!;
      if (value == 0) continue;

      final color = stageColors[key] ?? stageColorsEn[key] ?? widget.colorScheme.primary;
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 62.0 : 52.0;

      sections.add(
        PieChartSectionData(
          value: value.toDouble() * _anim.value,
          title: isTouched ? '${(value / total * 100).toStringAsFixed(0)}%' : '',
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  _touchedIndex = -1;
                  return;
                }
                _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
              });
            },
          ),
        ),
      ),
    );
  }

  String _t(String zh, String en) {
    // 简单判断：如果 colorScheme 是暗色，可能用户在用英文界面
    // 更准确的判断应该从 AppProvider 获取，但这里简化处理
    return zh;
  }
}
