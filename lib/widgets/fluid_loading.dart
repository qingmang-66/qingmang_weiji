import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/fluid_theme.dart';

/// 流体加载动画组件
///
/// 特性：
/// - 多粒子流体动画
/// - 渐变色彩流动
/// - 平滑旋转 + 缩放
/// - 可配置大小和颜色
class FluidLoading extends StatefulWidget {
  final double size;
  final List<Color>? colors;
  final String? message;

  const FluidLoading({super.key, this.size = 80, this.colors, this.message});

  @override
  State<FluidLoading> createState() => _FluidLoadingState();
}

class _FluidLoadingState extends State<FluidLoading>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _opacityController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // 旋转动画
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    // 缩放动画
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    // 透明度动画
    _opacityController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _opacityController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    _opacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? FluidTheme.primaryFluidGradient;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 粒子动画
        AnimatedBuilder(
          animation: Listenable.merge([
            _rotationAnimation,
            _scaleAnimation,
            _opacityAnimation,
          ]),
          builder: (context, child) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _FluidLoadingPainter(
                rotation: _rotationAnimation.value,
                scale: _scaleAnimation.value,
                opacity: _opacityAnimation.value,
                colors: colors,
              ),
            );
          },
        ),
        // 消息文本
        if (widget.message != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.message!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

/// 流体加载动画绘制器
class _FluidLoadingPainter extends CustomPainter {
  final double rotation;
  final double scale;
  final double opacity;
  final List<Color> colors;

  _FluidLoadingPainter({
    required this.rotation,
    required this.scale,
    required this.opacity,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.8;

    // 绘制外圈渐变圆环
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // 旋转的渐变圆环
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    final rect = Rect.fromCircle(center: center, radius: radius);
    paint.shader = SweepGradient(
      colors: [
        colors[0].withValues(alpha: opacity),
        colors[1].withValues(alpha: opacity * 0.5),
        colors[2].withValues(alpha: opacity),
        colors[0].withValues(alpha: 0),
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
      transform: GradientRotation(rotation),
    ).createShader(rect);

    canvas.drawArc(rect.inflate(-2), 0, math.pi * 1.5, false, paint);

    canvas.restore();

    // 绘制内部粒子
    final particleCount = 6;
    final particleRadius = radius * 0.6;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i * 2 * math.pi / particleCount) + rotation;
      final x = center.dx + particleRadius * math.cos(angle) * scale;
      final y = center.dy + particleRadius * math.sin(angle) * scale;
      final particleCenter = Offset(x, y);

      final particlePaint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: opacity * 0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(particleCenter, 3, particlePaint);
    }

    // 绘制中心点
    final centerPaint = Paint()
      ..color = colors[0].withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 6, centerPaint);
  }

  @override
  bool shouldRepaint(_FluidLoadingPainter oldDelegate) {
    return rotation != oldDelegate.rotation ||
        scale != oldDelegate.scale ||
        opacity != oldDelegate.opacity;
  }
}
