import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'platform_info.dart';

/// 按主题同步状态栏/导航栏图标对比度（Edge-to-edge）
void applySystemUiOverlay({required bool isDark}) {
  final style = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
  SystemChrome.setSystemUIOverlayStyle(style);
}

/// 应用系统栏显示模式。
///
/// - Android：沉浸式全屏。状态栏常驻会把内容整体往下压，挖孔/灵动岛区域
///   也被白白占掉，底部手势导航的"小白条"同样吃掉一截可视高度；
///   改成 [SystemUiMode.immersiveSticky] 后系统栏默认隐藏，用户从屏幕边缘
///   上滑时临时出现并自动隐藏，内容真正铺满整屏。
///   Flutter 仍会把挖孔（displayCutout）计入 SafeArea，内容不会被摄像头遮挡。
/// - 桌面 / Web：保持 edge-to-edge，由 SafeArea 避让即可。
void applySystemUiMode() {
  SystemChrome.setEnabledSystemUIMode(
    isAndroidPlatform ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
  );
}
