import 'package:flutter/material.dart';

/// 流体渐变动画曲线定义
class FluidCurves {
  /// 渐变流动动画 - 快速流畅
  static const Duration fluidDuration = Duration(milliseconds: 2000);
  static const Curve fluidCurve = Curves.easeInOut;

  /// Shimmer 光效动画 - 更快速
  static const Duration shimmerDuration = Duration(milliseconds: 1500);
  static const Curve shimmerCurve = Curves.linear;

  /// 粒子动画
  static const Duration particleDuration = Duration(milliseconds: 1000);
  static const Curve particleCurve = Curves.easeOut;

  /// 背景流动速度系数
  static const double fluidSpeed = 1.0;

  /// Shimmer 强度
  static const double shimmerIntensity = 0.6;

  /// 创建流动渐变动画
  static Animation<AlignmentGeometry> createFluidAnimation({
    required TickerProvider vsync,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    final controller = AnimationController(
      duration: fluidDuration,
      vsync: vsync,
    );

    return Tween<AlignmentGeometry>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: controller, curve: fluidCurve));
  }

  /// 创建 Shimmer 动画
  static Animation<double> createShimmerAnimation({
    required TickerProvider vsync,
  }) {
    final controller = AnimationController(
      duration: shimmerDuration,
      vsync: vsync,
    );

    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: shimmerCurve));
  }
}
