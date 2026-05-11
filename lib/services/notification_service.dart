import 'package:flutter/foundation.dart';

/// 本地通知服务 - 复习提醒（简化版，暂时禁用）
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// 初始化通知服务（暂时空实现）
  Future<void> init() async {
    debugPrint('通知服务初始化（简化版）');
  }

  /// 显示复习提醒通知（暂时空实现）
  Future<void> showReviewReminder(int dueCount) async {
    debugPrint('复习提醒：有 $dueCount 个单词待复习');
  }

  /// 检查并在需要时显示复习提醒
  Future<void> checkAndShowReminder(int dueCount) async {
    if (dueCount > 0) {
      await showReviewReminder(dueCount);
    }
  }

  /// 加载通知设置
  Future<bool> loadNotificationSetting() async {
    return true;
  }
}
