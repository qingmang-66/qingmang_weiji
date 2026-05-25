import 'package:flutter/material.dart';

/// 统一渐变容器组件
///
/// 特性：
/// - 动态渐变动画
/// - 支持点击
/// - 响应式设计
/// - 可配置动画
class UIGradientContainer extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final double borderRadius;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool animated;
  final Duration animationDuration;

  const UIGradientContainer({
    super.key,
    required this.child,
    required this.colors,
    this.borderRadius = 12.0,
    this.width,
    this.height,
    this.padding,
    this.onTap,
    this.animated = true,
    this.animationDuration = const Duration(seconds: 3),
  });

  @override
  State<UIGradientContainer> createState() => _UIGradientContainerState();
}

class _UIGradientContainerState extends State<UIGradientContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    if (widget.animated) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment(
                  -1 + _animation.value * 2,
                  -1 + _animation.value * 2,
                ),
                end: Alignment(
                  1 - _animation.value * 2,
                  1 - _animation.value * 2,
                ),
                colors: widget.colors,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// 统一渐变按钮组件
class UIGradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final List<Color> colors;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  final bool enabled;

  const UIGradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.colors = const [
      Color(0xFF667EEA),
      Color(0xFF764BA2),
      Color(0xFF667EEA),
    ],
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.textStyle,
    this.enabled = true,
  });

  @override
  State<UIGradientButton> createState() => _UIGradientButtonState();
}

class _UIGradientButtonState extends State<UIGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled
          ? (_) => setState(() => _isPressed = true)
          : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _isPressed = false)
          : null,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            transform: Matrix4.identity()
              ..scaleByDouble(
                _isPressed ? 0.95 : 1.0,
                _isPressed ? 0.95 : 1.0,
                1.0,
                1.0,
              ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment(
                  -1 + _animation.value * 2,
                  -1 + _animation.value * 2,
                ),
                end: Alignment(
                  1 - _animation.value * 2,
                  1 - _animation.value * 2,
                ),
                colors: widget.colors,
              ),
              boxShadow: _isPressed
                  ? []
                  : [
                      BoxShadow(
                        color: widget.colors[0].withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            padding: widget.padding,
            child: Center(
              child: Text(
                widget.text,
                style:
                    widget.textStyle ??
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          );
        },
      ),
    );
  }
}
