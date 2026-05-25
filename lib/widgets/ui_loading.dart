import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/ui_theme.dart';

/// 统一加载动画组件
///
/// 特性：
/// - 多粒子流体动画
/// - 渐变色彩流动
/// - 平滑旋转 + 缩放
/// - 可配置大小和颜色
class UILoading extends StatefulWidget {
  final double size;
  final List<Color>? colors;
  final String? message;

  const UILoading({super.key, this.size = 80, this.colors, this.message});

  @override
  State<UILoading> createState() => _UILoadingState();
}

class _UILoadingState extends State<UILoading> with TickerProviderStateMixin {
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
    final colors = widget.colors ?? UITheme.accentGradient;

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
              painter: _UILoadingPainter(
                rotation: _rotationAnimation.value,
                scale: _scaleAnimation.value,
                opacity: _opacityAnimation.value,
                colors: colors,
              ),
            );
          },
        ),

        // 消息文字
        if (widget.message != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.message!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// 加载动画绘制器
class _UILoadingPainter extends CustomPainter {
  final double rotation;
  final double scale;
  final double opacity;
  final List<Color> colors;

  _UILoadingPainter({
    required this.rotation,
    required this.scale,
    required this.opacity,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.8;

    // 绘制外圈粒子
    for (int i = 0; i < 8; i++) {
      final angle = rotation + (i * math.pi / 4);
      final particleRadius = radius * 0.3 * scale;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), particleRadius, paint);
    }

    // 绘制内圈粒子
    for (int i = 0; i < 4; i++) {
      final angle = -rotation * 1.5 + (i * math.pi / 2);
      final particleRadius = radius * 0.2 * scale;
      final x = center.dx + radius * 0.5 * math.cos(angle);
      final y = center.dy + radius * 0.5 * math.sin(angle);

      final paint = Paint()
        ..color = colors[(i + 2) % colors.length].withValues(
          alpha: opacity * 0.8,
        )
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), particleRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _UILoadingPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.scale != scale ||
        oldDelegate.opacity != opacity;
  }
}

/// 简单加载指示器
class UISimpleLoading extends StatelessWidget {
  final double size;
  final Color? color;

  const UISimpleLoading({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
