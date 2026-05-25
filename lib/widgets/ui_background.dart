import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../theme/ui_theme.dart';

/// 统一背景组件
///
/// 特性：
/// - 使用 Fragment Shader 实现流体模拟效果
/// - 自动降级为普通渐变（Web 平台或 Shader 加载失败）
/// - 支持自定义颜色和速度
class UIBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final double speed;
  final bool enableTouch;

  const UIBackground({
    super.key,
    required this.child,
    this.colors,
    this.speed = 1.0,
    this.enableTouch = false,
  });

  @override
  State<UIBackground> createState() => _UIBackgroundState();
}

class _UIBackgroundState extends State<UIBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  ui.FragmentProgram? _shaderProgram;
  ui.FragmentShader? _shader;
  bool _shaderLoaded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: (2000 / widget.speed).round()),
      vsync: this,
    )..repeat();

    _loadShader();
  }

  /// 加载 Shader
  Future<void> _loadShader() async {
    // Web 平台不支持 Fragment Shader，直接跳过
    if (kIsWeb) {
      return;
    }

    try {
      _shaderProgram = await ui.FragmentProgram.fromAsset(
        'assets/shaders/fluid_bg.frag',
      );
      setState(() {
        _shaderLoaded = true;
      });
      _updateShader();
    } catch (e) {
      // Shader 加载失败，使用 Fallback 渐变
    }
  }

  /// 更新 Shader 参数
  void _updateShader() {
    if (_shaderProgram != null && mounted) {
      _shader = _shaderProgram!.fragmentShader();
      _shader!
        ..setFloat(0, MediaQuery.of(context).size.width)
        ..setFloat(1, MediaQuery.of(context).size.height)
        ..setFloat(2, _controller.value * 2 * 3.14159);

      // 设置颜色
      final colors = widget.colors ?? UITheme.primaryGradient;
      if (colors.length >= 3) {
        _shader!
          ..setFloat(3, colors[0].r)
          ..setFloat(4, colors[0].g)
          ..setFloat(5, colors[0].b)
          ..setFloat(6, colors[0].a)
          ..setFloat(7, colors[1].r)
          ..setFloat(8, colors[1].g)
          ..setFloat(9, colors[1].b)
          ..setFloat(10, colors[1].a)
          ..setFloat(11, colors[2].r)
          ..setFloat(12, colors[2].g)
          ..setFloat(13, colors[2].b)
          ..setFloat(14, colors[2].a);
      }
    }
  }

  @override
  void didUpdateWidget(covariant UIBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.speed != oldWidget.speed) {
      _controller.duration = Duration(
        milliseconds: (2000 / widget.speed).round(),
      );
    }
    _updateShader();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_shaderLoaded && _shader != null) {
          _updateShader();
          return CustomPaint(
            painter: _ShaderPainter(shader: _shader!),
            child: child,
          );
        }

        // Fallback: 普通渐变背景
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.colors ?? UITheme.primaryGradient,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Shader 绘制器
class _ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;

  _ShaderPainter({required this.shader});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..shader = shader;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShaderPainter oldDelegate) {
    return true;
  }
}
