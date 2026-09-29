import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';
import '../services/providers/theme_provider.dart';
import '../utils/color_utils.dart';
import '../utils/platform_info.dart';

/// 液态玻璃动效令牌：全部为真实物理弹簧，禁止 ease-in-out 观感
class LiquidMotion {
  LiquidMotion._();

  ///弹窗入场：果冻式上弹（阻尼偏低，保留一次可见回弹）
  static const SpringDescription jellyEntrance = SpringDescription(
    mass: 1.1,
    stiffness: 210,
    damping: 14,
  );

  ///卡片切换：纸张入水，折叠展开后轻微回弹
  static const SpringDescription cardSwitch = SpringDescription(
    mass: 1.0,
    stiffness: 220,
    damping: 13.5,
  );

  ///按压反馈：快速回弹
  static const SpringDescription press = SpringDescription(
    mass: 0.6,
    stiffness: 320,
    damping: 14,
  );

  ///列表水波展开
  static const SpringDescription expand = SpringDescription(
    mass: 1.2,
    stiffness: 190,
    damping: 17,
  );

  ///用弹簧仿真驱动控制器，仿真自然结束后自动停（可被 pumpAndSettle）
  static void run(
    AnimationController controller, {
    SpringDescription spring = jellyEntrance,
    double velocity = 0,
  }) {
    controller.animateWith(SpringSimulation(spring, 0, 1, velocity));
  }
}

/// 把物理弹簧包装为 Curve：归一化时间 [0,1] 映射到弹簧位移（允许超调）
class SpringMotionCurve extends Curve {
  final SpringDescription spring;
  final double period;
  late final SpringSimulation _sim;

  SpringMotionCurve(this.spring, {this.period = 0.62}) {
    _sim = SpringSimulation(spring, 0, 1, 0);
  }

  @override
  double transformInternal(double t) => _sim.x((t.clamp(0.0, 1.0)) * period);
}

/// 液态玻璃风格设计令牌
///
/// 参照 iOS 26 Liquid Glass：高强高斯模糊 + 饱和度提升 + 极薄着色
/// + 果冻镜面描边（左上亮白受光边、右下微暗厚度边）
/// + 内侧顶部强高光带 + 底部折射反光 + 内部环境色灵动光斑
class LiquidGlass {
  LiquidGlass._();

  /// 模糊强度（全站唯一档 = 底部导航条同款）
  ///
  /// 要的是**液态玻璃而不是毛玻璃**：模糊越小，背景的形与色就越"清"地透过来，
  /// 玻璃才像一块透明材质而不是一片磨砂。当前背景本身是大尺度柔光斑
  /// （见 `_AmbientGlassBackground`），几乎不含高频细节，所以 sigma 不必更大。
  ///
  /// 曾分 10/18 轻档与 12/22 强调档两档（小表面用轻档、移动端降档省电）。
  /// 为与导航栏观感完全统一——全站所有玻璃的折射强度一致——轻档已退役，
  /// 默认档与原强调档同值。BackdropFilter 每帧高斯开销与 sigma 近似线性，
  /// 将来若要按面省电，可在调用处显式传 `blurSigma` 降档。
  static double get blurSigmaHeavy => isMobilePlatform ? 12.0 : 22.0;

  /// 自带彩色光斑强度倍率（0 = 关闭）
  ///
  /// 原先每张玻璃都叠 2~3 个自带彩色光斑（普通玻璃的冷蓝/暖紫双光斑、
  /// 强调玻璃的品牌色柔光），让玻璃「自带颜色」。但系统 UI 的玻璃色彩来自
  /// 背景透射，而非组件自身发光 —— 自带光斑会让所有卡片无论背景如何，
  /// 都是同一种彩色果冻。置 0 后色彩完全交给背景 + [accentTint]。
  ///
  /// 注意：关闭光斑必须与提高模糊档（[blurSigmaHeavy]）同时进行，否则玻璃会发灰。
  /// 需要回退观感时调回 1.0 即可。
  static const double decorOrbs = 0.0;

  /// 极通透着色：宁薄勿厚，灰感主要来自底色堆叠
  ///
  /// 深色的 0.45 是刻意调高的：背景光斑透过薄纱会在卡片内部复现出
  /// "上亮下暗"的大片明暗差（实测薄纱 0.13 + 光斑峰值 0.5 时卡内亮度差
  /// 高达 ~50 级），玻璃薄到几乎全透时，卡片看起来就像坏了一半。
  /// 提高到近半后配合压暗的背景光斑，卡内明暗差实测约 8 级 ——
  /// 肉眼是均匀的深蓝灰磨砂，透光只剩隐约的流动感（参照 iOS 深色控制中心）。
  static const double tintLight = 0.07;
  static const double tintDark = 0.45;

  /// 强调色玻璃（按钮等）品牌色注入量
  static const double accentAlpha = 0.24;

  /// 模糊滤镜：纯高斯模糊
  /// 注意：不可用 ImageFilter.compose(matrix)，Windows/Impeller 下会导致
  /// backdrop 渲染失败整屏变灰；背景增艳靠饱和度矩阵与内部光斑实现
  ///
  /// 按 sigma 缓存：全站统一取 [blurSigmaHeavy]（调用处仍可显式传其他值），
  /// 而 GlassSurface 每次 build 都会取一次 —— 不缓存则每张玻璃每次构建
  /// 都新建一个原生滤镜句柄（同值、可直接复用）。
  static final Map<double, ImageFilter> _blurFilters = {};
  static ImageFilter blurFilter(double sigma) => _blurFilters.putIfAbsent(
    sigma,
    () => ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
  );

  /// 果冻描边渐变：上边受光亮白边 → 中部半透 → 下边微暗厚度边
  ///
  /// 方向必须是**竖直**而不是 topLeft→bottomRight：对角渐变在宽卡片上
  /// 会让右侧整整一条边、以及下边的右半段都偏向末端颜色，看起来就是
  /// "有些框的某几段边框发灰"。竖直后上下边各自均匀，左右边对称过渡。
  static Gradient edgeGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              Colors.white.withValues(alpha: 0.95),
              Colors.white.withValues(alpha: 0.35),
              Colors.white.withValues(alpha: 0.12),
            ]
          : [
              Colors.white.withValues(alpha: 1.0),
              Colors.white.withValues(alpha: 0.65),
              Colors.black.withValues(alpha: 0.10),
            ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  /// 内侧顶部高光线颜色（果冻上表面镜面反射）
  static Color topEdgeGlow(bool isDark) =>
      Colors.white.withValues(alpha: isDark ? 0.55 : 0.9);

  /// 玻璃底色：极薄，亮色近透白，暗色带一丝冷蓝避免纯黑
  static Color tint(bool isDark) => isDark
      ? const Color(0xFF232638).withValues(alpha: tintDark)
      : Colors.white.withValues(alpha: tintLight);

  /// 强调玻璃底色（品牌色注入，保持果冻通透）
  static Color accentTint(Color primary, bool isDark) =>
      Color.alphaBlend(primary.withValues(alpha: accentAlpha), tint(isDark));

  /// 覆盖层（对话框、底部弹窗）玻璃的着色
  ///
  /// 这类玻璃背后是遮罩暗化后的页面，沿用主页面的薄纱会让透出来的背景被压暗，
  /// 观感就是"弹窗发灰"。这里给一层更厚的纱，覆盖层仍然透亮、正文可读。
  static Color overlayTint(bool isDark) => isDark
      ? const Color(0xFF232638).withValues(alpha: 0.20)
      : Colors.white.withValues(alpha: 0.32);

  /// 外层玻璃浮动阴影：深色投影 + 顶部受光边
  static List<BoxShadow> shadow(bool isDark) => [
    ...dropShadow(isDark),
    ...edgeHighlight(isDark),
  ];

  /// 玻璃下方的深色投影（环境漫射 + 接触阴影）
  ///
  /// 注意：玻璃本体只有 ~7% 不透明度，这层投影若直接垫在它下面，会**从内部
  /// 透出来**；又因为两个投影整体向下偏移，观感就是卡片内部多出一层灰、
  /// 越靠底部越明显。因此 [GlassSurface] 会把它裁到卡片形状之外再绘制，
  /// 见 [_GlassDropShadowPainter]。这里保留完整列表供需要普通阴影的场景使用。
  ///
  /// 浅色下收得比深色紧得多：卡片列表的间距只有 ~8px，投影的模糊半径越大，
  /// 向上溢出的部分就越会落在**上一张卡片的内部**（σ=20 时能爬到卡顶上方
  /// 60px），几张卡片叠起来就是"每张卡下沿一层灰"。
  ///
  /// 另外玻璃越透，投影在卡缝里压出的暗线就越显眼 —— 透亮感本来就该由
  /// "背景颜色 + 细亮描边"立形，而不是靠投影。浅色留一层极轻的接地感即可。
  static List<BoxShadow> dropShadow(bool isDark) => [
    //底层：带环境色倾向的柔和漫射，模拟极光背景的彩色反光
    BoxShadow(
      color: const Color(0xFF7A6BFF).withValues(alpha: isDark ? 0.22 : 0.035),
      blurRadius: isDark ? 48 : 14,
      offset: Offset(0, isDark ? 24 : 6),
      spreadRadius: isDark ? -12 : -5,
    ),
    //中层：紧贴玻璃底部的接触阴影，提供接地感
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.028),
      blurRadius: isDark ? 12 : 6,
      offset: Offset(0, isDark ? 4 : 2),
      spreadRadius: -2,
    ),
  ];

  /// 玻璃内部的白色底光（"这层白就是玻璃本身的奶感"，也是玻璃唯一的挡光来源）
  ///
  /// 必须**铺满整张卡片**。旧实现写成 `spreadRadius: -3, offset: (0,-1)`
  /// 去模仿"顶部 1px 受光边"，结果白层在四周内缩了 3~4px：玻璃只有 ~7%
  /// 不透明度，那圈没被提亮的边缘就原样透出背景（而背景刚好被卡片自身的
  /// 投影压暗），浅色模式下表现为"卡片内部下沿一道灰边"。
  /// 顶部的受光边由 [topEdgeGlow] 与 [_GlassBorderPainter] 负责，不需要这里兼职。
  ///
  /// 浅色下这个 alpha 就是"透不透"的总开关：卡片 = alpha 的白 + (1-alpha) 的背景。
  /// 0.20 时背景透出约 76%，卡片只比背景亮十来级，形状由**细亮描边 + 顶部高光**
  /// 立住（参照系统控制中心的玻璃砖：几乎只是一层薄纱 + 一圈边）。
  /// 注意"透"必须配合高彩度背景：背景若是低彩度的淡灰紫，透出来的就是灰，
  /// 越透越灰 —— 颜色靠 [ambientOrbs] 给，不要靠这里加白去救。
  static List<BoxShadow> edgeHighlight(bool isDark) => [
    BoxShadow(
      color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.20),
      blurRadius: 0,
      offset: Offset.zero,
      spreadRadius: 0,
    ),
  ];

  /// 嵌套玻璃片轻投影（玻璃上叠玻璃，不能投影过重），同样带环境色微光
  static List<BoxShadow> innerShadow(bool isDark) => [
    BoxShadow(
      color: const Color(0xFF8B7CFF).withValues(alpha: isDark ? 0.16 : 0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
      spreadRadius: -6,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: -4,
    ),
  ];

  /// 边缘色散：左上冷蓝、右下暖粉，仅用于 1px 极弱折射边
  static Color dispersionCool(bool isDark) =>
      const Color(0xFF8EC5FF).withValues(alpha: isDark ? 0.20 : 0.12);
  static Color dispersionWarm(bool isDark) =>
      const Color(0xFFFFB8D8).withValues(alpha: isDark ? 0.16 : 0.10);

  /// 光斑氛围背景色板（液态玻璃风格页面底层，供 FluidBackground 使用）
  ///
  /// 浅色下要的是"高彩度 + 高明度"：玻璃只有 ~70% 挡光，卡片呈现的颜色几乎
  /// 就是背景色。背景彩度一低（淡灰紫），透出来的就发灰 —— 灰带的观感就是这么
  /// 来的，所以这里宁可色相足一点，也不要用"接近白"的低彩度色。
  /// 深色模式本来就是高明度彩斑，保持不变。
  static List<Color> ambientOrbs(bool isDark) => isDark
      ? const [
          Color(0xFF5BB8FF), // 明亮天蓝
          Color(0xFF8B5CF6), // 亮紫罗兰
          Color(0xFFFF6B8A), // 珊瑚粉红
        ]
      : const [
          Color(0xFF6FAEFF), // 天蓝（彩度高、明度也够）
          Color(0xFFB79CFF), // 紫罗兰
          Color(0xFFFF9EB8), // 珊瑚粉
        ];

  /// 氛围背景基色
  static Color ambientBase(bool isDark) =>
      isDark ? const Color(0xFF0B0D14) : const Color(0xFFF8FBFF);
}

/// 玻璃嵌套深度跟踪：仅用于嵌套层级的投影选型（内层换用 [LiquidGlass.innerShadow]
/// 轻投影）。材质本身不按层级降级 —— 内层玻璃同样实时折射，与导航栏标准一致
class _GlassDepth extends InheritedWidget {
  final int depth;
  const _GlassDepth({required this.depth, required super.child});
  @override
  bool updateShouldNotify(_GlassDepth old) => old.depth != depth;
}

/// 液态玻璃表面
///
/// 通用玻璃材质容器：强模糊折射、饱和增强、极薄着色、内部灵动光斑、
/// 果冻镜面描边、顶部高光带与浮动阴影。需置于有内容的背景之上；
/// 嵌套在其他玻璃内时保持同样的实时折射（仅换用内层轻投影），
/// 全站材质与导航栏一致，不再按嵌套层级降级。
class GlassSurface extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? tint;

  ///模糊强度：null 时用全站统一档（导航栏同款，见 [LiquidGlass.blurSigmaHeavy]）。
  ///Dart 要求可选参数默认值为编译期常量，而 blurSigmaHeavy 是运行期 getter，
  ///故这里用可空字段、在 build 内解析，而不是直接给默认值。
  final double? blurSigma;
  final bool emphasized;

  ///覆盖材质明暗：自定义背景场景下按背景亮度取色，而非跟随 App 主题
  final bool? darkSurface;

  ///内部光斑色调：强调按钮传品牌色，呈现彩色果冻豆；null 用环境蓝紫光斑
  final Color? glowColor;

  ///表面细密噪点：弹窗/大卡片建议开启，消除塑料感
  final bool grain;

  ///强制降级为无模糊的果冻片。
  ///列表中的每个行卡片若都做一次 BackdropFilter 背景采样，滚动成本极高；
  ///这类「同屏大量重复」的场景传 true，视觉上仍是玻璃片，但没有实时折射。
  final bool forceFlat;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.tint,
    this.blurSigma,
    this.emphasized = false,
    this.darkSurface,
    this.glowColor,
    this.grain = false,
    this.forceFlat = false,
  });

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();

  //饱和度滤镜按明暗缓存：避免每次 build 重建 Float64List+ColorFilter
  static final ColorFilter _satFilterLight = ColorFilter.matrix(
    saturationMatrix(1.28),
  );
  static final ColorFilter _satFilterDark = ColorFilter.matrix(
    saturationMatrix(1.50),
  );

  /// 饱和度增强矩阵：液态玻璃的关键质感来源
  /// Apple 风格：blur 之后提升饱和度让背景光斑更鲜艳
  ///
  /// 注意必须是「绕亮度缩放色度差」的标准形式。
  /// 旧实现是 s·C + (1-s)/2（即 R' = s·R - (s-1)/2）：s>1 时它根本不提饱和度，
  /// 而是拉对比度并把亮部裁到 1.0 ——
  /// 浅绿 #D9EEDA 会被算成 #F2FFF3（约等于纯白），深色则被压到接近纯黑，
  /// 于是玻璃面板里的浅色块（如背景预设色点）全都看不出色相。
  /// 公开出来是为了让单测能直接校验这条不变式（test/liquid_glass_test.dart）。
  static Float64List saturationMatrix(double s) {
    // Rec.709 亮度权重，保证变换后亮度不变、只放大色度
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final inv = 1 - s;
    return Float64List.fromList([
      lr * inv + s,
      lg * inv,
      lb * inv,
      0,
      0,
      lr * inv,
      lg * inv + s,
      lb * inv,
      0,
      0,
      lr * inv,
      lg * inv,
      lb * inv + s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }
}

class _GlassSurfaceState extends State<GlassSurface> {
  ///指针在组件内的归一化坐标(-1~1)，驱动镜面高光视差；无鼠标时为零
  Offset _pointer = Offset.zero;

  void _onHover(PointerHoverEvent e, Size size) {
    if (size.isEmpty) return;
    final nx = ((e.localPosition.dx / size.width) * 2 - 1).clamp(-1.0, 1.0);
    final ny = ((e.localPosition.dy / size.height) * 2 - 1).clamp(-1.0, 1.0);
    final next = Offset(nx, ny);
    //节流：位移过小时不重建
    if ((next - _pointer).distance > 0.04) setState(() => _pointer = next);
  }

  @override
  Widget build(BuildContext context) {
    //只订阅 isDarkMode，避免其他主题属性变化触发不必要的重建
    final isDark =
        widget.darkSurface ??
        context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final radius = BorderRadius.circular(widget.borderRadius);
    final effectiveTint = widget.tint ?? LiquidGlass.tint(isDark);
    final depth =
        context.dependOnInheritedWidgetOfExactType<_GlassDepth>()?.depth ?? 0;
    //仅显式要求（forceFlat 性能逃生舱）时走无模糊降级片；
    //嵌套玻璃不再降级 —— 内层同样实时折射，与导航栏标准一致
    final flat = widget.forceFlat;
    final body = flat
        ? _flatSurface(isDark, radius, effectiveTint)
        : _blurredSurface(isDark, radius, effectiveTint);
    //深色投影只画在卡片形状之外，且必须画在玻璃**之后**（foregroundPainter）；
    //顶层玻璃的白色受光边本身就是内部亮层，仍按普通阴影垫在下面
    final dropShadows = depth > 0
        ? LiquidGlass.innerShadow(isDark)
        : LiquidGlass.dropShadow(isDark);
    final edgeShadows = depth > 0
        ? const <BoxShadow>[]
        : LiquidGlass.edgeHighlight(isDark);
    return _GlassDepth(
      depth: depth + 1,
      child: Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(borderRadius: radius, boxShadow: edgeShadows),
        child: MouseRegion(
          opaque: false,
          onHover: (e) => _onHover(e, context.size ?? Size.zero),
          onExit: (_) {
            if (_pointer != Offset.zero) {
              setState(() => _pointer = Offset.zero);
            }
          },
          //投影画在玻璃**之后**：用 painter（玻璃之前）时，这层投影会进入
          //BackdropFilter 的采样源 —— 高斯模糊把卡片外侧的阴影整片拉回卡内，
          //下半张卡因此被均匀压暗约 15 级（浅色模式下就是"卡片内部下沿横着
          //一条灰带"，且越靠底部越明显）。改成 foregroundPainter 后投影仍在
          //卡片形状之外，但不再参与玻璃的折射采样。
          // 投影单独隔成一层：painter 每次重绘都要 saveLayer + MaskFilter.blur
          // （深色模式 blurRadius 48、离屏范围上百像素），不隔离的话祖先
          // 每帧重绘（背景动画、shimmer）都会连带重跑一次投影
          child: RepaintBoundary(
            child: CustomPaint(
              foregroundPainter: _GlassDropShadowPainter(
                borderRadius: radius,
                shadows: dropShadows,
              ),
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  /// 标准玻璃：BackdropFilter 折射背景 + 饱和度增强 + 果冻光泽层
  Widget _blurredSurface(bool isDark, BorderRadius radius, Color tint) {
    //未显式传值时用全站统一档（导航栏同款）
    final sigma = widget.blurSigma ?? LiquidGlass.blurSigmaHeavy;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: LiquidGlass.blurFilter(sigma),
          child: ColorFiltered(
            colorFilter: isDark
                ? GlassSurface._satFilterDark
                : GlassSurface._satFilterLight,
            child: _surfaceContent(isDark, radius, tint),
          ),
        ),
      ),
    );
  }

  /// 降级玻璃：无模糊果冻片（仅 forceFlat 性能逃生舱场景）
  /// 以 tint 为主色，顶部叠一层白光，彩色 tint 呈现彩色果冻豆
  ///
  /// 浅色下三段白纱刻意压得接近（0.24 / 0.12 / 0.18）：外层玻璃一旦变透，
  /// 中间那段"只剩 tint"的薄腰就会显成内层卡片中部横着的一条灰带。
  Widget _flatSurface(bool isDark, BorderRadius radius, Color tint) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.18),
                      tint,
                    ),
                    tint,
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.10),
                      tint,
                    ),
                  ]
                : [
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.24),
                      tint,
                    ),
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.12),
                      tint,
                    ),
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.18),
                      tint,
                    ),
                  ],
          ),
        ),
        child: _glassLayers(isDark, radius),
      ),
    );
  }

  Widget _surfaceContent(bool isDark, BorderRadius radius, Color tint) {
    //深浅色都不做竖向着色渐变：玻璃本体只有 ~7%~13% 不透明度，任何"顶部多叠一点白"
    //的处理都会被读成"卡片上亮下灰"——浅色下是横贯卡片内部的一条灰带，
    //深色下则是"只有上半张被点亮"的割裂感（stops 落在 0.45 时最明显）。
    //着色调平后，卡片主体亮度完全由背景透射决定，上下沿的厚度感交给
    //_JellyHighlightPainter 的贴边高光与 _GlassBorderPainter 的描边渐变。
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, color: tint),
      child: _glassLayers(isDark, radius),
    );
  }

  /// 光斑层 + 内容 + 描边层 + 噪点层的统一叠放
  Widget _glassLayers(bool isDark, BorderRadius radius) {
    return CustomPaint(
      painter: _JellyHighlightPainter(
        radius: radius,
        isDark: isDark,
        emphasized: widget.emphasized,
        glowColor: widget.glowColor,
        pointer: _pointer,
      ),
      foregroundPainter: _GlassBorderPainter(
        radius: radius,
        border: LiquidGlass.edgeGradient(isDark),
        width: widget.emphasized ? 1.5 : 1.1,
        topGlow: LiquidGlass.topEdgeGlow(isDark),
        cool: LiquidGlass.dispersionCool(isDark),
        warm: LiquidGlass.dispersionWarm(isDark),
        pointer: _pointer,
      ),
      child: CustomPaint(
        foregroundPainter: widget.grain
            ? _GrainPainter(isDark: isDark, radius: radius)
            : null,
        child: _content(),
      ),
    );
  }

  Widget _content() {
    if (widget.padding == null) return widget.child;
    return Padding(padding: widget.padding!, child: widget.child);
  }
}

/// 玻璃卡片的深色投影，只绘制在卡片形状**之外**。
///
/// 为什么不用 BoxDecoration.boxShadow：玻璃本体很透，垫在它下面的阴影会从内部
/// 透出来；又因为阴影整体向下偏移（0,24）/（0,4），透出来之后表现为
/// "卡片内部靠底部多了一层灰"。
/// 这里用与 BoxShadow 相同的几何（spread → offset → blur）绘制，但把卡片自身
/// 从绘制区域中挖掉，于是只在卡片外缘看得到投影。
///
/// **裁切方式必须是"图层 + dstOut 挖空"，不能用 `clipPath(difference, …)`。**
/// `MaskFilter.blur` 的模糊会绕过 clip：实测把卡片形状用 difference 路径裁掉后，
/// 模糊后的阴影仍然被画回卡片内部（卡内下沿出现约 10~15 级压暗、并带紫罗兰色偏，
/// 正是投影色 0xFF7A6BFF + 黑色的叠加）。挖空是在模糊之后用硬边布尔运算做的，
/// 因此不受影响。
///
/// 另外，本 painter 应挂在 `foregroundPainter`（画在玻璃之后）：画在玻璃之前时
/// 它会进入 `BackdropFilter` 的采样源，被 σ=28~34 的高斯模糊整片拉回卡内。
class _GlassDropShadowPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final List<BoxShadow> shadows;

  _GlassDropShadowPainter({required this.borderRadius, required this.shadows});

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty || size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    // 阴影最大扩散距离，用于限定图层范围，避免无谓的超大绘制。
    // 1.4×blurRadius ≈ 2.8σ（MaskFilter 的 σ = blurRadius/2）已完全覆盖
    // 高斯尾部的可见范围；此前用 2×blurRadius（深色模式离屏缓冲四边各
    // 外扩约 100px）纯属超采，同屏多张玻璃时白白放大光栅化内存与填充率
    var reach = 0.0;
    for (final shadow in shadows) {
      reach = math.max(
        reach,
        shadow.blurRadius * 1.4 + shadow.offset.distance + shadow.spreadRadius,
      );
    }
    canvas.saveLayer(rect.inflate(reach.abs() + 1), Paint());
    for (final shadow in shadows) {
      final paint = Paint()..color = shadow.color;
      if (shadow.blurRadius > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma);
      }
      canvas.drawRRect(
        rrect.inflate(shadow.spreadRadius).shift(shadow.offset),
        paint,
      );
    }
    // 把卡片自身从这层阴影里挖掉（硬边，不做模糊），投影就只留在卡片外缘
    final punch = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = const Color(0xFFFFFFFF);
    canvas.drawRRect(rrect, punch);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassDropShadowPainter old) {
    if (old.borderRadius != borderRadius) return true;
    if (old.shadows.length != shadows.length) return true;
    for (var i = 0; i < shadows.length; i++) {
      if (old.shadows[i] != shadows[i]) return true;
    }
    return false;
  }
}

/// 果冻光泽绘制器：内部灵动光斑 + 顶部镜面高光带 + 底部折射反光
class _JellyHighlightPainter extends CustomPainter {
  final BorderRadius radius;
  final bool isDark;
  final bool emphasized;
  final Color? glowColor;
  final Offset pointer;

  _JellyHighlightPainter({
    required this.radius,
    required this.isDark,
    required this.emphasized,
    this.glowColor,
    this.pointer = Offset.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect);
    canvas.save();
    canvas.clipRRect(rrect);

    //自带彩色光斑总强度：decorOrbs 为 0 时下列 alpha 全为 0，
    //_drawOrb 内部会直接早退，光斑整体消失（色彩改由背景透射承载）
    final boost = LiquidGlass.decorOrbs * (emphasized ? 1.3 : 1.0);
    //光斑基准位置随指针产生微小视差，如同手电筒扫过玻璃
    final px = pointer.dx * 0.12;
    final py = pointer.dy * 0.12;

    if (glowColor != null) {
      //彩色果冻（强调按钮）：品牌色柔光从右上漫入
      _drawOrb(
        canvas,
        rect,
        Alignment(0.55 + px, -0.9 + py),
        1.15,
        glowColor!,
        (isDark ? 0.26 : 0.22) * boost,
      );
      _drawOrb(
        canvas,
        rect,
        Alignment(-0.8 + px, 0.9 + py),
        0.9,
        Colors.white,
        (isDark ? 0.05 : 0.10) * boost,
      );
    } else {
      //普通玻璃：冷蓝/暖紫双光斑，纯色背景下也有色彩流动
      _drawOrb(
        canvas,
        rect,
        Alignment(-0.75 + px, -0.85 + py),
        1.1,
        const Color(0xFF7FB8FF),
        (isDark ? 0.17 : 0.12) * boost,
      );
      _drawOrb(
        canvas,
        rect,
        Alignment(0.95 + px, 0.95 + py),
        0.95,
        const Color(0xFFC79BFF),
        (isDark ? 0.15 : 0.10) * boost,
      );
    }

    //指针镜面高光：跟随鼠标的局部亮斑（桌面端手电筒效果）
    if (pointer != Offset.zero) {
      _drawOrb(
        canvas,
        rect,
        Alignment(pointer.dx * 0.55, pointer.dy * 0.55),
        0.7,
        Colors.white,
        isDark ? 0.07 : 0.10,
      );
    }

    //顶部镜面高光带：果冻上表面受光。
    //只覆盖贴着上沿的一小段（旧实现把 white 0.30→0 铺满卡片上 55% 的高度，
    //于是整张卡"上亮下灰"，在浅色模式下就是横贯卡片内部的一层灰带）。
    //收窄到贴边后，卡片主体亮度保持均匀，厚度感交给描边与底部反光。
    //
    //深色下不画：基底本身很暗（合成亮度只有 30 上下），同样强度的白色高光
    //会在深色卡片上形成一条肉眼可见的亮带，整张卡被切成"上亮下暗"两截。
    //深色玻璃的上沿受光改由描边渐变（edgeGradient）与顶部高光线（topEdgeGlow）
    //承担——那两条线本来就贴着边缘画，不会污染卡片主体。
    final sheenHeight = isDark ? 0.0 : math.min(size.height * 0.26, 40.0);
    if (sheenHeight > 0.5) {
      final topPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.14 : 0.17),
            Colors.white.withValues(alpha: isDark ? 0.04 : 0.05),
            transparentLike(Colors.white),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTRB(0, 0, size.width, sheenHeight));
      canvas.drawRect(rect, topPaint);
    }

    //底部边缘折射反光：果冻厚度感。
    //同时也是对"卡底被自身投影透射压暗"的补偿，所以同样只覆盖最下面一小段，
    //避免做成第二条可见的亮带。深色下与顶部高光同理，不画。
    final reflectHeight = isDark ? 0.0 : math.min(size.height * 0.22, 34.0);
    if (reflectHeight > 0.5) {
      final bottomPaint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.white.withValues(alpha: isDark ? 0.10 : 0.20),
                transparentLike(Colors.white),
              ],
            ).createShader(
              Rect.fromLTRB(
                0,
                size.height - reflectHeight,
                size.width,
                size.height,
              ),
            );
      canvas.drawRect(rect, bottomPaint);
    }

    canvas.restore();
  }

  void _drawOrb(
    Canvas canvas,
    Rect rect,
    Alignment center,
    double radiusScale,
    Color color,
    double alpha,
  ) {
    if (alpha <= 0) return;
    final paint = Paint()
      ..shader = RadialGradient(
        center: center,
        radius: radiusScale,
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_JellyHighlightPainter old) =>
      old.isDark != isDark ||
      old.emphasized != emphasized ||
      old.glowColor != glowColor ||
      old.pointer != pointer;
}

/// 玻璃描边绘制器：沿圆角矩形画果冻渐变描边 + 色散边 + 顶部高光线
class _GlassBorderPainter extends CustomPainter {
  final BorderRadius radius;
  final Gradient border;
  final double width;
  final Color topGlow;
  final Color cool;
  final Color warm;
  final Offset pointer;

  _GlassBorderPainter({
    required this.radius,
    required this.border,
    required this.width,
    required this.topGlow,
    required this.cool,
    required this.warm,
    this.pointer = Offset.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect);
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = border.createShader(rect);
    canvas.drawRRect(rrect.inflate(-width / 2), borderPaint);
    //色散边：外侧一圈极弱冷蓝→暖粉渐变，模拟玻璃边缘折射分光
    final dispersionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [cool, transparentLike(cool), warm],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect.inflate(width / 2 + 0.4), dispersionPaint);
    //顶部高光线：中间亮两端渐隐，强化果冻上边缘；位置随指针微移。
    //必须沿圆角走上边缘：此前按下移「半径的固定比例」绘制，圆角越大越往内沉，
    //胶囊按钮/小卡片上会变成一条浮在形状内部的直线。
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [transparentLike(topGlow), topGlow, transparentLike(topGlow)],
      ).createShader(rect);
    final effRadius = radius.topLeft.y.clamp(0.0, size.shortestSide / 2);
    final glowPath = Path();
    if (effRadius > 0.5) {
      glowPath
        ..moveTo(0, effRadius)
        ..arcToPoint(
          Offset(effRadius, 0),
          radius: Radius.circular(effRadius),
          clockwise: true,
        );
    } else {
      glowPath.moveTo(0, 0);
    }
    glowPath.lineTo(size.width - effRadius, 0);
    if (effRadius > 0.5) {
      glowPath.arcToPoint(
        Offset(size.width, effRadius),
        radius: Radius.circular(effRadius),
        clockwise: true,
      );
    }
    canvas.save();
    canvas.translate(pointer.dx * size.width * 0.06, 0.6 + pointer.dy * 1.2);
    canvas.drawPath(glowPath, glowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassBorderPainter old) =>
      old.radius != radius ||
      old.width != width ||
      old.topGlow != topGlow ||
      old.pointer != pointer;
}

/// 玻璃表面细密噪点：固定种子静态点阵（2%~4% 不透明度），消除塑料感
/// 预渲染到 Picture 缓存，避免每帧绘制数千个 drawRect
class _GrainPainter extends CustomPainter {
  final bool isDark;
  final BorderRadius radius;

  _GrainPainter({required this.isDark, required this.radius});

  //噪点缓存：key = 尺寸 + 主题（isDark 参与键值，避免深浅色切换后复用旧色点阵），
  //value = 预渲染的 Picture。Picture 持有引擎侧资源，超限时按插入序淘汰并 dispose。
  static const int _maxGrainCacheSize = 32;
  static final Map<int, Picture> _cache = {};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;
    final int key =
        ((size.width * 10000 + size.height).round() << 1) | (isDark ? 1 : 0);
    final cached = _cache[key];
    if (cached != null) {
      canvas.save();
      canvas.clipRRect(radius.toRRect(rect));
      canvas.drawPicture(cached);
      canvas.restore();
      return;
    }
    final recorder = PictureRecorder();
    final recCanvas = Canvas(recorder);
    recCanvas.clipRRect(radius.toRRect(rect));
    final rnd = math.Random(7);
    final step = 6.0; //步长从4提到6，减少点数量约56%
    final paint = Paint();
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        if (rnd.nextInt(6) != 0) continue; //采样率从1/8降到1/6（步长变大补偿）
        final darkDot = rnd.nextBool();
        //浅色下噪点更轻：点阵本身是"磨砂"观感，而浅色玻璃要的是清透
        paint.color = darkDot
            ? Colors.black.withValues(alpha: isDark ? 0.05 : 0.015)
            : Colors.white.withValues(alpha: isDark ? 0.03 : 0.028);
        recCanvas.drawRect(
          Rect.fromLTWH(
            x + rnd.nextDouble() * 3,
            y + rnd.nextDouble() * 3,
            1.5,
            1.5,
          ),
          paint,
        );
      }
    }
    final picture = recorder.endRecording();
    if (_cache.length >= _maxGrainCacheSize) {
      _cache.remove(_cache.keys.first)?.dispose();
    }
    _cache[key] = picture;
    canvas.save();
    canvas.clipRRect(radius.toRRect(rect));
    canvas.drawPicture(picture);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.isDark != isDark;
}

/// 高透发光胶囊：标签/徽章专用
///
/// 极薄 accent 着色 + 外发光 + 顶部白纱，嵌在玻璃弹窗内也保持高亮识别度
class GlowCapsule extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  const GlowCapsule({
    super.key,
    required this.child,
    required this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        //外发光：品牌色光晕，呈现"发光胶囊"
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.35 : 0.22),
            blurRadius: 14,
            spreadRadius: -2,
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.40 : 0.30),
          width: 0.8,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: isDark ? 0.14 : 0.42),
              color.withValues(alpha: isDark ? 0.26 : 0.12),
            ),
            color.withValues(alpha: isDark ? 0.18 : 0.08),
          ],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// 判断当前是否处于液态玻璃风格（供内联玻璃分支使用）
///
/// 必须用 select 而不是 watch：ThemeProvider 还有主题模式、语言、启动动画速度、
/// 导航位置、循环动效开关等字段，用 watch 时其中任何一个变化都会让全部
/// 二十多个调用点重建。select 只订阅 appStyle，重建触发面收窄到真正相关的变更，
/// 读到的值完全一样。
extension BuildContextGlassStyle on BuildContext {
  bool get isLiquidGlass => select<ThemeProvider, bool>((p) => p.isLiquidGlass);
}
