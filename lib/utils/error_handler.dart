import 'package:flutter/material.dart';
import '../utils/translations.dart';

/// 错误处理工具类
class ErrorHandler {
  /// 显示错误提示
  static void showError(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: Translations.t('关闭', 'Close'),
            onPressed: () {},
          ),
        ),
      );
    }
  }

  /// 显示成功提示
  static void showSuccess(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 显示加载提示
  static void showLoading(BuildContext context, String message) {
    // 这里可以扩展为显示加载对话框
    debugPrint('Loading: $message');
  }

  /// 处理异常并显示友好提示
  static void handleException(BuildContext context, Object e, {String? fallbackMessage}) {
    String message;
    if (e is Exception) {
      message = e.toString().replaceAll('Exception: ', '');
    } else {
      message = e.toString();
    }
    
    // 如果是技术错误，显示更友好的提示
    if (message.contains('FileSystemException') || 
        message.contains('PathNotFoundException')) {
      message = fallbackMessage ?? Translations.t('文件操作失败', 'File operation failed');
    } else if (message.contains('SocketException') || 
               message.contains('Network')) {
      message = fallbackMessage ?? Translations.t('网络错误', 'Network error');
    } else if (message.contains('DatabaseException') || 
               message.contains('SQLite')) {
      message = fallbackMessage ?? Translations.t('数据库错误', 'Database error');
    }
    
    showError(context, message);
  }
}
