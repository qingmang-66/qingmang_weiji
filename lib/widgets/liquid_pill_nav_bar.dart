import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/platform_adapt.dart';
import 'liquid_glass.dart';

/// 悬浮胶囊导航条的一项
class LiquidPillNavItem {
  /// 未选中图标
  final IconData icon;

  /// 选中/悬停图标（填充态）
  final IconData activeIcon;
  final String label;

  /// 选中色（各 Tab 轮换主渐变色，与旧版导航栏一致）
  final Color activeColor;

  const LiquidPillNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.activeColor,
  });
}

/// 液态玻璃悬浮胶囊导航条（参考 ColorOS 悬浮导航交互）。
///
/// - **轻点**：直接切换到该项；
/// - **按住不放**：胶囊"充气"放大滑到指下，该项着色；
/// - **按住拖动**：胶囊以真实弹簧（速度保持）平滑追随手指，快速滑动时
///   沿运动方向拉伸、被拖动的项放大，松手即切到手指所在项；
///   拖出条外过远视为取消，胶囊弹回当前页；
/// - Android 与 Windows 两端交互一致（鼠标按住拖动同款）。
///
/// 运动实现：ticker 逐帧积分弹簧（位置+速度连续），目标频繁变化时
/// 速度不归零——这是"丝滑追随"的关键（每次 retarget 重放动画会像被吸走）。
///
/// 组件是**受控**的：[currentIndex] + [onChanged]，外部（引导/通知/快捷键/
/// 返回键）直接改索引时胶囊会自动弹到对应项。
/// 纵向（[Axis.vertical]）用于桌面端侧栏，交互语义与横向完全一致。
class LiquidPillNavBar extends StatefulWidget {
  final List<LiquidPillNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final Axis axis;

  /// 纵向侧栏胶囊顶部的附加内容（应用图标）
  final Widget? header;

  /// 纵向展开模式：胶囊条撑满父高度，导航项均分整条空间。
  /// 用于 Windows 左/右侧栏"印在边上"的通高面板；默认（false）
  /// 按每项 56dp 定高，窗口很高时项会挤在顶部。
  final bool expand;

  const LiquidPillNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.axis = Axis.horizontal,
    this.header,
    this.expand = false,
  });

  @override
  State<LiquidPillNavBar> createState() => _LiquidPillNavBarState();
}

class _LiquidPillNavBarState extends State<LiquidPillNavBar>
    with TickerProviderStateMixin {
  // ================== 胶囊运动：弹簧积分追随 ==================
  // 位置/速度都用"小数项索引"为单位（0..n-1），与布局解耦。
  // 注意必须用 TickerProviderStateMixin：本 State 同时持有两个
  // ticker（弹簧 _ticker + 按压 _pressCtrl），SingleTicker 版本会在
  // 第一次按住导航条（_ticker 懒创建）时抛"multiple tickers"断言。
  static const double _stiffness = 190;
  static const double _damping = 24;
  static const double _maxDt = 1 / 30;

  late final Ticker _ticker = createTicker(_onTick);
  Duration? _lastElapsed;
  double _pos = 0;
  double _vel = 0;
  double _target = 0;

  /// 按压强度（0→1），驱动胶囊充气与图标反馈的淡入淡出
  late final AnimationController _pressCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
    reverseDuration: const Duration(milliseconds: 200),
  )..addListener(_onVisualTick);

  /// 按住期间手指所在的项；null = 未按下或已取消
  int? _pointerIndex;
  bool _pressed = false;
  bool _cancelled = false;

  /// 每个导航项与条 Stack 的实测锚点：胶囊落点直接对齐到项的真实
  /// 中心而不是公式推算的格心——布局里任何隐性偏差（header、
  /// 约束不对称）都会被实测自动吸收，保证"永远居中于项"。
  final List<GlobalKey> _itemKeys = [];
  final GlobalKey _stackKey = GlobalKey();

  /// 最近一次布局的格心尺寸（实测锚点不可用时的退回值）
  double? _cellSize;

  /// 最近一次布局的主轴总长
  ///
  /// 窗口最大化/缩放那一帧，LayoutBuilder 先于子项布局执行，实测锚点拿到的是
  /// 上一帧的几何；用「新 cell 算长度 + 旧几何算中心」摆出的胶囊会跑偏。
  double? _lastMainSize;

  @override
  void initState() {
    super.initState();
    _pos = _target = widget.currentIndex.toDouble();
    _syncKeys();
  }

  void _syncKeys() {
    while (_itemKeys.length < widget.items.length) {
      _itemKeys.add(GlobalKey());
    }
  }

  @override
  void didUpdateWidget(covariant LiquidPillNavBar old) {
    super.didUpdateWidget(old);
    _syncKeys();
    //外部切页（引导/通知/快捷键/返回键）：未按住时胶囊弹到新页
    if (widget.currentIndex != old.currentIndex && !_pressed) {
      _setTarget(widget.currentIndex.toDouble());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onVisualTick() {
    if (mounted) setState(() {});
  }

  void _setTarget(double t) {
    if ((t - _target).abs() < 0.0005) return;
    _target = t;
    if (!_ticker.isActive) {
      _lastElapsed = null;
      _ticker.start();
    }
  }

  /// 逐帧半隐式欧拉积分弹簧（双子步，稳定且速度连续）
  void _onTick(Duration elapsed) {
    final dt = _lastElapsed == null
        ? 1 / 120
        : ((elapsed - _lastElapsed!).inMicroseconds / 1e6).clamp(
            0.0005,
            _maxDt,
          );
    _lastElapsed = elapsed;
    final h = dt / 2;
    for (var s = 0; s < 2; s++) {
      final acc = _stiffness * (_target - _pos) - _damping * _vel;
      _vel += acc * h;
      _pos += _vel * h;
    }
    if ((_target - _pos).abs() < 0.0008 && _vel.abs() < 0.004) {
      _pos = _target;
      _vel = 0;
      _ticker.stop();
    }
    if (mounted) setState(() {});
  }

  double _mainOf(Offset local) =>
      widget.axis == Axis.horizontal ? local.dx : local.dy;

  /// 弹簧位置（小数项索引）→ 条内主轴坐标。优先用相邻两项的**实测**
  /// 中心插值（展开/非展开、有无 header 都天然对齐）；首帧尚未完成
  /// 布局时退回格心公式。
  double _centerAt(double pos) {
    final horizontal = widget.axis == Axis.horizontal;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final n = widget.items.length;
    final cell = _cellSize ?? 0;
    if (stackBox == null || n == 0) {
      return pos * cell + cell / 2;
    }
    final i = pos.clamp(0.0, n - 1.0);
    final lo = i.floor();
    final hi = math.min(lo + 1, n - 1);
    final frac = i - lo;
    double? mainCenter(int idx) {
      final box =
          _itemKeys[idx].currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return null;
      final top = box.localToGlobal(Offset.zero, ancestor: stackBox);
      //主轴中心 = 主轴起点 + 主轴半宽。横向主轴是 x（加 width/2），
      //纵向是 y（加 height/2）；此前横向误加 height/2（条高一半），
      //格宽大于条高时（Windows 宽窗口 ≈210 vs 56）胶囊整体偏左。
      return (horizontal ? top.dx : top.dy) +
          (horizontal ? box.size.width : box.size.height) / 2;
    }

    final a = mainCenter(lo);
    final b = mainCenter(hi);
    if (a == null || b == null) return i * cell + cell / 2;
    return a + (b - a) * frac;
  }

  int _indexFromMain(double main, double cell) {
    //首帧/窗口最小化时 cell 可能是 0，除零会得到 inf/NaN，
    //.floor() 对非有限值直接抛 UnsupportedError（整条导航构建失败）；
    //items 为空时 clamp(0, -1) 上下限颠倒同样抛错
    final n = widget.items.length;
    if (n == 0 || !cell.isFinite || cell <= 0 || !main.isFinite) return 0;
    final idx = (main / cell).floor();
    if (!idx.isFinite) return 0;
    return idx.clamp(0, n - 1);
  }

  void _onPointerDown(Offset local, double cell) {
    _pressed = true;
    _cancelled = false;
    _pointerIndex = _indexFromMain(_mainOf(local), cell);
    _pressCtrl.forward();
    _setTarget(_pointerIndex!.toDouble());
    if (PlatformAdapt.isMobile) HapticFeedback.selectionClick();
  }

  void _onPointerMove(
    Offset local,
    double cell,
    double mainSize,
    double crossSize,
  ) {
    if (!_pressed) return;
    final main = _mainOf(local);
    final cross = widget.axis == Axis.horizontal ? local.dy : local.dx;
    //拖出条外过远：取消本次选择（松手不切页，胶囊弹回当前项）
    final outMain = main < -cell * 0.6 || main > mainSize + cell * 0.6;
    final outCross = cross < -crossSize * 0.6 || cross > crossSize * 1.6;
    if (outMain || outCross) {
      if (!_cancelled) {
        _cancelled = true;
        _pointerIndex = null;
        _pressCtrl.reverse();
        _setTarget(widget.currentIndex.toDouble());
      }
      return;
    }
    if (_cancelled) {
      //从条外拖回来：恢复按压态
      _cancelled = false;
      _pressCtrl.forward();
    }
    final idx = _indexFromMain(main, cell);
    if (idx != _pointerIndex) {
      _pointerIndex = idx;
      _setTarget(idx.toDouble());
      if (PlatformAdapt.isMobile) HapticFeedback.selectionClick();
    }
  }

  void _onPointerUp() {
    if (!_pressed) return;
    _pressed = false;
    _pressCtrl.reverse();
    final idx = _cancelled ? null : _pointerIndex;
    _pointerIndex = null;
    if (idx != null && idx != widget.currentIndex) {
      if (PlatformAdapt.isMobile) HapticFeedback.lightImpact();
      //先落位再回调：父组件随后更新 currentIndex 时 didUpdateWidget 幂等
      _setTarget(idx.toDouble());
      widget.onChanged(idx);
    } else {
      //原地松手/取消：胶囊弹回当前项
      _setTarget(widget.currentIndex.toDouble());
    }
  }

  void _onPointerCancel() {
    if (!_pressed) return;
    _pressed = false;
    _pointerIndex = null;
    _pressCtrl.reverse();
    _setTarget(widget.currentIndex.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final horizontal = widget.axis == Axis.horizontal;
    final strip = _buildStrip(isDark);
    final radius = BorderRadius.circular(horizontal ? 30 : 28);
    final padding = horizontal
        ? const EdgeInsets.symmetric(horizontal: 5, vertical: 5)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 10);
    final child = horizontal
        ? SizedBox(height: 56, child: strip)
        : Column(
            //展开模式撑满父高度（侧栏通高面板），否则按项数定高
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (widget.header != null) ...[
                widget.header!,
                const SizedBox(height: 12),
              ],
              if (widget.expand)
                Expanded(child: strip)
              else
                SizedBox(height: widget.items.length * 56.0, child: strip),
            ],
          );

    // Windows：Impeller 的 backdrop 采样在 bottomNavigationBar 槽位渲染
    // 失败（整块变灰、内容画不出，见项目内已知记录）。问题**仅限该槽位**：
    // body 内的 GlassSurface（全站卡片/弹窗）在 Windows 上渲染正常。
    // 因此只有横向条（挂在 bottomNavigationBar 槽位）继续用无 backdrop 的
    // 磨砂玻璃胶囊（半透明 + 受光描边 + 投影，纯普通绘制，不依赖滤镜）；
    // 纵向侧栏挂在 body 内，改走实时模糊玻璃——侧栏背后没有页面内容滑过
    // （内容区让开了侧栏宽度），若同样叠厚白纱只会显得发实不透（用户反馈
    // "侧栏不够透"），实时模糊让光斑背景直接透过玻璃，与底部观感一致。
    if (PlatformAdapt.isWindows && horizontal) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.62),
          borderRadius: radius,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.72),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.10),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      );
    }

    return GlassSurface(
      borderRadius: horizontal ? 30 : 28,
      blurSigma: LiquidGlass.blurSigmaHeavy,
      //纵向侧栏整体定宽
      width: horizontal ? null : 84,
      padding: padding,
      child: child,
    );
  }

  Widget _buildStrip(bool isDark) {
    final horizontal = widget.axis == Axis.horizontal;
    return LayoutBuilder(
      builder: (context, c) {
        final n = widget.items.length;
        //空列表短路：下面 cell 会出现除零(inf/NaN)，经 Positioned 触发构建期异常；
        //与 _indexFromMain 里"items 为空"的保护同源
        if (n == 0) return const SizedBox.shrink();
        final mainSize = horizontal ? c.maxWidth : c.maxHeight;
        final crossSize = horizontal ? c.maxHeight : c.maxWidth;
        final cell = mainSize / n;
        _cellSize = cell;
        //尺寸变化（最大化/缩放）那一帧补一帧重建：本帧的实测锚点还是旧几何，
        //而胶囊长度已按新 cell 计算，摆出来就是"选中框往上变长"；布局结束后
        //重建一次即可用新几何把胶囊摆正（否则要等切页触发重建才恢复）
        if (_lastMainSize != mainSize) {
          _lastMainSize = mainSize;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _onPointerDown(e.localPosition, cell),
          onPointerMove: (e) =>
              _onPointerMove(e.localPosition, cell, mainSize, crossSize),
          onPointerUp: (_) => _onPointerUp(),
          onPointerCancel: (_) => _onPointerCancel(),
          child: AnimatedBuilder(
            animation: _pressCtrl,
            builder: (context, _) {
              final press = Curves.easeOut.transform(_pressCtrl.value);
              //胶囊中心 = 弹簧位置（实测项中心插值，天然与内容对齐）；
              //充气（按压）+ 依据速度的挤压拉伸
              final center = _centerAt(_pos);
              final stretch = (_vel.abs() * 0.055).clamp(0.0, 0.30);
              final inflate = 1.0 + 0.14 * press;
              //展开模式（通高侧栏）：参照底部条的几何——选中框几乎铺满
              //该项整格（底部条每格 56 时框占 ≈49，即 ~88%），框的边界
              //就是项的边界，视觉上永远与内容对齐。长轴按 cell*0.88，
              //截面与底部条同宽（56*0.88≈49）；静止时不充气不拉伸，
              //保证任何窗口高度下都是同一套比例。
              final fillMode = !horizontal && widget.expand;
              final pillMain = fillMode
                  ? cell * 0.88
                  // 封顶 0.94×cell：充气(1.14)叠加拉伸(最大 1.3)后造型系数
                  // 可达 1.27×cell，宽窗口下高亮胶囊会溢出所在项的边界
                  : math.min(
                      cell * 0.86 * inflate * (1.0 + stretch * press),
                      cell * 0.94,
                    );
              //胶囊截面不能超过条宽。注意不能用
              //`.clamp(cell * 0.55, crossSize * 0.98)`：条很宽时
              //cell*0.55 会大于 crossSize*0.98（下限>上限，clamp 抛
              //ArgumentError，整个导航条构建失败——Windows 上表现为
              //导航条消失/灰带、图标全无）。上限只做封顶，不设下限。
              final pillCross = math.min(
                fillMode
                    ? 49.0
                    : cell * 0.86 * inflate * (1.0 - stretch * 0.35 * press),
                crossSize * 0.98,
              );
              return Stack(
                key: _stackKey,
                clipBehavior: Clip.none,
                children: [
                  //玻璃高亮胶囊
                  Positioned(
                    left: horizontal
                        ? center - pillMain / 2
                        : (crossSize - pillCross) / 2,
                    top: horizontal
                        ? (crossSize - pillCross) / 2
                        : center - pillMain / 2,
                    width: horizontal ? pillMain : pillCross,
                    height: horizontal ? pillCross : pillMain,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: LiquidGlass.accentTint(
                          FluidTheme.primaryFluidGradient[0],
                          isDark,
                        ),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  //导航项（展开模式用 Expanded 均分主轴，否则按 cell 定宽/定高）
                  if (horizontal)
                    Row(
                      children: [
                        for (var i = 0; i < n; i++)
                          SizedBox(
                            width: cell,
                            height: crossSize,
                            child: _buildItem(i, _pos, press, isDark),
                          ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0; i < n; i++)
                          widget.expand
                              ? Expanded(
                                  //Expanded 只锁主轴，截面必须显式定宽：
                                  //否则内容列收缩包裹、Stack 收缩到最宽
                                  //标签宽度，而胶囊 left 按整条宽(crossSize)
                                  //推算，高亮胶囊会横向偏出项的中线
                                  child: SizedBox(
                                    width: crossSize,
                                    child: _buildItem(i, _pos, press, isDark),
                                  ),
                                )
                              : SizedBox(
                                  width: crossSize,
                                  height: cell,
                                  child: _buildItem(i, _pos, press, isDark),
                                ),
                      ],
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// 单个导航项：图标 + 标签，靠近胶囊时平滑放大、着色
  Widget _buildItem(int i, double pillPos, double press, bool isDark) {
    final item = widget.items[i];
    final selected = i == widget.currentIndex;
    final hovered = _pressed && !_cancelled && i == _pointerIndex;
    final active = selected || hovered;
    final color = active
        ? item.activeColor
        : FluidTheme.getTextTertiaryColor(isDark);
    //距离胶囊越近放大越多（二次缓动），只在整个条上连续变化，无跳变
    final d = (i - pillPos).abs().clamp(0.0, 1.0);
    final falloff = (1 - d) * (1 - d);
    final scale = 1.0 + 0.11 * falloff * press;
    return Semantics(
      key: _itemKeys[i],
      button: true,
      selected: selected,
      label: item.label,
      // 提供语义动作：导航项用裸 Listener 实现指针交互，不给 onTap 语义
      // 时读屏只能播报"按钮"却无法激活（TalkBack 双击无反应、Tab 键不可用）
      onTap: () {
        if (i == widget.currentIndex) return;
        _setTarget(i.toDouble());
        widget.onChanged(i);
      },
      excludeSemantics: true,
      child: Transform.scale(
        scale: scale,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? item.activeIcon : item.icon, size: 22, color: color),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.0,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
