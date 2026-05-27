import 'package:flutter/material.dart';
import '../utils/translations.dart';

/// 学习日历热力图 — GitHub 风格贡献日历
/// 展示过去一年（53周 × 7天）的学习记录
class StudyHeatmap extends StatelessWidget {
  /// 日期 -> 学习数量的映射
  final Map<DateTime, int> data;

  const StudyHeatmap({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B6AFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr.studyCalendar,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.tr.pastYearRecord,
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),

            // 热力图
            _buildHeatmap(context),
            const SizedBox(height: 16),

            // 底部：图例 + 统计
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap(BuildContext context) {
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day);
    final startDate = endDate.subtract(const Duration(days: 53 * 7 - 1));
    final firstDay = startDate.subtract(Duration(days: startDate.weekday % 7));

    // 计算总周数
    final totalDays = endDate.difference(firstDay).inDays + 1;
    final totalWeeks = (totalDays / 7).ceil();

    // 计算月份标签
    final monthLabels = <Map<String, dynamic>>[];
    var currentMonth = -1;
    for (var i = 0; i < totalWeeks; i++) {
      final weekStart = firstDay.add(Duration(days: i * 7));
      if (weekStart.month != currentMonth) {
        currentMonth = weekStart.month;
        monthLabels.add({'label': _monthShort(currentMonth), 'weekIndex': i});
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 月份标签行
          SizedBox(
            height: 14,
            width: totalWeeks * (_cellSize + _cellGap) + 30,
            child: Stack(
              children: monthLabels.map((m) {
                return Positioned(
                  left: 30.0 + (m['weekIndex'] as int) * (_cellSize + _cellGap),
                  child: Text(
                    m['label'] as String,
                    style: TextStyle(
                      fontSize: 9,
                      color: const Color(0xFF1A1A2E).withValues(alpha: 0.6),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 2),

          // 热力图主体
          SizedBox(
            height: 7 * (_cellSize + _cellGap),
            width: totalWeeks * (_cellSize + _cellGap) + 30,
            child: CustomPaint(
              painter: _HeatmapPainter(
                data: data,
                firstDay: firstDay,
                endDate: endDate,
                totalWeeks: totalWeeks,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final activeDays = data.values.where((c) => c > 0).length;
    final totalWords = data.values.fold(0, (sum, c) => sum + c);
    final maxDay = data.values.isEmpty
        ? 0
        : data.values.reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        // 统计信息
        Expanded(
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _buildStatChip(
                Icons.local_fire_department,
                context.tr.activeDays,
                '$activeDays',
              ),
              _buildStatChip(
                Icons.functions,
                context.tr.totalWordsLabel,
                '$totalWords',
              ),
              if (maxDay > 0)
                _buildStatChip(
                  Icons.emoji_events,
                  context.tr.dailyMax,
                  '$maxDay',
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // 图例
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr.less,
              style: TextStyle(
                fontSize: 10,
                color: const Color(0xFF1A1A2E).withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 4),
            ...List.generate(5, (i) {
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: _getLevelColor(i),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
            const SizedBox(width: 4),
            Text(
              context.tr.more,
              style: TextStyle(
                fontSize: 10,
                color: const Color(0xFF1A1A2E).withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: const Color(0xFF1A1A2E).withValues(alpha: 0.6),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ========== 工具方法 ==========

  static const double _cellSize = 11;
  static const double _cellGap = 2;

  /// 获取等级对应的颜色
  Color _getLevelColor(int level) {
    switch (level) {
      case 0:
        return const Color(0xFF1A1A2E).withValues(alpha: 0.5);
      case 1:
        return const Color(0xFF5B6AFF).withValues(alpha: 0.2);
      case 2:
        return const Color(0xFF5B6AFF).withValues(alpha: 0.4);
      case 3:
        return const Color(0xFF5B6AFF).withValues(alpha: 0.6);
      case 4:
        return const Color(0xFF5B6AFF).withValues(alpha: 0.85);
      default:
        return const Color(0xFF5B6AFF).withValues(alpha: 0.5);
    }
  }

  static String _monthShort(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

/// 热力图绘制器
class _HeatmapPainter extends CustomPainter {
  final Map<DateTime, int> data;
  final DateTime firstDay;
  final DateTime endDate;
  final int totalWeeks;

  _HeatmapPainter({
    required this.data,
    required this.firstDay,
    required this.endDate,
    required this.totalWeeks,
  });

  static const double cellSize = 11;
  static const double cellGap = 2;
  static const double weekLabelWidth = 30;

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 绘制星期标签
    const weekLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final textPainter = TextPainter(
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    );

    for (var row = 0; row < 7; row++) {
      final y = row * (cellSize + cellGap);
      textPainter.text = TextSpan(
        text: weekLabels[row],
        style: TextStyle(
          fontSize: 8,
          color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          weekLabelWidth - textPainter.width - 4,
          y + (cellSize - textPainter.height) / 2,
        ),
      );
    }

    // 绘制热力图格子
    var day = firstDay;
    var col = 0;

    while (!day.isAfter(endDate)) {
      final dateKey = DateTime(day.year, day.month, day.day);
      final count = data[dateKey] ?? 0;
      final level = _getLevel(count);
      final isToday = dateKey == today;
      final isFuture = dateKey.isAfter(today);

      final x = weekLabelWidth + col * (cellSize + cellGap);
      final row = day.weekday % 7;
      final y = row * (cellSize + cellGap);

      Color cellColor;
      if (isFuture) {
        cellColor = const Color(0xFF1A1A2E).withValues(alpha: 0.2);
      } else if (count == 0) {
        cellColor = const Color(0xFF1A1A2E).withValues(alpha: 0.5);
      } else {
        cellColor = _getLevelColor(level);
      }

      final paint = Paint()..color = cellColor;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, cellSize, cellSize),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);

      // 绘制今天的边框
      if (isToday) {
        final borderPaint = Paint()
          ..color = const Color(0xFF5B6AFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRRect(rect, borderPaint);
      }

      if (day.weekday == DateTime.saturday || day.isAtSameMomentAs(endDate)) {
        col++;
      }

      day = day.add(const Duration(days: 1));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  int _getLevel(int count) {
    if (count == 0) return 0;
    if (count <= 5) return 1;
    if (count <= 15) return 2;
    if (count <= 30) return 3;
    return 4;
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 0:
        return const Color(0xFF1A1A2E).withValues(alpha: 0.5);
      case 1:
        return const Color(0xFF5B6AFF).withValues(alpha: 0.2);
      case 2:
        return const Color(0xFF5B6AFF).withValues(alpha: 0.4);
      case 3:
        return const Color(0xFF5B6AFF).withValues(alpha: 0.6);
      case 4:
        return const Color(0xFF5B6AFF).withValues(alpha: 0.85);
      default:
        return const Color(0xFF5B6AFF).withValues(alpha: 0.5);
    }
  }
}
