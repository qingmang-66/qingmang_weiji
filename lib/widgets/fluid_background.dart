import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/fluid_theme.dart';
import '../services/providers/theme_provider.dart';
import '../utils/app_idle_monitor.dart';
import '../utils/platform_adapt.dart';
import '../utils/platform_info.dart';
import 'liquid_glass.dart';

/// 把源动画的通知降频到约 [minInterval] 毫秒一次，下游据此重建。
///
/// 背景渐变与氛围光斑是"缓慢漂移"的大面积图层（一个周期十几秒）：
/// 以 60fps 全屏重绘换来的顺滑度肉眼分辨不出，却让 GPU 一直忙在
/// 填充全屏渐变上。降到约 30fps 可直接省掉近一半的填充开销，
/// 也是降低整机温度最直接的一步。
class _ThrottledAnimation extends ChangeNotifier {
  _ThrottledAnimation(this.source, {int minIntervalMs = _minIntervalMs})
    : _minInterval = minIntervalMs;

  final Animation<double> source;

  /// 最小通知间隔（毫秒）：约 30fps
  static const int _minIntervalMs = 33;

  final int _minInterval;

  int _lastNotifyMs = 0;

  void _onSourceTick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNotifyMs < _minInterval) return;
    _lastNotifyMs = now;
    notifyListeners();
  }

  void attach() => source.addListener(_onSourceTick);
  void detach() => source.removeListener(_onSourceTick);

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}

/// 流体渐变背景组件
///
/// 特性：
/// - 动态流动渐变背景（约 30fps，与页面内容分层重绘）
/// - 支持深浅色主题切换
/// - 液态玻璃风格下渲染光斑氛围背景
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

  /// 降频代理：背景渐变不需要 60fps
  late final _ThrottledAnimation _throttled;
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
    _throttled = _ThrottledAnimation(_animation)..attach();
    // 空闲暂停：Android LTPO（1~120Hz）在"无持续动画"时才能降频省电，
    // Windows 60/90/120Hz 高刷屏同理；任何交互会立即恢复
    AppIdleMonitor.instance.idle.addListener(_onIdleChanged);
  }

  void _onIdleChanged() {
    if (mounted) setState(() {});
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
    AppIdleMonitor.instance.idle.removeListener(_onIdleChanged);
    _throttled.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _shouldAnimate(BuildContext context) {
    if (!_appActive) return false;
    // 用户空闲（无指针/键盘活动）时暂停漂移：屏幕可以降到 1Hz
    if (AppIdleMonitor.instance.idle.value) return false;
    final enabled =
        widget.enableAnimation ??
        PlatformAdapt.allowBackgroundAnimation(context);
    return enabled && TickerMode.valuesOf(context).enabled;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final colors =
        widget.colors ??
        (isDark
            ? FluidTheme.dynamicBackgroundGradient
            : FluidTheme.lightBackgroundGradient);
    final isLiquidGlass = context.select<ThemeProvider, bool>(
      (p) => p.isLiquidGlass,
    );
    // 玻璃风格 + 外层已画了全局氛围光斑时，本层渐变被完全旁路（直接透传 child）：
    // 这时不能再让控制器空转，否则白占一个 vsync 回调（看不见任何画面变化）。
    // 判定必须在起 ticker 之前完成。
    final bypassed = isLiquidGlass && GlassAmbientScope.isActive(context);
    final shouldAnimate = !bypassed && _shouldAnimate(context);

    // 页面不可见或后台时停止背景动画
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }

    if (isLiquidGlass) {
      //外层已绘制全局氛围光斑时透传，玻璃折射需要统一背景源
      if (bypassed) return widget.child;
      return _AmbientGlassBackground(
        isDark: isDark,
        enabled: true,
        animate: shouldAnimate,
        animation: _animation,
        child: widget.child,
      );
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

    // 关键：背景动画层与页面内容拆成两个兄弟节点，各自独立重绘。
    //
    // 之前是 RepaintBoundary(AnimatedBuilder(Container(child: 整页)))：动画每帧
    // 把这个边界标脏，连同页面内容一起重绘 —— 60fps 的全屏重绘正是 Android
    // 持续发热、掉电快的主因。拆开后每帧只重绘这一层渐变，页面内容
    // 在另一个 layer 上，完全不参与。
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            // 降频驱动：背景慢速漂移不需要 60fps
            animation: _throttled,
            builder: (context, _) {
              return DecoratedBox(
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
                    //单色列表时 i/(length-1) = NaN 会让渐变断言失败
                    stops: colors.length > 1
                        ? List.generate(
                            colors.length,
                            (i) => i / (colors.length - 1),
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// 全局氛围光斑作用域
///
/// 包裹整个页面框架（如 HomeScreen），使内部所有 FluidBackground 透传、
/// 所有玻璃组件共享同一折射背景源，避免多层光斑叠加闪烁。
///
/// 注意：无论当前是否液态玻璃风格，本组件返回的 Widget 结构都保持一致
/// （仅由 [enabled] / [active] 控制是否绘制光斑）。否则切换风格时
/// child（整棵 Navigator）会被挂到不同父节点上而被重建，页面状态全部丢失。
class GlassAmbientScope extends StatefulWidget {
  final Widget child;

  const GlassAmbientScope({super.key, required this.child});

  /// 外层是否已绘制全局氛围光斑
  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AmbientProvided>()?.active ??
      false;

  @override
  State<GlassAmbientScope> createState() => _GlassAmbientScopeState();
}

class _GlassAmbientScopeState extends State<GlassAmbientScope>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _animation;

  /// 后台/分屏停表：TickerMode 只在页面不可见时关闭，退到后台（paused/hidden）
  /// 不一定触发，Android 上会留下白跑的 vsync 回调
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      duration: FluidTheme.fluidAnimationDuration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
    // 空闲暂停（LTPO/高刷适配）：见 AppIdleMonitor 注释
    AppIdleMonitor.instance.idle.addListener(_onIdleChanged);
  }

  void _onIdleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active != _appActive) {
      _appActive = active;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppIdleMonitor.instance.idle.removeListener(_onIdleChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLiquidGlass = context.select<ThemeProvider, bool>(
      (p) => p.isLiquidGlass,
    );
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final animate =
        _appActive &&
        isLiquidGlass &&
        // 空闲时暂停光斑漂移：LTPO 面板（1~120Hz）得以降到 1Hz 省电，
        // 桌面高刷屏也不再为静止的背景持续出帧
        !AppIdleMonitor.instance.idle.value &&
        PlatformAdapt.allowBackgroundAnimation(context) &&
        TickerMode.valuesOf(context).enabled;
    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
    }
    return _AmbientProvided(
      active: isLiquidGlass,
      child: _AmbientGlassBackground(
        isDark: isDark,
        enabled: isLiquidGlass,
        animate: animate,
        animation: _animation,
        child: widget.child,
      ),
    );
  }
}

class _AmbientProvided extends InheritedWidget {
  final bool active;

  const _AmbientProvided({required this.active, required super.child});

  @override
  bool updateShouldNotify(_AmbientProvided old) => old.active != active;
}

/// 液态玻璃光斑氛围背景
///
/// 玻璃材质需要背后有可模糊的内容，用大尺寸柔和光斑提供折射源。
/// [enabled] 为 false 时结构不变、只是不绘制任何东西（透传 child）。
class _AmbientGlassBackground extends StatefulWidget {
  final bool isDark;
  final bool enabled;
  final bool animate;
  final Animation<double> animation;
  final Widget child;

  const _AmbientGlassBackground({
    required this.isDark,
    required this.enabled,
    required this.animate,
    required this.animation,
    required this.child,
  });

  @override
  State<_AmbientGlassBackground> createState() =>
      _AmbientGlassBackgroundState();
}

class _AmbientGlassBackgroundState extends State<_AmbientGlassBackground> {
  /// 降频代理：光斑是 15 秒以上的慢速漂移，60fps 全屏重绘纯属浪费。
  ///
  /// 移动端进一步降到约 10fps：光斑是玻璃组件 backdrop 的采样源，它每动一次，
  /// 全站所有 BackdropFilter 就要重新高斯模糊一次。15 秒周期下每 100ms 挪一格
  /// 肉眼看不出步进，却把重模糊次数砍到 1/6 —— 这是玻璃模式省电的关键一档。
  late _ThrottledAnimation _throttled = _ThrottledAnimation(
    widget.animation,
    minIntervalMs: isMobilePlatform ? 100 : 33,
  )..attach();

  @override
  void didUpdateWidget(covariant _AmbientGlassBackground old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _throttled.dispose();
      _throttled = _ThrottledAnimation(
        widget.animation,
        minIntervalMs: isMobilePlatform ? 100 : 33,
      )..attach();
    }
  }

  @override
  void dispose() {
    _throttled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orbs = LiquidGlass.ambientOrbs(widget.isDark);
    // 光斑层与页面内容分成兄弟节点：这一层是包住整个 Navigator 的，
    // 若把 child 放进 AnimatedBuilder 的子树里，光斑每帧重绘就会带着
    // 整个 App 的界面一起重绘（玻璃模式下最典型的发热来源）。
    // 结构在开关风格时保持一致，避免 child 换父节点导致页面状态丢失。
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _throttled,
            builder: (context, _) {
              // 空闲暂停时取动画的**当前值**：光斑冻结在当前位置而不是跳回
              // 起点；用户关闭循环动效时 controller 从未启动、value 恒为 0，
              // 天然退化为静态背景
              final t = widget.enabled ? widget.animation.value : 0.0;
              return Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: widget.enabled
                        ? LiquidGlass.ambientBase(widget.isDark)
                        : Colors.transparent,
                  ),
                  _orb(orbs[0], _drift(t, 0.0, 0.75, -0.6), 0.9),
                  _orb(orbs[1], _drift(t, 0.33, -0.7, 0.55), 1.1),
                  _orb(orbs[2], _drift(t, 0.66, 0.15, 0.85), 0.8),
                ],
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }

  Alignment _drift(double t, double phase, double ax, double ay) {
    final angle = (t + phase) * 2 * math.pi;
    return Alignment(ax + 0.25 * math.cos(angle), ay + 0.25 * math.sin(angle));
  }

  Widget _orb(Color color, Alignment alignment, double scale) {
    //浅色光斑的透明度决定"卡片有没有颜色"。玻璃只叠约三成白纱，卡片呈现的
    //几乎就是背景色 —— 光斑太淡，背景趋于近白的低彩度色，透出来就发灰；
    //保持足够彩度，透出来才是"透亮"的淡蓝/淡紫/淡粉。
    //深色压到 0.22：深色玻璃后面是深底，光斑过强会透过卡片在内部复现出
    //"上亮下暗"的大片明暗差；压平后卡片内部均匀，氛围仍由描边与 tint 提供。
    final peak = widget.isDark ? 0.22 : 0.46;
    return Positioned.fill(
      child: IgnorePointer(
        //非玻璃风格时占位不绘制，保持 Stack 子节点数量一致
        child: !widget.enabled
            ? const SizedBox.shrink()
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: alignment,
                    radius: 0.85 * scale,
                    colors: [
                      color.withValues(alpha: peak),
                      color.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
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

  /// 降频驱动：流光每帧只改渐变端点，30fps 足够顺滑
  late final _ThrottledAnimation _throttled;
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
    _throttled = _ThrottledAnimation(_animation)..attach();
    if (widget.enableShimmer) {
      _controller.repeat();
    }
    AppIdleMonitor.instance.idle.addListener(_onIdleChanged);
  }

  void _onIdleChanged() {
    if (!mounted) return;
    if (AppIdleMonitor.instance.idle.value) {
      if (_controller.isAnimating) _controller.stop();
    } else if (widget.enableShimmer && !_controller.isAnimating) {
      _controller.repeat();
    }
    setState(() {});
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
    //走 ChangeNotifier 标准释放路径（内部先 detach 再 dispose），
    //只 detach 会让监听器列表与对象本身无法回收
    AppIdleMonitor.instance.idle.removeListener(_onIdleChanged);
    _throttled.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 空闲时同一并暂停：常驻流光会阻止 LTPO 降频（高刷屏也白耗帧）
    final tickerEnabled =
        TickerMode.valuesOf(context).enabled &&
        widget.enableShimmer &&
        !AppIdleMonitor.instance.idle.value;
    if (tickerEnabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!tickerEnabled && _controller.isAnimating) {
      _controller.stop();
    }
    //stops 只依赖 colors，提到 builder 外避免流光每帧重新分配。
    //单色列表时 i/(length-1) = NaN，会让渐变断言失败，此时不传 stops
    final stops = widget.colors.length > 1
        ? List.generate(
            widget.colors.length,
            (i) => i / (widget.colors.length - 1),
          )
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        //流光层与内容分层重绘：不隔离的话每帧动画会连带子树一起重录
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _throttled,
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
                      stops: stops,
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

  /// 降频驱动：光泽扫过是慢速动画，30fps 足够
  late final _ThrottledAnimation _throttled;
  bool _allowShimmer = false;

  //渐变不随动画变化，只建一次。0x00FFFFFF 即 transparentLike(Colors.white)
  static const _shimmerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0x00FFFFFF), Color(0x1AFFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.5, 1.0],
  );

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
    _throttled = _ThrottledAnimation(_animation)..attach();
    // 空闲暂停（LTPO/高刷适配）：用户停手 3 秒后流光冻结，
    // 任何交互立即恢复（ChangeNotifier.addListener 对同一监听是幂等的）
    AppIdleMonitor.instance.idle.addListener(_onIdleChanged);
  }

  void _onIdleChanged() {
    if (!mounted) return;
    if (AppIdleMonitor.instance.idle.value) {
      if (_controller.isAnimating) _controller.stop();
    } else if (_allowShimmer && !_controller.isAnimating) {
      _controller.repeat();
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final allow = PlatformAdapt.allowLoopEffects(context);
    if (allow != _allowShimmer) {
      _allowShimmer = allow;
      if (allow) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    //标准释放路径：只 detach 会留下监听器列表无法回收
    AppIdleMonitor.instance.idle.removeListener(_onIdleChanged);
    _throttled.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowShimmer || AppIdleMonitor.instance.idle.value) {
      return widget.child;
    }
    final width = MediaQuery.sizeOf(context).width;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          widget.child,
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _throttled,
              builder: (context, child) {
                return Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(width * _animation.value, 0),
                    child: child,
                  ),
                );
              },
              //渐变层作为静态 child 只建一次，逐帧只重算 translate
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: const BoxDecoration(gradient: _shimmerGradient),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
