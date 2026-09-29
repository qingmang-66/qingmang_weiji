import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/providers/theme_provider.dart';
import 'color_utils.dart';

/// 页面切换动画工具类
///
/// 提供多种页面进入/退出动画效果
class PageTransitions {
  PageTransitions._();

  // ==================== 页面进入动画 ====================

  /// 从右侧滑入（iOS风格）
  ///
  /// 进入：淡入 + 右滑；返回：反向曲线（先滑出、淡出收尾），
  /// 正反向观感对称，避免返回时"整体慢慢淡掉"的平滞感。
  static Route<T> slideFromRight<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 280),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        //加大滑移幅度并隔离重绘：返回时滑动方向明确可读，
        //不再是"整体慢慢淡掉"的平滞感
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );
        final slideAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.18, 0.0),
              end: Offset.zero,
            ).animate(slideAnimation),
            child: RepaintBoundary(child: child),
          ),
        );
      },
      transitionDuration: duration,
      reverseTransitionDuration: duration,
    );
  }

  /// 从底部滑入（模态风格）
  static Route<T> slideFromBottom<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 350),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: duration,
      reverseTransitionDuration: duration,
    );
  }

  /// 淡入动画
  static Route<T> fade<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        );
      },
      transitionDuration: duration,
      reverseTransitionDuration: duration,
    );
  }

  /// 果冻弹性缩放（duangduang效果）
  ///背景快速淡入遮挡旧页面，新页面弹性缩放弹出
  static Route<T> bouncyScale<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 360),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          _BouncyScaleTransition(animation: animation, child: child),
      transitionDuration: duration,
      reverseTransitionDuration: const Duration(milliseconds: 220),
    );
  }

  /// 缩放+淡入动画
  static Route<T> scaleFade<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(scaleAnimation),
            child: child,
          ),
        );
      },
      transitionDuration: duration,
      reverseTransitionDuration: duration,
    );
  }

  /// 共享轴动画（Material风格）
  static Route<T> sharedAxis<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 350),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
        );
        final slideAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.05),
              end: Offset.zero,
            ).animate(slideAnimation),
            child: child,
          ),
        );
      },
      transitionDuration: duration,
      reverseTransitionDuration: duration,
    );
  }
}

/// 果冻弹性缩放转场。
///
/// 早先这段逻辑直接写在 `transitionsBuilder` 里，而它是**逐帧**执行的：
/// 每帧都要重新读一次 ThemeProvider、重建 3 个 CurvedAnimation 与 Tween。
/// 低端 Android 上这部分开销会和"新页面首帧的重型布局"抢同一帧预算，
/// 表现就是"点开始学习进入学习页时掉帧"。
///
/// 拆成 StatefulWidget 后：主题只在挂载时读一次、曲线对象只建一次，
/// 新页面本身用 RepaintBoundary 隔离，缩放期间只做图层合成。
class _BouncyScaleTransition extends StatefulWidget {
  final Animation<double> animation;
  final Widget child;

  const _BouncyScaleTransition({required this.animation, required this.child});

  @override
  State<_BouncyScaleTransition> createState() => _BouncyScaleTransitionState();
}

class _BouncyScaleTransitionState extends State<_BouncyScaleTransition> {
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _bgOpacity;
  late final Color _bgColor;

  @override
  void initState() {
    super.initState();
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: widget.animation, curve: Curves.elasticOut),
    );
    _fade = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    //背景快速淡入遮挡旧页面，解决液态玻璃透明背景导致的重叠
    _bgOpacity = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    );
    //液态玻璃模式下 scaffoldBackgroundColor 是透明的，需要手动计算背景色
    final provider = Provider.of<ThemeProvider>(context, listen: false);
    _bgColor = provider.isLiquidGlass
        ? (provider.isDarkMode
              ? const Color(0xFF1A1A2E) //深色液态玻璃背景
              : const Color(0xFFF0F0F5)) //浅色液态玻璃背景
        : Theme.of(context).scaffoldBackgroundColor;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      //新页面隔成独立图层：缩放/淡入期间不重新录制子树
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: ColoredBox(
              // 淡入起点用"同色透明"而不是 Colors.transparent：
              // Color.lerp 同样按非预乘通道插值，透明黑会让渐显途中发灰。
              color: Color.lerp(
                transparentLike(_bgColor),
                _bgColor,
                _bgOpacity.value,
              )!,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
