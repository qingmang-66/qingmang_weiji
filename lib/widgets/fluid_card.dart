import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';
import '../theme/fluid_theme.dart';
import '../services/providers/theme_provider.dart';
import '../utils/app_idle_monitor.dart';
import '../utils/color_utils.dart';
import '../utils/platform_adapt.dart';
import 'liquid_glass.dart';

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

  ///玻璃模式下是否使用实时背景模糊。null = 按平台取默认：
  ///
  ///桌面 true（导航栏同款实时折射）；**移动端 false** —— Android 真机验证
  ///过，长列表每行一次 BackdropFilter 采样会让滚动明显掉帧，移动端默认
  ///降级为无 backdrop 的果冻片（材质由描边与颗粒层承担）。需要在某处
  ///强制统一观感时显式传 true，确证掉帧时显式传 false。
  final bool? enableBlur;

  const FluidCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.enableShimmer = false,
    this.enableBorderGradient = true,
    this.borderColors,
    this.borderRadius = FluidTheme.cardBorderRadius,
    this.backgroundColor,
    this.enableBlur,
  });

  @override
  State<FluidCard> createState() => _FluidCardState();
}

class _FluidCardState extends State<FluidCard> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pressController;
  late final AnimationController _flowController;
  late Animation<double> _animation;
  late Animation<double> _pressAnimation;

  /// 合并后的动画源：build 里每次 `Listenable.merge([...])` 都会新建对象
  /// 并重新订阅/退订两个 controller，卡片数量多时是无谓的分配
  late final Listenable _animationSource;
  bool _isHovered = false;
  bool _isPressed = false;

  /// shimmer 的 30fps 节流代理：跨卡渐变平移的 60fps 与 30fps 肉眼无差，
  /// 每帧重绘一层全卡渐变的开销却可减半（与背景/流光动画同策略）
  late final _ShimmerThrottle _shimmerThrottle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: FluidTheme.shimmerDuration,
      vsync: this,
    );
    //hover 时沿玻璃边缘流动的高光
    _flowController = AnimationController(
      duration: const Duration(milliseconds: 2600),
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
    _shimmerThrottle = _ShimmerThrottle(_animation)..attach();
    // 外层（缩放/流光）与 shimmer 层共用节流后的 shimmer 通知：
    // press 弹簧仍按 _pressController 的原始帧率驱动，保"Q 弹"手感
    _animationSource = Listenable.merge([_shimmerThrottle, _pressController]);
    if (widget.enableShimmer && !AppIdleMonitor.instance.idle.value) {
      _controller.repeat();
    }
    // 空闲暂停（LTPO/高刷适配）：用户停手 3 秒后 shimmer 冻结，
    // 任何交互立即恢复（见 AppIdleMonitor）
    AppIdleMonitor.instance.idle.addListener(_onIdleChanged);
  }

  void _onIdleChanged() {
    if (!mounted) return;
    if (AppIdleMonitor.instance.idle.value) {
      if (_controller.isAnimating) _controller.stop();
    } else if (widget.enableShimmer && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant FluidCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableShimmer != oldWidget.enableShimmer) {
      if (widget.enableShimmer && !AppIdleMonitor.instance.idle.value) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    AppIdleMonitor.instance.idle.removeListener(_onIdleChanged);
    // 先停节流代理再释放源控制器：避免 ticker 的最后一帧回调落到
    // 已 dispose 的通知者上
    _shimmerThrottle.dispose();
    _controller.dispose();
    _pressController.dispose();
    _flowController.dispose();
    super.dispose();
  }

  /// 按压驱动：两种界面风格都走物理弹簧。
  ///
  /// 此前只有液态玻璃风格有回弹，流体渐变风格是 150ms 缓动到 0.98 ——
  /// 同一台设备只要风格不同，按卡片的手感就"塌"下来。统一成弹簧后，
  /// 按下快速收缩、松手有一次可见的回弹（值会短暂越过 1.0，即"Q 弹"）。
  void _drivePress(bool pressed) {
    _pressController.animateWith(
      SpringSimulation(
        LiquidMotion.press,
        _pressController.value,
        pressed ? 1 : 0,
        0,
      ),
    );
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _drivePress(true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _drivePress(false);
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _drivePress(false);
  }

  @override
  Widget build(BuildContext context) {
    final borderColors = widget.borderColors ?? FluidTheme.primaryFluidGradient;
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final isGlass = context.select<ThemeProvider, bool>((p) => p.isLiquidGlass);
    final tickerEnabled =
        TickerMode.valuesOf(context).enabled && widget.enableShimmer;
    if (tickerEnabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!tickerEnabled && _controller.isAnimating) {
      _controller.stop();
    }
    //hover 边缘光流动：仅桌面端/允许循环动效时运行
    final flowEnabled =
        isGlass &&
        _isHovered &&
        TickerMode.valuesOf(context).enabled &&
        PlatformAdapt.allowLoopEffects(context);
    if (flowEnabled && !_flowController.isAnimating) {
      _flowController.repeat();
    } else if (!flowEnabled && _flowController.isAnimating) {
      _flowController.stop();
    }

    final content = Padding(
      padding: widget.padding ?? const EdgeInsets.all(16),
      child: widget.child,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: widget.onTap != null ? _handleTapDown : null,
        onTapUp: widget.onTap != null ? _handleTapUp : null,
        onTapCancel: widget.onTap != null ? _handleTapCancel : null,
        child: AnimatedBuilder(
          animation: _animationSource,
          builder: (context, child) {
            final scale = _isPressed
                ? _pressAnimation.value
                : (_isHovered ? FluidTheme.cardHoverScale : 1.0);
            return Transform.scale(scale: scale, child: child);
          },
          child: isGlass
              ? _buildGlassCard(isDark, content)
              : _buildFluidCard(isDark, borderColors, content),
        ),
      ),
    );
  }

  /// 液态玻璃卡片：模糊折射背景光斑 + 通透着色 + 渐变镜面描边
  Widget _buildGlassCard(bool isDark, Widget content) {
    //玻璃卡片圆角比经典风格更大，体现液态流动感
    final radius = widget.borderRadius == FluidTheme.cardBorderRadius
        ? 24.0
        : widget.borderRadius;
    //实时模糊按平台取默认（桌面 true / 移动端 false，Android 真机掉帧验证），
    //调用处显式传值可强制统一观感或强制降级
    final enableBlur = widget.enableBlur ?? !PlatformAdapt.isMobile;
    return GlassSurface(
      borderRadius: radius,
      margin: widget.margin,
      tint: widget.backgroundColor,
      //与 FluidDialog 的玻璃弹窗完全一致：更强模糊 + 加亮受光描边 + 表面颗粒，
      //保证全站玻璃材质统一（原先页面卡片比弹窗通透、缺少颗粒感）
      blurSigma: LiquidGlass.blurSigmaHeavy,
      emphasized: true,
      grain: true,
      forceFlat: !enableBlur,
      child: Stack(
        children: [
          content,
          if (widget.enableShimmer) _buildShimmerEffect(isDark),
          //hover：高光沿边缘循环流动
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _isHovered ? 1 : 0,
                duration: const Duration(milliseconds: 280),
                child: AnimatedBuilder(
                  animation: _flowController,
                  builder: (context, _) => CustomPaint(
                    painter: _EdgeFlowPainter(
                      radius: radius,
                      progress: _flowController.value,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluidCard(
    bool isDark,
    List<Color> borderColors,
    Widget content,
  ) {
    return Container(
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
        // 非 hover 时也保留一层轻投影：Android 上背景与卡片对比度本就偏低，
        // 无投影 + 无边框时相邻卡片几乎连成一片，用户看不出卡片边界在哪
        // （反馈"点到别的卡片了还以为在同一张上"）。
        boxShadow: _isHovered
            ? FluidTheme.cardShadow
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Container(
        margin: widget.enableBorderGradient ? const EdgeInsets.all(1) : null,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            widget.enableBorderGradient
                ? widget.borderRadius - 1
                : widget.borderRadius,
          ),
          color: widget.backgroundColor ?? FluidTheme.getSurfaceColor(isDark),
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
              content,
              if (widget.enableShimmer) _buildShimmerEffect(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerEffect(bool isDark) {
    final shimmer = FluidTheme.getShimmerColor(isDark);
    // 渐变与 stops 完全不随动画变化，提到 builder 外只算一次；
    // 取宽度用 MediaQuery.sizeOf 而不是 of(context)：后者依赖整份
    // MediaQueryData（键盘、字号、方向），会让这个逐帧 builder 被更多无关变化标脏
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [transparentLike(shimmer), shimmer, transparentLike(shimmer)],
      stops: const [0.0, 0.5, 1.0],
    );
    return AnimatedBuilder(
      // 节流代理：渐变平移的逐帧重绘降到 ~30fps（读值仍来自 _animation）
      animation: _shimmerThrottle,
      builder: (context, child) {
        return Positioned.fill(
          // 单独一层重绘边界：shimmer 是常驻逐帧动画，不隔离的话它每帧
          // 标脏会把同一层里的卡片内容（玻璃分支还包含 BackdropFilter 的
          // 高斯采样）一起重录
          child: RepaintBoundary(
            child: IgnorePointer(
              child: Transform.translate(
                offset: Offset(
                  MediaQuery.sizeOf(context).width * (_animation.value - 0.5),
                  0,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: gradient),
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
class FluidCardTitle extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = gradientColors ?? FluidTheme.primaryFluidGradient;
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(FluidTheme.smallBorderRadius),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
        ],
        ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              //渐变文字：浅色下用压暗变体保证可读，深色沿用原渐变
              colors: isDark ? colors : FluidTheme.textGradient(isDark),
            ).createShader(bounds);
          },
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: FluidTheme.getTextPrimaryColor(isDark),
            ),
          ),
        ),
      ],
    );
  }
}

/// 流体卡片数字组件
class FluidCardNumber extends StatelessWidget {
  final String value;
  final String? label;
  final List<Color>? gradientColors;
  final double fontSize;

  const FluidCardNumber({
    super.key,
    required this.value,
    this.label,
    this.gradientColors,
    this.fontSize = 42,
  });

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? FluidTheme.primaryFluidGradient;
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              //渐变数字：浅色下用压暗变体保证可读，深色沿用原渐变
              colors: isDark ? colors : FluidTheme.textGradient(isDark),
            ).createShader(bounds);
          },
          // 数字在窄槽位（如首页三宫格 56dp）里会换行成两行，用 FittedBox
          // 等比缩小以保证一行完整显示
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: FluidTheme.numberStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: FluidTheme.getTextPrimaryColor(isDark),
              ),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            label!,
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

/// hover 边缘流动高光：一段冷白光带沿圆角矩形周长循环游走
class _EdgeFlowPainter extends CustomPainter {
  final double radius;
  final double progress;

  _EdgeFlowPainter({required this.radius, required this.progress});

  //缓存路径度量：避免每帧 computeMetrics()
  static final Map<int, PathMetric> _metricCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    //尺寸退化（卡片折叠/窗口缩到极小）时 deflate 后是负尺寸路径，
    //computeMetrics() 为空，取 .first 会抛 "Bad state: No element"
    if (size.width <= 3 || size.height <= 3) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.2),
      Radius.circular(math.min(radius - 1.2, size.shortestSide / 2)),
    );
    //用 key 缓存：shortestSide + radius 足以唯一标识同尺寸路径
    final cacheKey = (size.shortestSide * 100 + radius).round();
    var metric = _metricCache[cacheKey];
    if (metric == null) {
      final metrics = (Path()..addRRect(rrect)).computeMetrics();
      if (metrics.isEmpty) return;
      metric = metrics.first;
      //限制缓存大小
      if (_metricCache.length > 20) _metricCache.clear();
      _metricCache[cacheKey] = metric;
    }
    final total = metric.length;
    final seg = total * 0.16;
    final start = progress * total;
    Path segmentAt(double s) {
      final e = math.min(s + seg, total);
      return metric!.extractPath(s, e);
    }

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8EC5FF).withValues(alpha: 0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    final p1 = segmentAt(start);
    canvas.drawPath(p1, glow);
    canvas.drawPath(p1, core);
    if (start + seg > total) {
      final p2 = metric.extractPath(0, start + seg - total);
      canvas.drawPath(p2, glow);
      canvas.drawPath(p2, core);
    }
  }

  @override
  bool shouldRepaint(_EdgeFlowPainter old) =>
      old.progress != progress || old.radius != radius;
}

/// 把源动画的逐帧通知稀疏到约 30fps 的 ChangeNotifier 代理。
///
/// shimmer 是跨越整张卡片的渐变平移：60fps 与 30fps 的肉眼差别可忽略，
/// 但每帧都要重绘一层全卡渐变。读值仍取源动画的实时值，只有通知频率被
/// 稀疏化（与 fluid_background.dart 的 _ThrottledAnimation 同一策略，
/// 这里独立一份以避免 widgets 之间的私有类耦合）。
class _ShimmerThrottle extends ChangeNotifier {
  _ShimmerThrottle(this.source);

  final Animation<double> source;

  static const int _minIntervalMs = 33;

  int _lastNotifyMs = 0;

  void _onTick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNotifyMs < _minIntervalMs) return;
    _lastNotifyMs = now;
    notifyListeners();
  }

  void attach() => source.addListener(_onTick);

  void detach() => source.removeListener(_onTick);

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
