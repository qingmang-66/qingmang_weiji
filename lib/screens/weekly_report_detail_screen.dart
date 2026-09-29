import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/weekly_report.dart';
import '../models/weakness_level.dart';
import '../services/di_container.dart';
import '../services/providers/theme_provider.dart';
import '../services/weekly_report_service.dart';
import '../theme/fluid_theme.dart';
import '../utils/platform_adapt.dart';
import '../utils/platform_info.dart';
import '../utils/file_io.dart'
    if (dart.library.html) '../utils/file_io_web.dart'
    as file_io;
import '../utils/translations.dart';
import '../widgets/daily_details_table.dart';
import '../widgets/fluid_card.dart';

class WeeklyReportDetailScreen extends StatefulWidget {
  final WeeklyReport? initialReport;

  const WeeklyReportDetailScreen({super.key, this.initialReport});

  @override
  State<WeeklyReportDetailScreen> createState() =>
      _WeeklyReportDetailScreenState();
}

class _WeeklyReportDetailScreenState extends State<WeeklyReportDetailScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  late WeeklyReportService _reportService;
  WeeklyReport? _currentReport;
  bool _isLoading = false;
  bool _isExporting = false;
  late DateTime _currentWeekStart;
  //翻周世代号：快速连点上一周/下一周时丢弃乱序返回的旧结果
  int _generation = 0;

  DateTime get _thisWeekStart {
    final now = DateTime.now();
    final dayOnly = DateTime(now.year, now.month, now.day);
    return dayOnly.subtract(Duration(days: dayOnly.weekday - 1));
  }

  bool get _isCurrentWeek {
    final thisWeek = _thisWeekStart;
    return _currentWeekStart.year == thisWeek.year &&
        _currentWeekStart.month == thisWeek.month &&
        _currentWeekStart.day == thisWeek.day;
  }

  @override
  void initState() {
    super.initState();
    _reportService = DIContainer.instance.weeklyReportService;
    if (widget.initialReport != null) {
      _currentReport = widget.initialReport;
      _currentWeekStart = widget.initialReport!.weekStart;
    } else {
      _currentWeekStart = _thisWeekStart;
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    final generation = ++_generation;
    setState(() => _isLoading = true);
    try {
      final report = await _reportService.buildWeekReport(_currentWeekStart);
      if (!mounted || generation != _generation) return;
      setState(() => _currentReport = report);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      _showToast('${context.tr.loadingError}：$e');
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goToPrevWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
    });
    _loadReport();
  }

  void _goToNextWeek() {
    if (_isCurrentWeek) return;
    setState(() {
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
    });
    _loadReport();
  }

  Future<void> _exportReport() async {
    if (_isExporting) return;
    final screenshotFailed = context.tr.screenshotFailed;
    final savedTo = context.tr.savedTo;
    final exportFailed = context.tr.exportFailed;
    final filePrefix = context.tr.weeklyReportFilePrefix;
    final saveFailed = context.tr.saveFailed;
    setState(() => _isExporting = true);
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        _showToast(screenshotFailed);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      // 引擎侧位图（整页 × 2.0，数十 MB 原生内存）必须显式释放：
      // PNG 字节已经复制出来，此时 dispose 不影响导出结果，
      // 但能避免反复导出时内存峰值叠加
      image.dispose();
      if (bytes == null) {
        _showToast(screenshotFailed);
        return;
      }
      final path = await _saveToFile(
        bytes,
        filePrefix: filePrefix,
        saveFailed: saveFailed,
      );
      _showToast('$savedTo$path');
    } catch (e) {
      _showToast('$exportFailed：$e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<String> _saveToFile(
    Uint8List bytes, {
    required String filePrefix,
    required String saveFailed,
  }) async {
    final report = _currentReport;
    if (report == null) return saveFailed;
    final fileName =
        '$filePrefix${report.weekStart.year}'
        '${report.weekStart.month.toString().padLeft(2, '0')}'
        '${report.weekStart.day.toString().padLeft(2, '0')}.png';

    if (kIsWeb) {
      await file_io.downloadBytes(fileName, bytes, mimeType: 'image/png');
      return fileName;
    }

    // 手机端写入缓存后走系统分享，避免用户找不到 Documents 路径
    if (isMobilePlatform) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}${file_io.pathSeparator}$fileName';
      await file_io.writeBytes(path, bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'image/png')],
          subject: fileName,
        ),
      );
      return path;
    }

    String dirPath;
    if (isWindowsPlatform) {
      dirPath =
          file_io.windowsDesktopPath() ??
          (await getApplicationDocumentsDirectory()).path;
    } else if (isMacOSPlatform) {
      dirPath =
          file_io.macDesktopPath() ??
          (await getApplicationDocumentsDirectory()).path;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dirPath = dir.path;
    }
    final path = '$dirPath${file_io.pathSeparator}$fileName';
    await file_io.writeBytes(path, bytes);
    return path;
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return FluidPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            context.tr.weeklyReportDetail,
            style: FluidTheme.headingMedium(
              isDark,
            ).copyWith(color: textPrimary),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.share_outlined, color: textPrimary),
              onPressed: _isExporting ? null : _exportReport,
              tooltip: context.tr.exportReport,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildWeekNavigator(context, isDark, textPrimary, textSecondary),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_currentReport == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Text(
                    context.tr.noData,
                    style: TextStyle(color: textSecondary),
                  ),
                ),
              )
            else
              RepaintBoundary(
                key: _repaintKey,
                child: Container(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildDailyDetailsCard(
                        context,
                        isDark,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 12),
                      _buildTopWeakWordsCard(
                        context,
                        isDark,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 12),
                      _buildFrequentWrongWordsCard(
                        context,
                        isDark,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekNavigator(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final weekEnd = _currentWeekStart.add(const Duration(days: 6));
    final dateRange =
        '${_currentWeekStart.month}/${_currentWeekStart.day} - ${weekEnd.month}/${weekEnd.day}';
    final label = _isCurrentWeek
        ? '${context.tr.thisWeekLabel}（$dateRange）'
        : '${_currentWeekStart.year}/${_currentWeekStart.month}/${_currentWeekStart.day} - ${weekEnd.month}/${weekEnd.day}';

    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: textPrimary),
          onPressed: _isLoading ? null : _goToPrevWeek,
          tooltip: context.tr.prevWeekTooltip,
        ),
        Expanded(
          child: Center(
            child: Text(
              label,
              style: FluidTheme.labelLarge(isDark).copyWith(color: textPrimary),
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.chevron_right,
            color: _isCurrentWeek
                ? textSecondary.withValues(alpha: 0.3)
                : textPrimary,
          ),
          onPressed: (_isLoading || _isCurrentWeek) ? null : _goToNextWeek,
          tooltip: context.tr.nextWeekTooltip,
        ),
      ],
    );
  }

  Widget _buildDailyDetailsCard(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final report = _currentReport!;
    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluidCardTitle(
            text: context.tr.dailyDetailsTitle,
            icon: Icons.bar_chart_outlined,
            gradientColors: FluidTheme.primaryFluidGradient,
          ),
          const SizedBox(height: 12),
          DailyDetailsTable(details: report.dailyDetails),
        ],
      ),
    );
  }

  Widget _buildTopWeakWordsCard(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final report = _currentReport!;
    final words = report.topWeakWords;
    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluidCardTitle(
            text: context.tr.topWeakWords,
            icon: Icons.error_outline,
            gradientColors: FluidTheme.errorFluidGradient,
          ),
          const SizedBox(height: 12),
          if (words.isEmpty)
            Text(
              context.tr.noWeakWordsDesc,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textSecondary),
            )
          else
            ...words.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _weaknessColor(item.level),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.word,
                            style: FluidTheme.labelMedium(
                              isDark,
                            ).copyWith(color: textPrimary),
                          ),
                          if (item.definition.isNotEmpty)
                            Text(
                              item.definition,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FluidTheme.bodySmall(
                                isDark,
                              ).copyWith(color: textSecondary),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item.weaknessScore.toStringAsFixed(1),
                          style: FluidTheme.labelMedium(
                            isDark,
                          ).copyWith(color: _weaknessColor(item.level)),
                        ),
                        Text(
                          _weaknessLabel(item.level, context),
                          style: FluidTheme.bodySmall(
                            isDark,
                          ).copyWith(color: textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFrequentWrongWordsCard(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final report = _currentReport!;
    final words = report.frequentWrongWords;
    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluidCardTitle(
            text: context.tr.frequentWrongWords,
            icon: Icons.priority_high_outlined,
            gradientColors: FluidTheme.warningFluidGradient,
          ),
          const SizedBox(height: 12),
          if (words.isEmpty)
            Text(
              context.tr.noFrequentWrongWords,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textSecondary),
            )
          else
            ...words.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: FluidTheme.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.wrongCount}',
                        style: FluidTheme.labelMedium(
                          isDark,
                        ).copyWith(color: FluidTheme.error),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.word,
                            style: FluidTheme.labelMedium(
                              isDark,
                            ).copyWith(color: textPrimary),
                          ),
                          if (item.definition.isNotEmpty)
                            Text(
                              item.definition,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FluidTheme.bodySmall(
                                isDark,
                              ).copyWith(color: textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _weaknessColor(WeaknessLevel level) {
    return level.color;
  }

  String _weaknessLabel(WeaknessLevel level, BuildContext context) {
    switch (level) {
      case WeaknessLevel.critical:
        return context.tr.criticalWeak;
      case WeaknessLevel.weak:
        return context.tr.weakLevelWeak;
      case WeaknessLevel.shaky:
        return context.tr.shakyWeak;
      case WeaknessLevel.normal:
        return context.tr.normalWeak;
      case WeaknessLevel.solid:
        return context.tr.solidWeak;
    }
  }
}
