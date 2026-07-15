import 'package:flutter/foundation.dart';

import '../../models/weekly_report.dart';
import '../weekly_report_service.dart';

/// 每周学习报告仓储层
///
/// 封装 [WeeklyReportService] 的调用，捕获异常并兜底返回空数据，
/// 确保 UI 层永远不面对数据库异常。
class WeeklyReportRepository {
  final WeeklyReportService _service;

  WeeklyReportRepository(this._service);

  /// 加载本周报告（带缓存）
  Future<WeeklyReport> loadCurrentWeek({bool forceRefresh = false}) async {
    try {
      return await _service.buildCurrentWeekReport(forceRefresh: forceRefresh);
    } catch (e) {
      debugPrint('WeeklyReportRepository.loadCurrentWeek error: $e');
      return WeeklyReport.empty();
    }
  }

  /// 加载上周报告
  Future<WeeklyReport> loadLastWeek() async {
    try {
      return await _service.buildLastWeekReport();
    } catch (e) {
      debugPrint('WeeklyReportRepository.loadLastWeek error: $e');
      return WeeklyReport.empty();
    }
  }

  /// 加载指定日期所在周的报告
  Future<WeeklyReport> loadWeek(DateTime date) async {
    try {
      return await _service.buildWeekReport(date);
    } catch (e) {
      debugPrint('WeeklyReportRepository.loadWeek error: $e');
      return WeeklyReport.empty();
    }
  }

  /// 加载月度汇总
  Future<MonthlySummary> loadCurrentMonth() async {
    try {
      return await _service.buildCurrentMonthReport();
    } catch (e) {
      debugPrint('WeeklyReportRepository.loadCurrentMonth error: $e');
      return const MonthlySummary(
        newWords: 0,
        reviewWords: 0,
        studyDays: 0,
        averageQuality: 0,
        planCompletedDays: 0,
      );
    }
  }

  /// 清除缓存
  void invalidate() {
    _service.invalidate();
  }
}
