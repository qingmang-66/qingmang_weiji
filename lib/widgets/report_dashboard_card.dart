import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/daily_study_detail.dart';
import '../services/di_container.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_card.dart';
import 'fluid_dialog.dart';
import '../widgets/liquid_controls.dart';
import '../widgets/liquid_glass.dart';

/// 学习报告板块 - 日/周/月切换 + 周期下拉选择 + 指标卡 + 双线趋势图
///
/// 已合并原学习日历的按时间回看能力：日视图选年月日、周视图选周、
/// 月视图选年月，明细通过 [WeeklyReportService.buildRangeDetails] 按需查询。
class ReportDashboardCard extends StatefulWidget {
  /// 外部刷新信号：变化时重新查询当前选中周期
  final int reloadToken;

  const ReportDashboardCard({super.key, this.reloadToken = 0});

  @override
  State<ReportDashboardCard> createState() => _ReportDashboardCardState();
}

class _ReportDashboardCardState extends State<ReportDashboardCard> {
  int _period = 0; // 0=周 1=月 2=年
  late DateTime _weekAnchor; // 周视图：选中周内任意一天
  late DateTime _monthDate; // 月视图选中月份（取月初）
  late int _year; // 年视图选中年份
  List<DailyStudyDetail> _details = const [];
  bool _loading = false;
  int _generation = 0;
  int _chartType = 0; // 0=折线 1=条形

  /// 内容区保底高度：指标卡行 + 间距 + 图例 + 图表，与数据态实际高度对齐，
  /// 使加载/空/数据三态切换时卡片总高不变
  static const double _minBodyHeight = 318;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _weekAnchor = _today;
    _monthDate = DateTime(_today.year, _today.month);
    _year = _today.year;
    _load();
  }

  @override
  void didUpdateWidget(ReportDashboardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) _load();
  }

  /// 当前视图的锚点日期（滚轮初始定位用）
  DateTime get _anchorDate {
    switch (_period) {
      case 0:
        return _weekAnchor;
      case 1:
        return _monthDate;
      default:
        return DateTime(_year, 1, 1);
    }
  }

  /// 当前选中周期的查询区间 [start, end)
  ({DateTime start, DateTime end}) get _range {
    switch (_period) {
      case 0:
        final monday = _mondayOf(_weekAnchor);
        return (start: monday, end: monday.add(const Duration(days: 7)));
      case 1:
        return (
          start: _monthDate,
          end: DateTime(_monthDate.year, _monthDate.month + 1),
        );
      default:
        return (start: DateTime(_year), end: DateTime(_year + 1));
    }
  }

  DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  Future<void> _load() async {
    final generation = ++_generation;
    final range = _range;
    setState(() => _loading = true);
    try {
      final details = await DIContainer.instance.weeklyReportService
          .buildRangeDetails(start: range.start, end: range.end);
      if (!mounted || generation != _generation) return;
      setState(() {
        _details = details;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      debugPrint('学习报告加载失败: $e');
      setState(() {
        _details = const [];
        _loading = false;
      });
    }
  }

  void _selectPeriod(int period) {
    if (_period == period) return;
    setState(() => _period = period);
    _load();
  }

  /// 右上角周期文案：与下拉按钮共用同一份文案
  ///
  /// 直接从选中锚点推算，不依赖异步返回的 [_details]，
  /// 否则切换周期的一瞬间会残留上一周期的日期区间文案。
  String get _periodLabel => _selectorLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    //年视图按自然月聚合：逐日 365 个点既画不下、等距采样又会漏掉"没学的那几天"
    final details = _period == 2 ? _aggregateByMonth(_details) : _details;
    final newWords = details.fold<int>(0, (s, d) => s + d.newWords);
    final practiced = details.fold<int>(0, (s, d) => s + d.practicedWords);
    final remembered = details.fold<int>(0, (s, d) => s + d.rememberedWords);
    final attempts = details.fold<int>(0, (s, d) => s + d.attempts);
    final wrong = details.fold<int>(0, (s, d) => s + d.wrongCount);
    final accPercent = attempts <= 0
        ? 0
        : ((attempts - wrong) / attempts * 100).round();

    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FluidCardTitle(
                text: context.tr.studyReport,
                icon: Icons.insights_outlined,
                gradientColors: FluidTheme.primaryFluidGradient,
              ),
              const Spacer(),
              Text(
                _periodLabel,
                style: FluidTheme.bodySmall(
                  isDark,
                ).copyWith(color: textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPeriodSwitcher(),
          const SizedBox(height: 10),
          _buildPeriodSelector(isDark, textPrimary),
          const SizedBox(height: 16),
          //内容区保底高度：加载/空态/数据三态高度一致，切换周期时卡片
          //不再发生高度跳变。Windows 桌面端整页重布局会让同屏实时模糊的
          //玻璃卡重新采样合成，正是"切换年月屏幕概率性闪烁"的来源。
          //只保底不锁死：系统字体缩放大时内容可自然撑高，不会溢出
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _minBodyHeight),
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: FluidTheme.primaryFluidGradient[0],
                      ),
                    ),
                  )
                : details.isEmpty
                ? Center(child: _buildEmpty(isDark, textSecondary))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStatCards(
                        isDark,
                        newWords,
                        practiced,
                        remembered,
                        accPercent,
                      ),
                      const SizedBox(height: 16),
                      _buildTrendChart(isDark, textSecondary, details),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSwitcher() {
    //液态玻璃模式为水滴滑块分段控件，经典模式自动回退 SegmentedButton
    return LiquidSegmented<int>(
      value: _period,
      segments: [
        LiquidSegment(value: 0, label: context.tr.reportWeek),
        LiquidSegment(value: 1, label: context.tr.reportMonth),
        LiquidSegment(value: 2, label: context.tr.reportYear),
      ],
      onChanged: _selectPeriod,
    );
  }

  /// 周期选择入口：胶囊按钮，点击弹出滚轮选择器
  Widget _buildPeriodSelector(bool isDark, Color textPrimary) {
    final accent = FluidTheme.primaryFluidGradient[0];
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.calendar_today_outlined, size: 14, color: accent),
        const SizedBox(width: 8),
        Text(
          _selectorLabel,
          style: FluidTheme.bodyMedium(
            isDark,
          ).copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: textPrimary),
      ],
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: _showPeriodPicker,
        behavior: HitTestBehavior.opaque,
        //玻璃模式用半透明白色胶囊，经典模式保留原描边胶囊
        child: context.isLiquidGlass
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x00ffffff).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0x00ffffff).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: content,
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: content,
              ),
      ),
    );
  }

  String get _selectorLabel {
    switch (_period) {
      case 0:
        return _weekRangeLabel(_weekAnchor);
      case 1:
        // 语言感知拼接：英文 "Mar 2026"，中文 "2026年3月"
        // （此前用 suffix 直接拼，英文会得到 "20263"）
        return context.tr.formatYearMonth(_monthDate.year, _monthDate.month);
      default:
        return context.tr.formatYear(_year);
    }
  }

  /// 选中日期所在周的区间文案，如 2026/8/24 - 8/30
  String _weekRangeLabel(DateTime anchor) {
    final monday = _mondayOf(anchor);
    final sunday = monday.add(const Duration(days: 6));
    if (monday.year == _today.year && sunday.year == _today.year) {
      return '${monday.month}/${monday.day} - ${sunday.month}/${sunday.day}';
    }
    final sameYear = monday.year == sunday.year;
    if (sameYear) {
      return '${monday.year}/${monday.month}/${monday.day} - ${sunday.month}/${sunday.day}';
    }
    return '${monday.year}/${monday.month}/${monday.day} - ${sunday.year}/${sunday.month}/${sunday.day}';
  }

  /// 年份范围：往前 5 年到 2050 年。
  ///
  /// 往后开放到 2050 是为了让用户能回看/预置长期计划（年份只是滚轮里的一个
  /// int，不占存储也不参与任何后台计算，多几年几乎零成本）。
  static const int _maxYear = 2050;
  List<int> get _yearOptions {
    final first = _today.year - 5;
    final last = _maxYear < _today.year ? _today.year : _maxYear;
    return List.generate(last - first + 1, (i) => first + i);
  }

  /// 指定月份覆盖到的所有周（每周以周一为起点，首尾周可跨到相邻月份）
  List<DateTime> _weekStartsOfMonth(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0);
    final weeks = <DateTime>[];
    var start = _mondayOf(DateTime(year, month, 1));
    while (!start.isAfter(lastDay)) {
      weeks.add(start);
      start = start.add(const Duration(days: 7));
    }
    return weeks;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 滚轮式周期选择弹窗，风格与流体渐变主题一致
  ///
  /// - 周视图：年/月/周（一周一个选项，按 7 天步进，不会选到具体某天）
  /// - 月视图：年/月
  /// - 年视图：只选年份
  void _showPeriodPicker() {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final years = _yearOptions;
    final anchor = _anchorDate;
    var year = anchor.year.clamp(years.first, years.last);
    var month = anchor.month;
    //周视图的选择单位是"周一"
    var weekStart = _mondayOf(anchor);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(
        alpha: context.isLiquidGlass ? 0.25 : 0.5,
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final weekStarts = _weekStartsOfMonth(year, month);
          var weekIndex = weekStarts.indexWhere(
            (d) => _isSameDay(d, weekStart),
          );
          if (weekIndex < 0) {
            //切换年月后原选中周不在范围内，退回本月第一周
            weekIndex = 0;
            weekStart = weekStarts.first;
          }

          void apply() {
            setState(() {
              switch (_period) {
                case 0:
                  _weekAnchor = weekStart;
                case 1:
                  _monthDate = DateTime(year, month);
                default:
                  _year = year;
              }
            });
            _load();
            Navigator.of(ctx).pop();
          }

          //液态玻璃模式为水滴滚轮（自带滚动控制器），经典模式内部回退 CupertinoPicker
          //autofocus 让打开弹窗后可直接用上下键调节首列、左右键切换列；
          //这是纯键盘便利，移动端没有物理键盘，不聚焦（也会抢走弹窗回车确认的焦点）
          Widget wheelPicker<T>({
            required int initialItem,
            required List<T> items,
            required String Function(T) label,
            required ValueChanged<int> onChanged,
            Key? wheelKey,
            bool autofocus = false,
          }) {
            return Expanded(
              child: LiquidWheelPicker(
                key: wheelKey,
                itemCount: items.length,
                initialItem: initialItem,
                itemExtent: 40,
                height: 220,
                autofocus: autofocus,
                onSelectedItemChanged: onChanged,
                itemBuilder: (context, i) => Text(
                  label(items[i]),
                  style: TextStyle(
                    fontSize: 16, //加大字号提升玻璃背景上可读性
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
            );
          }

          Widget columnHeader(String text) => Expanded(
            child: Center(
              child: Text(
                text,
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
            ),
          );

          final yearWheel = wheelPicker<int>(
            initialItem: years.indexOf(year),
            items: years,
            label: context.tr.formatYear,
            autofocus: PlatformAdapt.isDesktop,
            onChanged: (i) => setDialogState(() => year = years[i]),
          );
          final monthWheel = wheelPicker<int>(
            initialItem: month - 1,
            items: List.generate(12, (i) => i + 1),
            label: context.tr.formatMonth,
            onChanged: (i) => setDialogState(() => month = i + 1),
          );

          //周列长度随年月变化，用 key 强制重建以刷新滚轮与选中项
          final weekWheel = wheelPicker<DateTime>(
            wheelKey: ValueKey('week-$year-$month'),
            initialItem: weekIndex,
            items: weekStarts,
            label: (d) => '${d.month}/${d.day}',
            onChanged: (i) => setDialogState(() => weekStart = weekStarts[i]),
          );

          final Row picker;
          final Row pickerHeader;
          if (_period == 2) {
            //年视图只需要年份
            picker = Row(children: [yearWheel]);
            pickerHeader = Row(children: [columnHeader(context.tr.yearLabel)]);
          } else if (_period == 1) {
            picker = Row(children: [yearWheel, monthWheel]);
            pickerHeader = Row(
              children: [
                columnHeader(context.tr.yearLabel),
                columnHeader(context.tr.monthLabel),
              ],
            );
          } else {
            //周视图按整周（7天）选择，避免选到具体某一天
            picker = Row(children: [yearWheel, monthWheel, weekWheel]);
            pickerHeader = Row(
              children: [
                columnHeader(context.tr.yearLabel),
                columnHeader(context.tr.monthLabel),
                columnHeader(context.tr.reportWeek),
              ],
            );
          }

          final dialogChild = Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: FluidTheme.primaryFluidGradient,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr.reportSelectPeriod,
                      style: FluidTheme.headingSmall(
                        isDark,
                      ).copyWith(color: textPrimary),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: FluidTheme.getTextSecondaryColor(isDark),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                //列头说明当前每列的单位（年/月/日 或 年/月/周）
                pickerHeader,
                SizedBox(height: 220, child: picker),
                const SizedBox(height: 16),
                //双风格流体按钮：玻璃模式为果冻胶囊，经典模式为渐变实心
                FluidButton(
                  text: context.tr.confirm,
                  onPressed: apply,
                  expanded: true,
                  height: 44,
                  fontSize: 15,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  colors: FluidTheme.primaryFluidGradient,
                ),
              ],
            ),
          );
          return FluidDialog(
            content: dialogChild,
            barrierDismissible: true,
            // 回车键等同于「确定」
            onConfirm: apply,
          );
        },
      ),
    );
  }

  Widget _buildStatCards(
    bool isDark,
    int newWords,
    int practiced,
    int remembered,
    int accPercent,
  ) {
    final items = [
      (
        '$newWords',
        context.tr.reportNewWords,
        FluidTheme.primaryFluidGradient[0],
      ),
      (
        '$practiced',
        context.tr.reportPracticed,
        FluidTheme.secondaryFluidGradient[0],
      ),
      ('$remembered', context.tr.reportRemembered, FluidTheme.success),
      ('$accPercent%', context.tr.reportAccuracy, FluidTheme.warning),
    ];
    return Row(
      children: items
          .map((it) => Expanded(child: _statCard(isDark, it.$1, it.$2, it.$3)))
          .toList(),
    );
  }

  Widget _statCard(bool isDark, String value, String label, Color accent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x00ffffff).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0x00ffffff).withValues(alpha: 0.5),
          width: 1,
        ),
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
    );
  }

  Widget _buildTrendChart(
    bool isDark,
    Color textSecondary,
    List<DailyStudyDetail> details,
  ) {
    final practicedColor = FluidTheme.primaryFluidGradient[0];
    final rememberedColor = FluidTheme.secondaryFluidGradient[0];
    // 过滤尾部无活动日期（如本月未来天/本周剩余天），避免X轴挤满空白标签
    final trimmed = _trimTrailingZeros(details);
    if (trimmed.isEmpty) {
      //空态高度收紧：固定 120 会让卡片中间出现一大块死白
      return SizedBox(
        height: 72,
        child: Center(
          child: Text(
            context.tr.reportNoData,
            style: FluidTheme.bodySmall(isDark).copyWith(color: textSecondary),
          ),
        ),
      );
    }
    // 点数过多时等距采样，保证X轴标签不重叠
    final sampled = _sampleForDisplay(trimmed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 图例 + 切换按钮在窄屏/大字体下总宽会超出卡片，溢出部分被 ClipRRect 裁掉。
        // 图例允许收缩并省略，切换按钮（操作入口）保持完整
        Row(
          children: [
            Flexible(
              child: _legend(
                isDark,
                practicedColor,
                context.tr.reportPracticedSeries,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _legend(
                isDark,
                rememberedColor,
                context.tr.reportRememberedSeries,
              ),
            ),
            const SizedBox(width: 8),
            _buildChartToggle(isDark),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: _chartType == 0
              ? _buildLineChart(
                  isDark,
                  textSecondary,
                  sampled,
                  practicedColor,
                  rememberedColor,
                )
              : _buildBarChart(
                  isDark,
                  textSecondary,
                  sampled,
                  practicedColor,
                  rememberedColor,
                ),
        ),
      ],
    );
  }

  /// 折线/条形图切换按钮（图标+文字，保证可见性）
  Widget _buildChartToggle(bool isDark) {
    final accent = FluidTheme.primaryFluidGradient[0];
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    Widget btn(int type, IconData icon, String label) {
      final selected = _chartType == type;
      final color = selected ? accent : textSecondary;
      return GestureDetector(
        onTap: () {
          if (!selected) setState(() => _chartType = type);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.25 : 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: FluidTheme.getMutedOverlayColor(isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FluidTheme.getBorderColor(isDark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(0, Icons.show_chart_rounded, context.tr.reportChartLine),
          btn(1, Icons.bar_chart_rounded, context.tr.reportChartBar),
        ],
      ),
    );
  }

  FlGridData _chartGrid(bool isDark) => FlGridData(
    show: true,
    drawVerticalLine: false,
    getDrawingHorizontalLine: (v) =>
        FlLine(color: FluidTheme.getBorderColor(isDark), strokeWidth: 1),
  );

  /// 共用坐标轴：左侧数值 + 底部日期标签
  FlTitlesData _chartTitles(
    bool isDark,
    Color textSecondary,
    List<DailyStudyDetail> sampled,
  ) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          getTitlesWidget: (v, meta) => Text(
            v.toInt().toString(),
            style: TextStyle(fontSize: 10, color: textSecondary),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (v, meta) {
            // fl_chart 会对非整数 x 值调用，只渲染整数位置防止标签重复
            if ((v - v.round()).abs() > 0.01) return const SizedBox.shrink();
            final i = v.round();
            if (i < 0 || i >= sampled.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _xLabel(sampled[i].date),
                style: TextStyle(fontSize: 9, color: textSecondary),
              ),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _buildLineChart(
    bool isDark,
    Color textSecondary,
    List<DailyStudyDetail> sampled,
    Color practicedColor,
    Color rememberedColor,
  ) {
    final maxX = sampled.length > 1 ? (sampled.length - 1).toDouble() : 1.0;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: 0,
        gridData: _chartGrid(isDark),
        titlesData: _chartTitles(isDark, textSecondary, sampled),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          _lineBar(
            sampled,
            practicedColor,
            (d) => d.practicedWords.toDouble(),
            isDark,
          ),
          _lineBar(
            sampled,
            rememberedColor,
            (d) => d.rememberedWords.toDouble(),
            isDark,
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => FluidTheme.getDialogSurfaceColor(isDark),
            tooltipRoundedRadius: 12,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final i = spot.x.round();
                if (i < 0 || i >= sampled.length) return null;
                final d = sampled[i];
                return LineTooltipItem(
                  '${_pointLabel(d.date)}\n'
                  '${context.tr.reportPracticed} ${d.practicedWords}\n'
                  '${context.tr.reportRemembered} ${d.rememberedWords}',
                  TextStyle(
                    color: FluidTheme.getTextPrimaryColor(isDark),
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(
    bool isDark,
    Color textSecondary,
    List<DailyStudyDetail> sampled,
    Color practicedColor,
    Color rememberedColor,
  ) {
    final rodWidth = sampled.length > 14 ? 4.0 : 7.0;
    return BarChart(
      BarChartData(
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        gridData: _chartGrid(isDark),
        titlesData: _chartTitles(isDark, textSecondary, sampled),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => FluidTheme.getDialogSurfaceColor(isDark),
            tooltipRoundedRadius: 12,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final d = sampled[group.x];
              final label = rodIndex == 0
                  ? context.tr.reportPracticed
                  : context.tr.reportRemembered;
              return BarTooltipItem(
                '${_pointLabel(d.date)}\n$label ${rod.toY.toInt()}',
                TextStyle(
                  color: FluidTheme.getTextPrimaryColor(isDark),
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < sampled.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: sampled[i].practicedWords.toDouble(),
                  color: practicedColor,
                  width: rodWidth,
                  borderRadius: BorderRadius.circular(3),
                ),
                BarChartRodData(
                  toY: sampled[i].rememberedWords.toDouble(),
                  color: rememberedColor,
                  width: rodWidth,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 年视图：把逐日明细按自然月求和，得到 12 个点（1 月 ~ 12 月）
  ///
  /// 直接画 365 个点会挤成一团，等距采样到 7 个点又会把"某几天集中学习"
  /// 这种真实形态抹平，所以按自然月聚合：图表读作"每月练了多少 / 记住多少"。
  List<DailyStudyDetail> _aggregateByMonth(List<DailyStudyDetail> details) {
    final buckets = <int, List<DailyStudyDetail>>{};
    for (final d in details) {
      buckets.putIfAbsent(d.date.month, () => <DailyStudyDetail>[]).add(d);
    }
    int sum(int month, int Function(DailyStudyDetail) pick) {
      final items = buckets[month];
      if (items == null) return 0;
      var total = 0;
      for (final d in items) {
        total += pick(d);
      }
      return total;
    }

    return List.generate(12, (i) {
      final month = i + 1;
      return DailyStudyDetail(
        date: DateTime(_year, month),
        newWords: sum(month, (d) => d.newWords),
        practicedWords: sum(month, (d) => d.practicedWords),
        rememberedWords: sum(month, (d) => d.rememberedWords),
        wrongWords: sum(month, (d) => d.wrongWords),
        attempts: sum(month, (d) => d.attempts),
        wrongCount: sum(month, (d) => d.wrongCount),
      );
    });
  }

  /// 图表点的短标签：年视图的点代表一整月，只显示月份
  String _pointLabel(DateTime date) => _period == 2
      ? context.tr.formatMonth(date.month)
      : '${date.month}/${date.day}';

  /// 去除尾部全零明细（未来日期/未学习天）
  List<DailyStudyDetail> _trimTrailingZeros(List<DailyStudyDetail> list) {
    int end = list.length;
    while (end > 0 && !list[end - 1].hasActivity) {
      end--;
    }
    return list.sublist(0, end);
  }

  /// 超过14天时等距采样到7个点，保证X轴可读
  List<DailyStudyDetail> _sampleForDisplay(List<DailyStudyDetail> list) {
    if (list.length <= 14) return list;
    const maxPoints = 7;
    final result = <DailyStudyDetail>[list.first];
    final step = (list.length - 1) / (maxPoints - 1);
    for (var j = 1; j < maxPoints - 1; j++) {
      result.add(list[(j * step).round()]);
    }
    result.add(list.last);
    return result;
  }

  LineChartBarData _lineBar(
    List<DailyStudyDetail> details,
    Color color,
    double Function(DailyStudyDetail) value,
    bool isDark,
  ) {
    final spots = <FlSpot>[
      for (var i = 0; i < details.length; i++)
        FlSpot(i.toDouble(), value(details[i])),
    ];
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: isDark ? 0.25 : 0.18),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }

  Widget _legend(bool isDark, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        //可收缩：空间不足时省略，而不是溢出后被卡片裁掉半截文字
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FluidTheme.bodySmall(
              isDark,
            ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
          ),
        ),
      ],
    );
  }

  String _xLabel(DateTime date) {
    //周视图正好是周一到周日 7 个点，标星期几最好认
    if (_period == 0) {
      const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      return '周${weekdays[date.weekday - 1]}';
    }
    return _pointLabel(date);
  }

  Widget _buildEmpty(bool isDark, Color textSecondary) {
    return Container(
      height: 72,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: textSecondary),
          const SizedBox(height: 8),
          Text(
            context.tr.reportNoData,
            style: FluidTheme.bodySmall(isDark).copyWith(color: textSecondary),
          ),
        ],
      ),
    );
  }
}
