import 'package:flutter/material.dart';
import '../widgets/fluid_dialog.dart';
import 'translations.dart';

/// 错误处理工具类
class ErrorHandler {
  /// 显示错误提示（居中弹窗）
  static void showError(BuildContext context, String message) {
    final tr = context.tr;
    if (context.mounted) {
      showFluidDialog<void>(
        context: context,
        title: tr.errorTitle,
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr.confirm),
          ),
        ],
      );
    }
  }

  /// 显示成功提示（居中弹窗）
  static void showSuccess(BuildContext context, String message) {
    final tr = context.tr;
    if (context.mounted) {
      showFluidDialog<void>(
        context: context,
        title: tr.successTitle,
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr.confirm),
          ),
        ],
      );
    }
  }

  /// 显示加载提示
  static void showLoading(BuildContext context, String message) {
    // 这里可以扩展为显示加载对话框
    debugPrint('Loading: $message');
  }

  /// 处理异常并显示真实错误（保留异常原文，必要时附带分类前缀）
  static void handleException(
    BuildContext context,
    Object e, {
    String? fallbackMessage,
  }) {
    final tr = context.tr;
    var detail = e.toString().replaceAll('Exception: ', '');
    if (detail.trim().isEmpty) {
      detail = fallbackMessage ?? tr.unknownError;
    }
    String message = detail;
    if (detail.contains('FileSystemException') ||
        detail.contains('PathNotFoundException')) {
      message = '${fallbackMessage ?? tr.fileOpFailed}\n$detail';
    } else if (detail.contains('SocketException') ||
        detail.contains('Network')) {
      message = '${fallbackMessage ?? tr.networkError}\n$detail';
    } else if (detail.contains('DatabaseException') ||
        detail.contains('SQLite') ||
        detail.contains('no such table')) {
      message = '${fallbackMessage ?? tr.dbError}\n$detail';
    }
    showError(context, message);
  }
}
