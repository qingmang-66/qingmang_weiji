import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/fluid_theme.dart';
import '../services/providers/theme_provider.dart';
import '../utils/platform_adapt.dart';

/// 流体渐变按钮组件
///
/// 特性：
/// - 动态流动渐变背景（200%大小实现流动效果）
/// - 弹簧物理按压动画
/// - 悬浮发光效果
/// - 支持图标和文本
class FluidButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final List<Color>? colors;
  final double fontSize;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final bool expanded;
  final bool isEnabled;

  const FluidButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.colors,
    this.fontSize = 16,
    this.padding,
    this.width,
    this.height,
    this.expanded = false,
    this.isEnabled = true,
  });

  @override
  State<FluidButton> createState() => _FluidButtonState();
}

class _FluidButtonState extends State<FluidButton>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pressController;
  late Animation<double> _animation;
  late Animation<double> _pressAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: FluidTheme.buttonFlowDuration,
      vsync: this,
    );
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _pressAnimation =
        Tween<double>(begin: 1.0, end: FluidTheme.buttonPressedScale).animate(
          CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pressController.dispose();
    super.dispose();
  }

  bool _shouldLoop(BuildContext context) {
    return widget.isEnabled && PlatformAdapt.allowLoopEffects(context);
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.isEnabled) {
      setState(() => _isPressed = true);
      _pressController.forward();
      if (PlatformAdapt.isMobile) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.isEnabled) {
      setState(() => _isPressed = false);
      _pressController.reverse();
      widget.onPressed?.call();
    }
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? FluidTheme.primaryFluidGradient;
    final isInteractive = widget.isEnabled && widget.onPressed != null;
    final effectiveColors = isInteractive
        ? colors
        : [
            Colors.grey.withValues(alpha: 0.35),
            Colors.grey.withValues(alpha: 0.22),
          ];
    final loop = _shouldLoop(context);
    if (loop && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!loop && _controller.isAnimating) {
      _controller.stop();
    }

    final button = MouseRegion(
      cursor: isInteractive
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isInteractive) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isHovered) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: isInteractive ? _handleTapDown : null,
        onTapUp: isInteractive ? _handleTapUp : null,
        onTapCancel: isInteractive ? _handleTapCancel : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_animation, _pressController]),
          builder: (context, child) {
            final scale = _isPressed
                ? _pressAnimation.value
                : (_isHovered ? FluidTheme.buttonHoverScale : 1.0);
            return Transform.scale(
              scale: scale,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  padding:
                      widget.padding ??
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      FluidTheme.buttonBorderRadius,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment(
                        -1 + (loop ? _animation.value : 0) * 2,
                        0,
                      ),
                      end: Alignment(1 + (loop ? _animation.value : 0) * 2, 0),
                      colors: effectiveColors,
                      stops: List.generate(
                        effectiveColors.length,
                        (i) => i / (effectiveColors.length - 1),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: effectiveColors[0].withValues(
                          alpha: _isHovered ? 0.5 : 0.24,
                        ),
                        blurRadius: _isHovered ? 32 : 18,
                        offset: Offset(0, _isHovered ? 12 : 6),
                      ),
                      if (_isHovered && effectiveColors.length > 2)
                        BoxShadow(
                          color: effectiveColors[2].withValues(alpha: 0.2),
                          blurRadius: 48,
                          offset: const Offset(0, 16),
                        ),
                    ],
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: Row(
            mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                widget.text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.expanded) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}

/// 流体图标按钮组件
///
/// 圆形图标按钮，带有流动渐变背景
class FluidIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final List<Color>? colors;
  final double size;
  final double iconSize;
  final String? tooltip;

  const FluidIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.colors,
    this.size = 48,
    this.iconSize = 24,
    this.tooltip,
  });

  @override
  State<FluidIconButton> createState() => _FluidIconButtonState();
}

class _FluidIconButtonState extends State<FluidIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: FluidTheme.buttonFlowDuration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? FluidTheme.primaryFluidGradient;

    Widget button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed?.call();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed
              ? FluidTheme.buttonPressedScale
              : (_isHovered ? FluidTheme.buttonHoverScale : 1.0),
          duration: const Duration(milliseconds: 200),
          curve: FluidTheme.springCurve,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment(
                      -1 + _animation.value * 2,
                      -1 + _animation.value * 2,
                    ),
                    end: Alignment(
                      1 - _animation.value * 2,
                      1 - _animation.value * 2,
                    ),
                    colors: colors,
                    stops: List.generate(
                      colors.length,
                      (i) => i / (colors.length - 1),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors[0].withValues(
                        alpha: _isHovered ? 0.5 : 0.3,
                      ),
                      blurRadius: _isHovered ? 24 : 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Icon(
              widget.icon,
              color: Colors.white,
              size: widget.iconSize,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}

/// 流体文字按钮组件
///
/// 带有渐变色的文本按钮
class FluidTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final List<Color>? colors;
  final double fontSize;

  const FluidTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.colors,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final colors = this.colors ?? FluidTheme.primaryFluidGradient;
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return MouseRegion(
      cursor: onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: onPressed != null
                  ? colors[0]
                  : FluidTheme.getTextTertiaryColor(isDark),
            ),
          ),
        ),
      ),
    );
  }
}
