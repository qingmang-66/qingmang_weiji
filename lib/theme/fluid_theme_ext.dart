import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/providers/theme_provider.dart';
import 'fluid_theme.dart';

/// 流体主题扩展 - 提供动态颜色方法
extension FluidThemeExt on BuildContext {
  /// 获取当前是否为深色模式
  bool get isDarkMode {
    final themeProvider = watch<ThemeProvider>();
    return themeProvider.isDarkMode;
  }

  /// 获取主要文字颜色
  Color get textPrimaryColor =>
      FluidTheme.getTextPrimaryColor(isDarkMode);

  /// 获取次要文字颜色
  Color get textSecondaryColor =>
      FluidTheme.getTextSecondaryColor(isDarkMode);

  /// 获取第三级文字颜色
  Color get textTertiaryColor =>
      FluidTheme.getTextTertiaryColor(isDarkMode);

  /// 获取边框颜色
  Color get borderColor => FluidTheme.getBorderColor(isDarkMode);

  /// 获取背景颜色
  Color get backgroundColor => FluidTheme.getBackgroundColor(isDarkMode);

  /// 获取表面颜色
  Color get surfaceColor => FluidTheme.getSurfaceColor(isDarkMode);
}
