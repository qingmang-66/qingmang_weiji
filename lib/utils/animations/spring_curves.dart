import 'dart:math' as math;
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';

/// 120fps 优化的弹簧物理曲线
class SpringCurves {
  /// 按钮点击反馈 - 快速响应（更丝滑的弹簧效果）
  static const SpringDescription click = SpringDescription(
    mass: 0.5, // 更轻质量，更快响应
    stiffness: 300.0, // 更高刚度，更明显的回弹
    damping: 15.0, // 较低阻尼，更多弹性
  );

  /// 卡片点击反馈 - 中等弹性
  static const SpringDescription card = SpringDescription(
    mass: 0.8,
    stiffness: 250.0,
    damping: 18.0,
  );

  /// 卡片展开/收起
  static const SpringDescription expand = SpringDescription(
    mass: 1.2,
    stiffness: 200.0,
    damping: 20.0,
  );

  /// 页面切换 - 流畅过渡
  static const SpringDescription page = SpringDescription(
    mass: 1.5,
    stiffness: 180.0,
    damping: 22.0,
  );

  /// 对话框弹出
  static const SpringDescription dialog = SpringDescription(
    mass: 1.0,
    stiffness: 190.0,
    damping: 19.0,
  );

  /// 图标缩放 - 快速弹性
  static const SpringDescription icon = SpringDescription(
    mass: 0.4,
    stiffness: 350.0,
    damping: 12.0,
  );

  /// 柔和弹簧 - 适合微交互
  static const SpringDescription soft = SpringDescription(
    mass: 1.0,
    stiffness: 150.0,
    damping: 25.0,
  );

  /// 弹性弹簧 - 明显的回弹效果
  static const SpringDescription bouncy = SpringDescription(
    mass: 0.6,
    stiffness: 400.0,
    damping: 10.0,
  );

  /// 将 SpringDescription 转换为 Animation
  static Animation<double> createAnimation({
    required SpringDescription spring,
    required TickerProvider vsync,
    double begin = 0.0,
    double end = 1.0,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    final controller = AnimationController(duration: duration, vsync: vsync);

    return controller.drive(Tween<double>(begin: begin, end: end));
  }

  /// 创建弹簧缩放动画（用于按钮/卡片点击）
  static Animation<double> createScaleAnimation({
    required SpringDescription spring,
    required TickerProvider vsync,
    double pressedScale = 0.95,
  }) {
    final controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: vsync,
    );

    return controller.drive(Tween<double>(begin: 1.0, end: pressedScale));
  }
}

/// 多种动画曲线选择
class AnimationCurves {
  /// 弹性曲线 - 明显的回弹效果（类似弹簧）
  static const Curve elastic = _ElasticOutCurve();

  /// 反弹曲线 - 多次反弹效果
  static const Curve bounce = _BounceOutCurve();

  /// 快速开始，缓慢结束
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;

  /// 缓慢开始，快速结束
  static const Curve slowOutFastIn = Curves.easeOut;

  /// 平滑的S型曲线
  static const Curve smooth = Curves.easeInOutCubic;

  /// 更夸张的回弹
  static const Curve exaggeratedBounce = _ExaggeratedBounceCurve();
}

/// 弹性输出曲线
class _ElasticOutCurve extends Curve {
  const _ElasticOutCurve();

  @override
  double transform(double t) {
    if (t == 0 || t == 1) return t;
    return math.pow(2, -10 * t) * math.sin((t - 0.075) * (2 * math.pi) / 0.3) +
        1;
  }
}

/// 反弹输出曲线
class _BounceOutCurve extends Curve {
  const _BounceOutCurve();

  @override
  double transform(double t) {
    if (t < 1 / 2.75) {
      return 7.5625 * t * t;
    } else if (t < 2 / 2.75) {
      t -= 1.5 / 2.75;
      return 7.5625 * t * t + 0.75;
    } else if (t < 2.5 / 2.75) {
      t -= 2.25 / 2.75;
      return 7.5625 * t * t + 0.9375;
    } else {
      t -= 2.625 / 2.75;
      return 7.5625 * t * t + 0.984375;
    }
  }
}

/// 夸张反弹曲线
class _ExaggeratedBounceCurve extends Curve {
  const _ExaggeratedBounceCurve();

  @override
  double transform(double t) {
    if (t < 1 / 3) {
      return 9 * t * t;
    } else if (t < 2 / 3) {
      t -= 0.5;
      return 9 * t * t + 0.75;
    } else {
      t -= 0.75;
      return 9 * t * t + 0.9375;
    }
  }
}
