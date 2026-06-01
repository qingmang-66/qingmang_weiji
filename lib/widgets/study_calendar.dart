import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/fluid_theme.dart';
import '../services/providers/theme_provider.dart';
import '../utils/translations.dart';

/// 学习日历 - 流体渐变风格
/// 显示指定月份的学习记录，支持月份和年份选择
class StudyCalendar extends StatefulWidget {
  final Map<DateTime, int> data;

  const StudyCalendar({super.key, required this.data});

  @override
  State<StudyCalendar> createState() => _StudyCalendarState();
}

class _StudyCalendarState extends State<StudyCalendar> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
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
        border: Border.all(
          color: FluidTheme.getBorderColor(isDark),
          width: 1.0,
        ),
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
                  child: Icon(
                    Icons.calendar_month,
                    color: isDark
                        ? Colors.white
                        : FluidTheme.primaryFluidGradient[0],
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr.studyCalendar,
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: textPrimary),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.help_outline, color: textTertiary, size: 20),
                  onPressed: () => _showHelpDialog(context),
                  tooltip: context.tr.viewDescription,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDateSelector(isDark, textPrimary),
            const SizedBox(height: 16),
            _buildWeekdayHeaders(textSecondary),
            const SizedBox(height: 8),
            _buildCalendarGrid(isDark, textPrimary, textTertiary),
            const SizedBox(height: 16),
            _buildFooter(isDark, textPrimary, textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(bool isDark, Color textPrimary) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: FluidTheme.getMutedOverlayColor(isDark),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: _selectedDate.year,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: FluidTheme.getDialogSurfaceColor(isDark),
              items: List.generate(25, (i) => 2026 + i)
                  .map(
                    (year) => DropdownMenuItem(
                      value: year,
                      child: Text(
                        '$year${context.tr.yearSuffix}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (year) {
                if (year != null) {
                  setState(() {
                    _selectedDate = DateTime(year, _selectedDate.month);
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: FluidTheme.getMutedOverlayColor(isDark),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: _selectedDate.month,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: FluidTheme.getDialogSurfaceColor(isDark),
              items: List.generate(12, (i) => i + 1)
                  .map(
                    (month) => DropdownMenuItem(
                      value: month,
                      child: Text(
                        '$month${context.tr.monthSuffix}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (month) {
                if (month != null) {
                  setState(() {
                    _selectedDate = DateTime(_selectedDate.year, month);
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeaders(Color textSecondary) {
    final weekdays = [
      context.tr.seven,
      context.tr.one,
      context.tr.two,
      context.tr.three,
      context.tr.four,
      context.tr.five,
      context.tr.six,
    ];
    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid(
    bool isDark,
    Color textPrimary,
    Color textTertiary,
  ) {
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final firstWeekday = firstDay.weekday % 7;
    final totalCells = (firstWeekday + lastDay.day + 6) ~/ 7 * 7;

    final cells = <Widget>[];
    var currentDate = firstDay.subtract(Duration(days: firstWeekday));

    for (var i = 0; i < totalCells; i++) {
      final isCurrentMonth =
          currentDate.month == month && currentDate.year == year;
      final dateKey = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
      );
      final count = widget.data[dateKey] ?? 0;
      final level = _getLevel(count);
      final isToday = _isToday(currentDate);

      cells.add(
        _buildCalendarCell(
          date: currentDate,
          count: count,
          level: level,
          isCurrentMonth: isCurrentMonth,
          isToday: isToday,
          isDark: isDark,
          textPrimary: textPrimary,
          textTertiary: textTertiary,
        ),
      );
      currentDate = currentDate.add(const Duration(days: 1));
    }

    final rows = <Widget>[];
    for (var row = 0; row < 6; row++) {
      final rowCells = cells.skip(row * 7).take(7).toList();
      rows.add(
        Row(children: rowCells.map((cell) => Expanded(child: cell)).toList()),
      );
      if (row < 5) {
        rows.add(const SizedBox(height: 4));
      }
    }

    return Column(children: rows);
  }

  Widget _buildCalendarCell({
    required DateTime date,
    required int count,
    required int level,
    required bool isCurrentMonth,
    required bool isToday,
    required bool isDark,
    required Color textPrimary,
    required Color textTertiary,
  }) {
    final now = DateTime.now();
    final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));

    Color cellColor;
    if (!isCurrentMonth) {
      cellColor = isDark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.black.withValues(alpha: 0.03);
    } else if (isFuture) {
      cellColor = isDark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.black.withValues(alpha: 0.025);
    } else if (count == 0) {
      cellColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.045);
    } else {
      cellColor = _getLevelColor(level, isDark);
    }

    return Container(
      margin: const EdgeInsets.all(2),
      height: 40,
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: FluidTheme.primaryFluidGradient[0], width: 2)
            : null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isCurrentMonth
                    ? (isToday && isDark ? Colors.white : textPrimary)
                    : textTertiary,
              ),
            ),
            if (count > 0 && isCurrentMonth)
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark, Color textPrimary, Color textSecondary) {
    final monthData = widget.data.entries.where((e) {
      return e.key.year == _selectedDate.year &&
          e.key.month == _selectedDate.month;
    }).toList();

    final studyDays = monthData.where((e) => e.value > 0).length;
    final totalWords = monthData.fold<int>(0, (sum, e) => sum + e.value);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FluidTheme.getMutedOverlayColor(isDark),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context.tr.studyDaysLabel,
            '$studyDays ${context.tr.days}',
            textPrimary,
            textSecondary,
            isDark,
          ),
          Container(
            width: 1,
            height: 20,
            color: FluidTheme.getBorderColor(isDark),
          ),
          _buildStatItem(
            context.tr.studyWordsLabel,
            '$totalWords ${context.tr.dailyUnit}',
            textPrimary,
            textSecondary,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: FluidTheme.labelLarge(isDark).copyWith(color: textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: FluidTheme.bodySmall(isDark).copyWith(color: textSecondary),
        ),
      ],
    );
  }

  int _getLevel(int count) {
    if (count == 0) return 0;
    if (count <= 10) return 1;
    if (count <= 30) return 2;
    if (count <= 50) return 3;
    return 4;
  }

  Color _getLevelColor(int level, bool isDark) {
    switch (level) {
      case 1:
        return FluidTheme.primaryFluidGradient[0].withValues(
          alpha: isDark ? 0.3 : 0.18,
        );
      case 2:
        return FluidTheme.primaryFluidGradient[0].withValues(
          alpha: isDark ? 0.5 : 0.32,
        );
      case 3:
        return FluidTheme.primaryFluidGradient[0].withValues(
          alpha: isDark ? 0.7 : 0.48,
        );
      case 4:
        return FluidTheme.primaryFluidGradient[0].withValues(
          alpha: isDark ? 1.0 : 0.72,
        );
      default:
        return isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.045);
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  void _showHelpDialog(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FluidTheme.getDialogSurfaceColor(isDark),
        title: Text(
          context.tr.calendarGuideTitle,
          style: FluidTheme.headingSmall(isDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr.calendarGuide1,
              style: FluidTheme.bodyMedium(isDark),
            ),
            Text(
              context.tr.calendarGuide2,
              style: FluidTheme.bodyMedium(isDark),
            ),
            Text(
              context.tr.calendarGuide3,
              style: FluidTheme.bodyMedium(isDark),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr.gotIt,
              style: TextStyle(color: FluidTheme.primaryFluidGradient[0]),
            ),
          ),
        ],
      ),
    );
  }
}
