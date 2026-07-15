import 'package:flutter/material.dart';

/// 页面切换动画工具类
///
/// 提供多种页面进入/退出动画效果
class PageTransitions {
  PageTransitions._();

  // ==================== 页面进入动画 ====================

  /// 从右侧滑入（iOS风格）
  static Route<T> slideFromRight<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

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
