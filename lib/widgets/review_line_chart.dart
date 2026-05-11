import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// 复习趋势折线图 — 增强版
/// 支持 7/14/30 天切换，面积图+折线图组合
class ReviewLineChart extends StatefulWidget {
  final List<Map<String, dynamic>> dailyData;
  final ColorScheme colorScheme;

  const ReviewLineChart({
    super.key,
    required this.dailyData,
    required this.colorScheme,
  });

  @override
  State<ReviewLineChart> createState() => _ReviewLineChartState();
}

class _ReviewLineChartState extends State<ReviewLineChart> {
  int _selectedRange = 7; // 默认显示7天

  List<Map<String, dynamic>> get _filteredData {
    if (widget.dailyData.isEmpty) return [];
    if (widget.dailyData.length <= _selectedRange) return widget.dailyData;
    return widget.dailyData.sublist(widget.dailyData.length - _selectedRange);
  }

  @override
  Widget build(BuildContext context) {
    final data = _filteredData;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题 + 时间范围切换
            Row(
              children: [
                Icon(Icons.show_chart, color: widget.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t('复习趋势', 'Review Trend'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                _buildRangeChip(7, _t('7天', '7D')),
                const SizedBox(width: 4),
                _buildRangeChip(14, _t('14天', '14D')),
                const SizedBox(width: 4),
                _buildRangeChip(30, _t('30天', '30D')),
              ],
            ),
            const SizedBox(height: 20),

            // 汇总数据
            if (data.isNotEmpty) _buildSummaryRow(data),
            const SizedBox(height: 16),

            // 图表
            SizedBox(
              height: 200,
              child: data.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 40,
                              color: widget.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          Text(
                            _t('暂无数据', 'No data yet'),
                            style: TextStyle(
                              color: widget.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : LineChart(_buildChartData(data)),
            ),
          ],
        ),
      ),
    );
  }

  /// 时间范围选择 chip
  Widget _buildRangeChip(int days, String label) {
    final isSelected = _selectedRange == days;
    return GestureDetector(
      onTap: () => setState(() => _selectedRange = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? widget.colorScheme.primaryContainer
              : widget.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: widget.colorScheme.primary, width: 1)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? widget.colorScheme.primary
                : widget.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// 汇总数据行
  Widget _buildSummaryRow(List<Map<String, dynamic>> data) {
    final total = data.fold<int>(0, (sum, d) => sum + (d['count'] as int));
    final avg = data.isEmpty ? 0 : (total / data.length).round();
    final max = data.isEmpty
        ? 0
        : data.map((d) => d['count'] as int).reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        _buildSummaryItem(_t('总计', 'Total'), '$total', Icons.functions),
        const SizedBox(width: 24),
        _buildSummaryItem(_t('日均', 'Avg'), '$avg', Icons.trending_up),
        const SizedBox(width: 24),
        _buildSummaryItem(_t('峰值', 'Max'), '$max', Icons.emoji_events),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: widget.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: widget.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  LineChartData _buildChartData(List<Map<String, dynamic>> data) {
    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), (data[i]['count'] as int).toDouble()));
    }

    final maxY = spots.isEmpty
        ? 10.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final niceMax = maxY <= 5
        ? 5.0
        : maxY <= 10
            ? 10.0
            : ((maxY / 5).ceil() * 5).toDouble();

    final primaryColor = widget.colorScheme.primary;

    return LineChartData(
      minY: 0,
      maxY: niceMax,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: niceMax > 20 ? 10 : (niceMax > 10 ? 5 : 1),
        getDrawingHorizontalLine: (value) => FlLine(
          color: widget.colorScheme.outlineVariant.withValues(alpha: 0.2),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: niceMax > 20 ? 10 : (niceMax > 10 ? 5 : 1),
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: TextStyle(
                fontSize: 10,
                color: widget.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: data.length > 14 ? 3 : (data.length > 7 ? 2 : 1),
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= data.length) {
                return const SizedBox.shrink();
              }
              final date = data[index]['date'] as DateTime;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${date.month}/${date.day}',
                  style: TextStyle(
                    fontSize: 9,
                    color: widget.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        // 面积图（渐变填充）
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: primaryColor.withValues(alpha: 0.0),
          barWidth: 0,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor.withValues(alpha: 0.25),
                primaryColor.withValues(alpha: 0.05),
                primaryColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        // 折线图
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: primaryColor,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 3.5,
                color: primaryColor,
                strokeWidth: 2,
                strokeColor: widget.colorScheme.surface,
              );
            },
          ),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => widget.colorScheme.inverseSurface,
          tooltipRoundedRadius: 12,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.toInt();
              if (index < 0 || index >= data.length) return null;
              final date = data[index]['date'] as DateTime;
              final count = data[index]['count'] as int;
              return LineTooltipItem(
                '${date.month}/${date.day}\n$count ${_t('词', 'words')}',
                TextStyle(
                  color: widget.colorScheme.onInverseSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  String _t(String zh, String en) {
    return widget.colorScheme.brightness == Brightness.light ? zh : en;
  }
}
