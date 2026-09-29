import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import '../widgets/fluid_card.dart';

/// 阅读模式统计卡：统计阅读中"记住了"的勾记数量
/// 与学习报告（学习模式）分开，各自一张卡
class ReaderStatsCard extends StatefulWidget {
  /// 外部刷新信号：变化时重新查询
  final int reloadToken;

  const ReaderStatsCard({super.key, this.reloadToken = 0});

  @override
  State<ReaderStatsCard> createState() => _ReaderStatsCardState();
}

class _ReaderStatsCardState extends State<ReaderStatsCard> {
  int _total = 0;
  int _today = 0;
  int _week = 0;
  int _month = 0;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ReaderStatsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      //周一为一周起点
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final monthStart = DateTime(now.year, now.month);
      final dao = DatabaseService.readerDao;
      //今日/本周/本月三次区间查询并行
      final results = await Future.wait([
        dao.getMarkCounts(
          start: today,
          end: today.add(const Duration(days: 1)),
        ),
        dao.getMarkCounts(
          start: monday,
          end: monday.add(const Duration(days: 7)),
        ),
        dao.getMarkCounts(
          start: monthStart,
          end: DateTime(monthStart.year, monthStart.month + 1),
        ),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _total = results[0].total;
        _today = results[0].range;
        _week = results[1].range;
        _month = results[2].range;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      debugPrint('阅读统计加载失败: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final tr = context.tr;
    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluidCardTitle(
            text: tr.readerStatsTitle,
            icon: Icons.menu_book_outlined,
            gradientColors: FluidTheme.secondaryFluidGradient,
          ),
          const SizedBox(height: 4),
          Text(
            tr.readerStatsDesc,
            style: FluidTheme.bodySmall(isDark).copyWith(color: textSecondary),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const SizedBox(
              height: 64,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else
            Row(
              children: [
                _stat(
                  isDark,
                  '$_total',
                  tr.readerStatsTotal,
                  FluidTheme.secondaryFluidGradient[0],
                ),
                _stat(
                  isDark,
                  '$_today',
                  tr.readerStatsToday,
                  FluidTheme.primaryFluidGradient[0],
                ),
                _stat(isDark, '$_week', tr.readerStatsWeek, FluidTheme.success),
                _stat(
                  isDark,
                  '$_month',
                  tr.readerStatsMonth,
                  FluidTheme.warning,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _stat(bool isDark, String value, String label, Color accent) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: FluidTheme.getMutedOverlayColor(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: FluidTheme.labelLarge(isDark).copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
            ),
          ],
        ),
      ),
    );
  }
}
