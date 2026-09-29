import 'package:flutter/foundation.dart';

import '../../models/weekly_report.dart';
import '../weekly_report_service.dart';

/// 周期学习报告仓储层
///
/// 封装 [WeeklyReportService] 的调用，捕获异常并兜底返回空数据，
/// 确保 UI 层永远不面对数据库异常。
class WeeklyReportRepository {
  final WeeklyReportService _service;

  WeeklyReportRepository(this._service);

  /// 加载本周报告（最近7天，带缓存）
  Future<WeeklyReport> loadCurrentWeek({bool forceRefresh = false}) async {
    try {
      return await _service.buildCurrentWeekReport(forceRefresh: forceRefresh);
    } catch (e) {
      debugPrint('WeeklyReportRepository.loadCurrentWeek error: $e');
      return WeeklyReport.empty();
    }
  }

  /// 加载月度报告（最近30天逐日明细）
  Future<MonthlySummary> loadCurrentMonth() async {
    try {
      return await _service.buildCurrentMonthReport();
    } catch (e) {
      debugPrint('WeeklyReportRepository.loadCurrentMonth error: $e');
      return const MonthlySummary(dailyDetails: []);
    }
  }

  /// 清除缓存
  void invalidate() {
    _service.invalidate();
  }
}
