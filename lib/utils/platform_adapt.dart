import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/providers/theme_provider.dart';
import '../widgets/fluid_background.dart';
import 'platform_info.dart';

/// 跨平台 UI/动效适配
class PlatformAdapt {
  static bool get isMobile => isMobilePlatform;
  static bool get isDesktop => isDesktopPlatform;
  static bool get isWindows => isWindowsPlatform;
  static bool get isAndroid => isAndroidPlatform;

  /// 是否允许循环动效（背景光斑漂移、按钮/卡片 shimmer 流动）。
  ///
  /// Android 端已整体移除循环动效：shimmer 是逐帧重绘的渐变、背景光斑
  /// 让帧调度一直不停，手机上常驻播放持续耗电，而观感提升很有限
  /// （用户反馈"额外增加功耗，带来的观感不是很明显"）。
  /// 非循环的一次性过渡与按压光效不受影响，交互质感仍然保留。
  /// 桌面端仍交给用户在「设置 → 通用 → 循环动效」里决定，且始终尊重
  /// 系统的"减弱动态效果"（[MediaQueryData.disableAnimations]）。
  static bool allowLoopEffects(BuildContext context) {
    if (isAndroidPlatform) return false;
    final mq = MediaQuery.maybeOf(context);
    if (mq?.disableAnimations == true) return false;
    return context.select<ThemeProvider, bool>((p) => p.loopEffectsEnabled);
  }

  /// 是否允许持续背景动画（与循环动效同源，保留独立入口便于语义区分）
  static bool allowBackgroundAnimation(BuildContext context) =>
      allowLoopEffects(context);

  /// 是否展示"键盘快捷键"形态的操作提示。
  ///
  /// 桌面端讲键位（回车/Ctrl+回车/数字键），移动端讲触屏手势，
  /// 两端都保留顶栏问号入口，只是内容不同。
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
