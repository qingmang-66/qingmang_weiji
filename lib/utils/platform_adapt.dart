import 'package:flutter/material.dart';

import '../widgets/fluid_background.dart';
import 'platform_info.dart';

/// 跨平台 UI/动效适配
class PlatformAdapt {
  static bool get isMobile => isMobilePlatform;
  static bool get isDesktop => isDesktopPlatform;

  /// 是否允许持续背景动画（手机默认关，桌面开；尊重系统减少动态）
  static bool allowBackgroundAnimation(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    if (mq?.disableAnimations == true) return false;
    if (isMobile) return false;
    return true;
  }

  /// 按钮/卡片是否允许循环 shimmer 流动
  static bool allowLoopEffects(BuildContext context) {
    return allowBackgroundAnimation(context);
  }

  /// 桌面端才展示快捷键入口
  static bool showKeyboardShortcuts(BuildContext context) {
    return isDesktop;
  }
}

/// 带 SafeArea 的流体页面壳，统一系统栏避让与动效策略
class FluidPage extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
  final bool? enableAnimation;

  const FluidPage({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
    this.enableAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final animate =
        enableAnimation ?? PlatformAdapt.allowBackgroundAnimation(context);
    return FluidBackground(
      enableAnimation: animate,
      child: SafeArea(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: child,
      ),
    );
  }
}
