import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/fluid_theme.dart';
import '../services/providers/theme_provider.dart';
import '../utils/app_idle_monitor.dart';
import '../utils/platform_adapt.dart';
import 'liquid_glass.dart';

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

  /// 最小触发间隔：两次 onPressed 之间的硬性下限，null 表示不限制。
  ///
  /// 按钮用的是 onTapDown/onTapUp 而非 onTap，没有任何按压判定/去抖，
  /// 长按、双击、以及上一次触发的动画还在进行时的补点，每一次 down+up
  /// 都会实打实调一次 onPressed。引导页那种"翻页动画期间连点"的场景
  /// 靠调用方自己的翻页锁不够（异步空窗里仍可能漏出去），由它在按钮层
  /// 再兜一道底。
  ///
  /// 默认关闭：多数按钮允许连续触发（如表单校验、下拉刷新），
  /// 全局默认开启会吞掉正常操作。
  final Duration? minTriggerInterval;

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
    this.minTriggerInterval,
  });

  @override
  State<FluidButton> createState() => _FluidButtonState();
}

class _FluidButtonState extends State<FluidButton>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pressController;
  late final AnimationController _sweepController;
  late Animation<double> _animation;
  late Animation<double> _pressAnimation;

  /// 合并后的动画源：build 里每次 Listenable.merge 都会新建对象并重新订阅
  late final Listenable _animationSource;
  bool _isHovered = false;
  bool _isPressed = false;

  /// 冷却窗内的触发会被吞掉（按下/回弹动画照常播）
  bool _triggerBlocked = false;
  Timer? _triggerCooldown;

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
    //点击光影扫过（水银表面被指尖带起的反光）
    _sweepController = AnimationController(
      duration: const Duration(milliseconds: 480),
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
    _animationSource = Listenable.merge([_animation, _pressController]);
  }

  @override
  void dispose() {
    _triggerCooldown?.cancel();
    _controller.dispose();
    _pressController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  bool _shouldLoop(BuildContext context) {
    // 玻璃模式走 GlassSurface，_animation.value 只用于经典分支的渐变端点，
    // 玻璃下开启循环纯属常驻空转的 ticker（高刷屏/ LTPO 都会为它持续出帧）。
    // 空闲时同样暂停：停手 3 秒后所有循环动画让位给系统降频。
    if (!widget.isEnabled) return false;
    if (AppIdleMonitor.instance.idle.value) return false;
    if (context.select<ThemeProvider, bool>((p) => p.isLiquidGlass)) {
      return false;
    }
    return PlatformAdapt.allowLoopEffects(context);
  }

  /// 按压驱动：两种界面风格都走物理弹簧。
  ///
  /// 此前经典（流体渐变）风格是 150ms 缓动，按下是"软塌塌"地缩、
  /// 松手也没有回弹；而只要切到液态玻璃，同一个按钮立刻变得 Q 弹。
  /// 手感不应该由界面风格决定，这里统一成弹簧（松手时值会短暂低于 0，
  /// 映射到缩放上就是一次可见的回弹）。
  void _drivePress(bool pressed) {
    _pressController.animateWith(
      SpringSimulation(
        LiquidMotion.press,
        _pressController.value,
        pressed ? 1 : 0,
        0,
      ),
    );
    //点击光影扫过（水银反光）只在玻璃材质上有意义，保持原样
    if (pressed && context.read<ThemeProvider>().isLiquidGlass) {
      _sweepController.forward(from: 0);
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.isEnabled) {
      setState(() => _isPressed = true);
      _drivePress(true);
      if (PlatformAdapt.isMobile) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.isEnabled) {
      setState(() => _isPressed = false);
      _drivePress(false);
      // 冷却窗内吞掉这次触发：按下/回弹照常播，按钮不会"点了没反应"，
      // 只是不再重复执行动作（见 FluidButton.minTriggerInterval）
      final interval = widget.minTriggerInterval;
      if (interval != null) {
        if (_triggerBlocked) return;
        _triggerBlocked = true;
        _triggerCooldown?.cancel();
        _triggerCooldown = Timer(interval, () {
          if (!mounted) return;
          _triggerBlocked = false;
        });
      }
      widget.onPressed?.call();
    }
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _drivePress(false);
  }

  /// 按钮文字/图标颜色
  ///
  /// 玻璃风格用自适应色；经典风格是 #F093FB→#4FACFE 的高明度渐变，
  /// 白色前景对比度仅 2.04:1，改用深色前景达 8.34:1，渐变本身保持不变。
  Color _labelColor(bool isGlass, bool isInteractive, bool isDark) {
    if (isGlass) {
      return isInteractive
          ? FluidTheme.getTextPrimaryColor(isDark)
          : FluidTheme.getTextTertiaryColor(isDark);
    }
    return isInteractive
        ? FluidTheme.onGradientForeground
        : FluidTheme.onGradientForegroundMuted;
  }

  /// 液态玻璃按钮主体：胶囊形玻璃，模糊折射背景光斑
  Widget _buildGlassButton(
    BuildContext context,
    bool isDark,
    bool isInteractive,
    List<Color> effectiveColors,
    Widget child,
  ) {
    //未指定高度时自适应内容，超大圆角由 RRect 自动钳制为胶囊形
    return GlassSurface(
      width: widget.width,
      height: widget.height,
      borderRadius: widget.height == null ? 999 : widget.height! / 2,
      padding:
          widget.padding ??
          const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      tint: isInteractive
          ? LiquidGlass.accentTint(effectiveColors[0], isDark)
          : LiquidGlass.tint(isDark),
      emphasized: isInteractive,
      glowColor: isInteractive ? effectiveColors[0] : null,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          //点击瞬间一道斜向高光扫过水银表面
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                widget.height == null ? 999 : widget.height! / 2,
              ),
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _sweepController,
                  builder: (context, _) => CustomPaint(
                    painter: _SweepPainter(progress: _sweepController.value),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    final isGlass = context.select<ThemeProvider, bool>((p) => p.isLiquidGlass);
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);

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
          animation: _animationSource,
          builder: (context, child) {
            final scale = _isPressed
                ? _pressAnimation.value
                : (_isHovered ? FluidTheme.buttonHoverScale : 1.0);
            return Transform.scale(
              scale: scale,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: isGlass
                    ? _buildGlassButton(
                        context,
                        isDark,
                        isInteractive,
                        effectiveColors,
                        child!,
                      )
                    : Container(
                        width: widget.width,
                        height: widget.height,
                        padding:
                            widget.padding ??
                            const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            FluidTheme.buttonBorderRadius,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment(
                              -1 + (loop ? _animation.value : 0) * 2,
                              0,
                            ),
                            end: Alignment(
                              1 + (loop ? _animation.value : 0) * 2,
                              0,
                            ),
                            colors: effectiveColors,
                            //单色列表时 i/(length-1) = 0/0 = NaN 会让渐变断言失败，
                            //此时不传 stops（两端同色，无需分布点）
                            stops: effectiveColors.length > 1
                                ? List.generate(
                                    effectiveColors.length,
                                    (i) => i / (effectiveColors.length - 1),
                                  )
                                : null,
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
                                color: effectiveColors[2].withValues(
                                  alpha: 0.2,
                                ),
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
                Icon(
                  widget.icon,
                  color: _labelColor(isGlass, isInteractive, isDark),
                  size: 20,
                ),
                const SizedBox(width: 8),
              ],
              // 撑满宽度的按钮在窄屏/大字体下文字会溢出按钮外——玻璃按钮有
              // ClipRRect，溢出的部分会被静默裁掉（表现为缺半个字）。
              // expanded 模式下允许文字收缩并省略，保证不会出现残缺文字。
              if (widget.expanded)
                Flexible(
                  child: Text(
                    widget.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _labelColor(isGlass, isInteractive, isDark),
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                // 非撑满模式的按钮宽度由内容决定：极窄容器 + 大字体（如英文 +
                // 1.6 倍字号）时文字会溢出按钮，玻璃风格下还会被 ClipRRect
                // 静默裁掉。注意 Row 给非 flex 子项下发的 maxWidth 是无界的，
                // 仅包 FittedBox 不会触发缩放，必须由 Flexible 下发有界宽度后
                // 才能在放不下时等比缩小（空间充足时保持原尺寸与外观）。
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        color: _labelColor(isGlass, isInteractive, isDark),
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
    //不在此处 repeat：循环门控交给 build，避免不可见/低端平台后台空转
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? FluidTheme.primaryFluidGradient;
    final themeProvider = context
        .select<ThemeProvider, ({bool isGlass, bool isDark})>(
          (p) => (isGlass: p.isLiquidGlass, isDark: p.isDarkMode),
        );
    final isGlass = themeProvider.isGlass;
    final isDark = themeProvider.isDark;

    //循环门控：仅在可交互且平台允许时跑流光动画（TickerMode 关闭时自动暂停）
    final loop =
        widget.onPressed != null &&
        PlatformAdapt.allowLoopEffects(context) &&
        TickerMode.valuesOf(context).enabled;
    if (loop && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!loop && _controller.isAnimating) {
      _controller.stop();
    }

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
              if (isGlass) {
                return GlassSurface(
                  width: widget.size,
                  height: widget.size,
                  borderRadius: widget.size / 2,
                  child: Center(child: child),
                );
              }
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
              //渐变之上的图标同样改用深色前景，理由同 _labelColor
              color: isGlass
                  ? FluidTheme.getTextPrimaryColor(isDark)
                  : FluidTheme.onGradientForeground,
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
  final double fontSize;

  const FluidTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);

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
                  //主色 #F093FB 在浅色背景上仅 1.91:1，文字场景改用可读版本（5.91:1）
                  ? FluidTheme.primaryAccessible(isDark)
                  : FluidTheme.getTextTertiaryColor(isDark),
            ),
          ),
        ),
      ),
    );
  }
}

/// 点击扫光：一道斜向柔白光带自左向右掠过水银表面
class _SweepPainter extends CustomPainter {
  final double progress;

  _SweepPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final envelope = math.sin(progress * math.pi); //首尾隐没
    final bandW = size.width * 0.42;
    final cx = size.width * (-0.35 + 1.7 * progress);
    canvas.save();
    canvas.translate(cx, size.height / 2);
    canvas.rotate(-0.32);
    canvas.drawRect(
      Rect.fromLTWH(-bandW / 2, -size.height, bandW, size.height * 2),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.10 * envelope),
                Colors.white.withValues(alpha: 0.55 * envelope),
                Colors.white.withValues(alpha: 0.10 * envelope),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0, 0.35, 0.5, 0.65, 1],
            ).createShader(
              Rect.fromLTWH(-bandW / 2, -size.height, bandW, size.height * 2),
            ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.progress != progress;
}
