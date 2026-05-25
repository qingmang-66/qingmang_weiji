import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/providers/theme_provider.dart';

/// 主题辅助工具类
/// 提供根据深浅色模式返回不同颜色的便捷方法
class ThemeHelper {
  /// 获取当前是否为深色模式
  static bool isDark(BuildContext context) {
    return context.read<ThemeProvider>().isDarkMode;
  }

  /// 获取主要文字颜色（深色模式：白色，浅色模式：深色）
  static Color textPrimary(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return isDark ? Colors.white : const Color(0xFF1A1A2E);
  }

  /// 获取次要文字颜色
  static Color textSecondary(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return isDark
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF1A1A2E).withValues(alpha: 0.7);
  }

  /// 获取第三级文字颜色
  static Color textTertiary(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return isDark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF1A1A2E).withValues(alpha: 0.5);
  }

  /// 获取边框颜色
  static Color border(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.1);
  }

  /// 获取背景颜色
  static Color background(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return isDark ? const Color(0xFF0a0a0f) : Colors.white;
  }

  /// 获取表面颜色
  static Color surface(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.8);
  }
}
