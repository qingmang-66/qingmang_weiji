import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 按主题同步状态栏/导航栏图标对比度（Edge-to-edge）
void applySystemUiOverlay({required bool isDark}) {
  final style = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
  SystemChrome.setSystemUIOverlayStyle(style);
}
