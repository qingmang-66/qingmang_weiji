import 'package:flutter/material.dart';

/// 学习日历热力图 — GitHub 风格贡献日历
/// 展示过去一年（53周 × 7天）的学习记录
class StudyHeatmap extends StatelessWidget {
  /// 日期 -> 学习数量的映射
  final Map<DateTime, int> data;
  final ColorScheme colorScheme;

  const StudyHeatmap({
    super.key,
    required this.data,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(Icons.calendar_month, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  _t('学习日历', 'Study Calendar'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _t('过去一年的学习记录', 'Study record of the past year'),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

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
    // 从53周前的周日开始
    final endDate = DateTime(now.year, now.month, now.day);
    final startDate = endDate.subtract(const Duration(days: 53 * 7 - 1));
    // 对齐到周日
    final firstDay = startDate.subtract(Duration(days: startDate.weekday % 7));

    // 月份标签
    final monthLabels = <String>[];
    var monthCheck = DateTime(firstDay.year, firstDay.month, 1);
    while (monthCheck.isBefore(endDate.add(const Duration(days: 7)))) {
      monthLabels.add(_monthShort(monthCheck.month));
      if (monthCheck.month == 12) {
        monthCheck = DateTime(monthCheck.year + 1, 1, 1);
      } else {
        monthCheck = DateTime(monthCheck.year, monthCheck.month + 1, 1);
      }
    }

    // 计算月份标签位置（第几列）
    final monthPositions = <String, int>{};
    var col = 0;
    var currentMonth = -1;
    for (var d = firstDay; !d.isAfter(endDate); d = d.add(const Duration(days: 1))) {
      if (d.month != currentMonth) {
        currentMonth = d.month;
        monthPositions[_monthShort(currentMonth)] = col;
      }
      col++;
    }
    // 转换为列索引（每周一列）
    final monthColumnPositions = <String, double>{};
    monthPositions.forEach((month, dayIndex) {
      monthColumnPositions[month] = dayIndex / 7.0;
    });

    // 周标签
    const weekLabels = ['', 'Mon', '', 'Wed', '', 'Fri', ''];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧星期标签
        Column(
          children: List.generate(7, (i) {
            return SizedBox(
              height: 14,
              child: weekLabels[i].isNotEmpty
                  ? Text(
                      weekLabels[i],
                      style: TextStyle(
                        fontSize: 8,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    )
                  : null,
            );
          }),
        ),
        const SizedBox(width: 4),

        // 热力图主体
        Expanded(
          child: Column(
            children: [
              // 月份标签行
              SizedBox(
                height: 14,
                child: Stack(
                  children: monthColumnPositions.entries.map((e) {
                    return Positioned(
                      left: e.value * _cellSize,
                      child: Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 9,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 2),

              // 格子
              _buildCells(firstDay, endDate),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCells(DateTime firstDay, DateTime endDate) {
    final rows = <Widget>[];
    var currentWeek = <Widget>[];
    var day = firstDay;

    // 第一周可能不完整（从周日开始）
    while (!day.isAfter(endDate)) {
      final dateKey = DateTime(day.year, day.month, day.day);
      final count = data[dateKey] ?? 0;
      final level = _getLevel(count);

      currentWeek.add(_buildCell(day, count, level));

      if (day.weekday == DateTime.saturday || day.isAtSameMomentAs(endDate)) {
        // 补齐最后一周
        while (currentWeek.length < 7) {
          currentWeek.add(const SizedBox(width: _cellSize, height: _cellSize));
        }
        rows.add(Row(children: List.from(currentWeek)));
        rows.add(const SizedBox(height: _cellGap));
        currentWeek = [];
      }

      day = day.add(const Duration(days: 1));
    }

    return Column(children: rows);
  }

  Widget _buildCell(DateTime day, int count, int level) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateKey = DateTime(day.year, day.month, day.day);
    final isToday = dateKey == today;
    final isFuture = dateKey.isAfter(today);

    Color cellColor;
    if (isFuture) {
      cellColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.2);
    } else if (count == 0) {
      cellColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    } else {
      cellColor = _getLevelColor(level);
    }

    return Tooltip(
      message: '${day.month}/${day.day}: $count ${_t('词', 'words')}',
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        width: _cellSize,
        height: _cellSize,
        margin: const EdgeInsets.only(right: _cellGap, bottom: _cellGap),
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(3),
          border: isToday
              ? Border.all(color: colorScheme.primary, width: 1.5)
              : null,
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final activeDays = data.values.where((c) => c > 0).length;
    final totalWords = data.values.fold(0, (sum, c) => sum + c);
    final maxDay = data.values.isEmpty ? 0 : data.values.reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        // 统计信息
        Expanded(
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _buildStatChip(Icons.local_fire_department, _t('活跃天数', 'Active'), '$activeDays'),
              _buildStatChip(Icons.functions, _t('总词数', 'Words'), '$totalWords'),
              if (maxDay > 0)
                _buildStatChip(Icons.emoji_events, _t('单日最高', 'Best Day'), '$maxDay'),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // 图例
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _t('少', 'Less'),
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
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
              _t('多', 'More'),
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
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
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ========== 工具方法 ==========

  static const double _cellSize = 11;
  static const double _cellGap = 2;

  /// 根据学习数量计算强度等级 (0-4)
  int _getLevel(int count) {
    if (count == 0) return 0;
    if (count <= 5) return 1;
    if (count <= 15) return 2;
    if (count <= 30) return 3;
    return 4;
  }

  /// 获取等级对应的颜色
  Color _getLevelColor(int level) {
    final primary = colorScheme.primary;
    switch (level) {
      case 0:
        return colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
      case 1:
        return primary.withValues(alpha: 0.2);
      case 2:
        return primary.withValues(alpha: 0.4);
      case 3:
        return primary.withValues(alpha: 0.6);
      case 4:
        return primary.withValues(alpha: 0.85);
      default:
        return primary.withValues(alpha: 0.5);
    }
  }

  static String _monthShort(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _t(String zh, String en) {
    return zh; // 简化处理，实际应从 AppProvider 获取语言设置
  }
}
