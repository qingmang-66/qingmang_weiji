import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/fluid_theme.dart';
import '../services/providers/theme_provider.dart';

/// 流体卡片组件
///
/// 特性：
/// - 动态流动渐变边框
/// - Shimmer光泽效果
/// - 弹簧物理动画
/// - 深色玻璃质感
class FluidCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool enableShimmer;
  final bool enableBorderGradient;
  final List<Color>? borderColors;
  final double borderRadius;
  final Color? backgroundColor;

  const FluidCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.enableShimmer = true,
    this.enableBorderGradient = true,
    this.borderColors,
    this.borderRadius = FluidTheme.cardBorderRadius,
    this.backgroundColor,
  });

  @override
  State<FluidCard> createState() => _FluidCardState();
}

class _FluidCardState extends State<FluidCard>
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
      duration: FluidTheme.shimmerDuration,
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
        Tween<double>(begin: 1.0, end: FluidTheme.cardPressedScale).animate(
          CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
        );

    if (widget.enableShimmer) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _pressController.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final borderColors = widget.borderColors ?? FluidTheme.primaryFluidGradient;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: widget.onTap != null ? _handleTapDown : null,
        onTapUp: widget.onTap != null ? _handleTapUp : null,
        onTapCancel: widget.onTap != null ? _handleTapCancel : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_animation, _pressController]),
          builder: (context, child) {
            final scale = _isPressed
                ? _pressAnimation.value
                : (_isHovered ? FluidTheme.cardHoverScale : 1.0);
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            margin: widget.margin,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: widget.enableBorderGradient
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: FluidTheme.getBorderGradientColors(
                        isDark,
                        borderColors,
                      ),
                    )
                  : null,
              boxShadow: _isHovered ? FluidTheme.cardShadow : null,
            ),
            child: Container(
              margin: widget.enableBorderGradient
                  ? const EdgeInsets.all(1)
                  : null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  widget.enableBorderGradient
                      ? widget.borderRadius - 1
                      : widget.borderRadius,
                ),
                color:
                    widget.backgroundColor ??
                    FluidTheme.getSurfaceColor(isDark),
                gradient: widget.backgroundColor == null
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: FluidTheme.getSurfaceGradientColors(isDark),
                      )
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  widget.enableBorderGradient
                      ? widget.borderRadius - 1
                      : widget.borderRadius,
                ),
                child: Stack(
                  children: [
                    // 内容
                    Padding(
                      padding: widget.padding ?? const EdgeInsets.all(16),
                      child: widget.child,
                    ),
                    if (widget.enableShimmer) _buildShimmerEffect(isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerEffect(bool isDark) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned.fill(
          child: IgnorePointer(
            child: Transform.translate(
              offset: Offset(
                MediaQuery.of(context).size.width * (_animation.value - 0.5),
                0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      FluidTheme.getShimmerColor(isDark),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 流体卡片标题组件
///
/// 用于卡片内的标题，带有渐变文字效果
class FluidCardTitle extends StatefulWidget {
  final String text;
  final IconData? icon;
  final List<Color>? gradientColors;

  const FluidCardTitle({
    super.key,
    required this.text,
    this.icon,
    this.gradientColors,
  });

  @override
  State<FluidCardTitle> createState() => _FluidCardTitleState();
}

class _FluidCardTitleState extends State<FluidCardTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: FluidTheme.textFlowDuration,
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
    final colors = widget.gradientColors ?? FluidTheme.primaryFluidGradient;
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Row(
      children: [
        if (widget.icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(FluidTheme.smallBorderRadius),
            ),
            child: Icon(widget.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
        ],
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment(-1 + _animation.value * 2, 0),
                  end: Alignment(1 + _animation.value * 2, 0),
                  colors: colors,
                ).createShader(bounds);
              },
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: FluidTheme.getTextPrimaryColor(isDark),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 流体卡片数字组件
///
/// 用于显示统计数据，带有渐变文字效果
class FluidCardNumber extends StatefulWidget {
  final String value;
  final String? label;
  final List<Color>? gradientColors;
  final double fontSize;

  const FluidCardNumber({
    super.key,
    required this.value,
    this.label,
    this.gradientColors,
    this.fontSize = 36,
  });

  @override
  State<FluidCardNumber> createState() => _FluidCardNumberState();
}

class _FluidCardNumberState extends State<FluidCardNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: FluidTheme.textFlowDuration,
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
    final colors = widget.gradientColors ?? FluidTheme.primaryFluidGradient;
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Column(
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment(-1 + _animation.value * 2, 0),
                  end: Alignment(1 + _animation.value * 2, 0),
                  colors: colors,
                ).createShader(bounds);
              },
              child: Text(
                widget.value,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w700,
                  color: FluidTheme.getTextPrimaryColor(isDark),
                  letterSpacing: -1,
                ),
              ),
            );
          },
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 13,
              color: FluidTheme.getTextSecondaryColor(isDark),
            ),
          ),
        ],
      ],
    );
  }
}
