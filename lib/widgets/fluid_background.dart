import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/fluid_theme.dart';
import '../services/providers/theme_provider.dart';
import '../utils/platform_adapt.dart';

/// 流体渐变背景组件
///
/// 特性：
/// - 动态流动渐变背景
/// - 支持深浅色主题切换
/// - 15秒循环动画（移动端默认关闭以省电）
class FluidBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final double speed;
  final bool? enableAnimation;

  const FluidBackground({
    super.key,
    required this.child,
    this.colors,
    this.speed = 1.0,
    this.enableAnimation,
  });

  @override
  State<FluidBackground> createState() => _FluidBackgroundState();
}

class _FluidBackgroundState extends State<FluidBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      duration: Duration(
        milliseconds:
            (FluidTheme.fluidAnimationDuration.inMilliseconds / widget.speed)
                .round(),
      ),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (!_appActive && _controller.isAnimating) {
      _controller.stop();
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  bool _shouldAnimate(BuildContext context) {
    if (!_appActive) return false;
    final enabled =
        widget.enableAnimation ??
        PlatformAdapt.allowBackgroundAnimation(context);
    return enabled && TickerMode.valuesOf(context).enabled;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final colors =
        widget.colors ??
        (isDark
            ? FluidTheme.dynamicBackgroundGradient
            : FluidTheme.lightBackgroundGradient);
    final shouldAnimate = _shouldAnimate(context);

    // 页面不可见或后台时停止背景动画
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }

    if (!shouldAnimate) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: widget.child,
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
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
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// 流体渐变容器组件
///
/// 用于卡片、按钮等需要流动渐变的元素
class FluidGradientContainer extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool enableShimmer;
  final Duration animationDuration;

  const FluidGradientContainer({
    super.key,
    required this.child,
    required this.colors,
    this.borderRadius = FluidTheme.cardBorderRadius,
    this.padding,
    this.margin,
    this.onTap,
    this.enableShimmer = false,
    this.animationDuration = const Duration(seconds: 6),
  });

  @override
  State<FluidGradientContainer> createState() => _FluidGradientContainerState();
}

class _FluidGradientContainerState extends State<FluidGradientContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
    if (widget.enableShimmer) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant FluidGradientContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableShimmer != oldWidget.enableShimmer) {
      if (widget.enableShimmer) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tickerEnabled =
        TickerMode.valuesOf(context).enabled && widget.enableShimmer;
    if (tickerEnabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!tickerEnabled && _controller.isAnimating) {
      _controller.stop();
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final t = widget.enableShimmer ? _animation.value : 0.0;
            return AnimatedScale(
              scale: _isHovered ? FluidTheme.cardHoverScale : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                margin: widget.margin,
                padding: widget.padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  gradient: LinearGradient(
                    begin: Alignment(-1 + t * 2, -1 + t * 2),
                    end: Alignment(1 - t * 2, 1 - t * 2),
                    colors: widget.colors,
                    stops: List.generate(
                      widget.colors.length,
                      (i) => i / (widget.colors.length - 1),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.colors[0].withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// 流体Shimmer效果组件
///
/// 用于卡片表面的光泽流动效果
class FluidShimmer extends StatefulWidget {
  final Widget child;
  final double borderRadius;

  const FluidShimmer({
    super.key,
    required this.child,
    this.borderRadius = FluidTheme.cardBorderRadius,
  });

  @override
  State<FluidShimmer> createState() => _FluidShimmerState();
}

class _FluidShimmerState extends State<FluidShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: FluidTheme.shimmerDuration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Positioned.fill(
                child: Transform.translate(
                  offset: Offset(
                    MediaQuery.of(context).size.width * _animation.value,
                    0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
