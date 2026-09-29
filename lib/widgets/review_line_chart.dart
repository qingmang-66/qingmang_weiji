import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
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

/// 复习趋势折线图 - 流体渐变风格
/// 支持 7/14/30 天切换，面积图+折线图组合
class ReviewLineChart extends StatefulWidget {
  final List<Map<String, dynamic>> dailyData;

  const ReviewLineChart({super.key, required this.dailyData});

  @override
  State<ReviewLineChart> createState() => _ReviewLineChartState();
}

class _ReviewLineChartState extends State<ReviewLineChart> {
  int _selectedRange = 7;

  //图表数据缓存：源数据、时间范围、主题都未变时复用上一份 LineChartData，
  //省去每次 build 重建 FlSpot/坐标轴；返回同一实例不影响 fl_chart 的
  //数据变更动画（引用相等即视为未变）
  List<Map<String, dynamic>>? _cacheSource;
  int? _cacheRange;
  bool? _cacheDark;
  LineChartData? _cacheChart;

  List<Map<String, dynamic>> get _filteredData {
    if (widget.dailyData.isEmpty) return [];
    if (widget.dailyData.length <= _selectedRange) return widget.dailyData;
    return widget.dailyData.sublist(widget.dailyData.length - _selectedRange);
  }

  @override
  Widget build(BuildContext context) {
    final data = _filteredData;
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
                    Icons.show_chart,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr.reviewTrend,
                    style: FluidTheme.labelLarge(
                      isDark,
                    ).copyWith(color: textPrimary),
                  ),
                ),
                _buildRangeChip(7, context.tr.days7, isDark, textSecondary),
                const SizedBox(width: 4),
                _buildRangeChip(14, context.tr.days14, isDark, textSecondary),
                const SizedBox(width: 4),
                _buildRangeChip(30, context.tr.days30, isDark, textSecondary),
              ],
            ),
            const SizedBox(height: 16),
            if (data.isNotEmpty)
              _buildSummaryRow(data, textPrimary, textSecondary, isDark),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: data.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 40,
                            color: textTertiary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr.noData,
                            style: FluidTheme.bodySmall(
                              isDark,
                            ).copyWith(color: textSecondary),
                          ),
                        ],
                      ),
                    )
                  : LineChart(_chartData(data, isDark, textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeChip(
    int days,
    String label,
    bool isDark,
    Color textSecondary,
  ) {
    final isSelected = _selectedRange == days;
    return GestureDetector(
      onTap: () => setState(() => _selectedRange = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? FluidTheme.primaryFluidGradient[0]
              : FluidTheme.getMutedOverlayColor(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? FluidTheme.primaryFluidGradient[0]
                : FluidTheme.getBorderColor(isDark),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    List<Map<String, dynamic>> data,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final total = data.fold<int>(0, (sum, d) => sum + (d['count'] as int));
    final avg = data.isEmpty ? 0 : (total / data.length).round();
    final max = data.isEmpty
        ? 0
        : data.map((d) => d['count'] as int).reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        _buildSummaryItem(
          context.tr.total,
          '$total',
          Icons.functions,
          textPrimary,
          textSecondary,
          isDark,
        ),
        const SizedBox(width: 24),
        _buildSummaryItem(
          context.tr.dailyAvg,
          '$avg',
          Icons.trending_up,
          textPrimary,
          textSecondary,
          isDark,
        ),
        const SizedBox(width: 24),
        _buildSummaryItem(
          context.tr.peak,
          '$max',
          Icons.emoji_events,
          textPrimary,
          textSecondary,
          isDark,
        ),
      ],
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: textSecondary),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: FluidTheme.bodySmall(
                  isDark,
                ).copyWith(color: textSecondary),
              ),
              Text(
                value,
                style: FluidTheme.labelLarge(
                  isDark,
                ).copyWith(color: textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  LineChartData _chartData(
    List<Map<String, dynamic>> data,
    bool isDark,
    Color textSecondary,
  ) {
    if (identical(widget.dailyData, _cacheSource) &&
        _selectedRange == _cacheRange &&
        isDark == _cacheDark &&
        _cacheChart != null) {
      return _cacheChart!;
    }
    final chart = _buildChartData(data, isDark, textSecondary);
    _cacheSource = widget.dailyData;
    _cacheRange = _selectedRange;
    _cacheDark = isDark;
    _cacheChart = chart;
    return chart;
  }

  LineChartData _buildChartData(
    List<Map<String, dynamic>> data,
    bool isDark,
    Color textSecondary,
  ) {
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

    final primaryColor = FluidTheme.primaryFluidGradient[0];

    return LineChartData(
      minY: 0,
      maxY: niceMax,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: niceMax > 20 ? 10 : (niceMax > 10 ? 5 : 1),
        getDrawingHorizontalLine: (value) =>
            FlLine(color: FluidTheme.getBorderColor(isDark), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: niceMax > 20 ? 10 : (niceMax > 10 ? 5 : 1),
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: TextStyle(fontSize: 10, color: textSecondary),
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
                  style: TextStyle(fontSize: 9, color: textSecondary),
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: primaryColor.withValues(alpha: 0),
          barWidth: 0,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor.withValues(alpha: isDark ? 0.25 : 0.18),
                primaryColor.withValues(alpha: isDark ? 0.05 : 0.08),
                primaryColor.withValues(alpha: 0),
              ],
            ),
          ),
        ),
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
                strokeColor: FluidTheme.getTextPrimaryColor(isDark),
              );
            },
          ),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => FluidTheme.getDialogSurfaceColor(isDark),
          tooltipRoundedRadius: 12,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.toInt();
              if (index < 0 || index >= data.length) return null;
              final date = data[index]['date'] as DateTime;
              final count = data[index]['count'] as int;
              return LineTooltipItem(
                '${date.month}/${date.day}\n$count ${context.tr.wordUnit}',
                TextStyle(
                  color: FluidTheme.getTextPrimaryColor(isDark),
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
}
