import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_initialization_service.dart';
import '../services/guide_service.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import 'liquid_glass.dart';

/// 单步上下文引导：高亮某个控件并在旁边弹出说明气泡。
class CoachMarkStep {
  /// 需要高亮的目标控件 Key（须已完成布局）
  final GlobalKey targetKey;
  final String title;
  final String message;
  final IconData icon;

  /// 该步骤所在的目标底部 Tab 序号。
  ///
  /// 非空时，进入这一步会先请求切换 Tab（由 HomeScreen 执行）并留出切换缓冲，
  /// 让引导可以带着用户一路走完首页 → 词库 → 阅读 → 统计。
  final int? tabIndex;

  /// 进入这一步时的收尾动作，用来把高亮目标"摆好"再展示。
  ///
  /// 典型场景是长页面里靠下的锚点：控件虽然已经完成布局（如
  /// `SingleChildScrollView` 的子节点），但它可能还在可视区域之外，
  /// 直接高亮会指着屏幕外。传入 `Scrollable.ensureVisible` 之类的回调，
  /// 气泡会在滚动动画结束后再定位。
  final VoidCallback? onEnter;

  /// 气泡固定居中显示，不再贴着高亮目标上下排布。
  ///
  /// 目标锚点位于长页面（设置页这类滚动页）时，气泡被算法推到屏幕底部，
  /// 与锚点隔着大半屏内容，"这条提示在说哪一块"很难看清；
  /// 这类**纯说明性**的单步提示直接居中更好读。
  final bool centerBubble;

  const CoachMarkStep({
    required this.targetKey,
    required this.title,
    required this.message,
    this.icon = Icons.tips_and_updates_outlined,
    this.tabIndex,
    this.onEnter,
    this.centerBubble = false,
  });
}

/// 上下文引导（coach mark）遮罩。
///
/// 以全屏半透明遮罩 + 目标控件镂空高亮 + 说明气泡的形式介绍关键操作；
/// 一组步骤按顺序连播，需要跨 Tab 时自动切换页面。
/// 气泡与遮罩均为双风格：液态玻璃模式使用玻璃片，经典模式使用描边卡片。
class CoachMarkOverlay {
  CoachMarkOverlay._();

  /// 该引导是否已看过；未看过则播放一次，看完自动记录到 [GuideService]。
  ///
  /// [steps] 在真正展示时才求值，保证「有没有词库」这类依赖运行时状态的判断
  /// 是当下最新的。[onFinish] 用于播放结束后的收尾（如切回首页）。
  static Future<void> maybeShow(
    BuildContext context, {
    required String guideId,
    required List<CoachMarkStep> Function() steps,
    VoidCallback? onFinish,
  }) async {
    if (await GuideService.isSeen(guideId)) return;
    if (!context.mounted) return;
    showWhenReady(
      context,
      stepsBuilder: steps,
      guideId: guideId,
      onFinish: onFinish,
    );
  }

  /// 与 [maybeShow] 同语义的「只提示一次」，但更保守：
  /// 开屏动画尚未结束时直接放弃本次展示，也不把引导标记成已看过，
  /// 留到下次进入该页面再提示。
  ///
  /// 学习页、阅读页这类跟随具体页面的功能提示用它：这些页面出现在开屏之后，
  /// 正常流程都能等到开屏结束；万一没等到，也不该在开屏遮罩之上强弹一次，
  /// 更不该让用户从此再也看不到这条提示。
  ///
  /// [onBeforeShow] 在确认要展示后的最后一刻调用，用于把「高亮锚点」固定下来
  /// （如阅读页锁定当前词条下标），保证高亮目标不会在后续翻页中来回换控件。
  static Future<void> maybeShowAfterSplash(
    BuildContext context, {
    required String guideId,
    required List<CoachMarkStep> Function() steps,
    VoidCallback? onBeforeShow,
  }) async {
    if (await GuideService.isSeen(guideId)) return;
    if (!context.mounted) return;
    if (!AppInitializationService.splashCompleted.value) return;
    onBeforeShow?.call();
    showWhenReady(context, stepsBuilder: steps, guideId: guideId);
  }

  /// 当前正在展示的引导路由。
  ///
  /// 单例闸门：引导学生层的入口都带异步间隙（`GuideService.isSeen` 是
  /// SharedPreferences 读、"重看功能提示"前还有 600ms 等待），连点同一个
  /// Tab / 连点重看按钮会插进第二层全屏遮罩 —— 用户得连点两次"完成"才能
  /// 回到页面，高亮锚点也可能落在错误位置。
  static Route<void>? _activeRoute;

  /// 是否有引导正在展示
  static bool get isShowing => _activeRoute != null;

  /// 用透明全屏路由展示一组引导步骤。
  ///
  /// 必须走路由，不能直接往根 Overlay 插 OverlayEntry：OverlayEntry 的子树
  /// 没有 ModalRoute 祖先，_CoachMarkHost 里的 PopScope 不会向任何路由注册，
  /// Android 返回键会穿透遮罩把底层页面 pop 掉，遮罩则停在已消失的页面上。
  static void show(
    BuildContext context, {
    required List<CoachMarkStep> steps,
    VoidCallback? onFinish,
    VoidCallback? onAbort,
  }) {
    if (steps.isEmpty) return;
    if (_activeRoute != null) return; // 已有一层在展示：忽略本次
    final navigator = Navigator.maybeOf(context, rootNavigator: true);
    if (navigator == null) return;

    late final Route<void> route;
    var finished = false;
    void finish(VoidCallback? callback) {
      if (finished) return;
      finished = true;
      if (identical(_activeRoute, route)) _activeRoute = null;
      //立即摘除、不走退场动画：与旧的 OverlayEntry.remove() 行为一致
      if (route.isActive) navigator.removeRoute(route);
      callback?.call();
    }

    route = PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => _CoachMarkHost(
        steps: steps,
        onFinish: () => finish(onFinish),
        onAbort: onAbort == null ? null : () => finish(onAbort),
      ),
    );
    _activeRoute = route;
    //兜底：路由被外部（如别处 popUntil）摘掉时也要释放单例闸门，
    //否则后续所有引导都会被永久挡住
    navigator.push<void>(route).whenComplete(() {
      if (identical(_activeRoute, route)) _activeRoute = null;
    });
  }

  /// 目标控件是否已完成布局
  static bool isReady(GlobalKey key) {
    final targetContext = key.currentContext;
    if (targetContext == null) return false;
    final renderObject = targetContext.findRenderObject();
    return renderObject is RenderBox &&
        renderObject.hasSize &&
        !renderObject.size.isEmpty;
  }

  /// 等开屏动画结束、且首个目标控件完成布局后再展示。
  ///
  /// 首次进入页面时数据可能还在加载（目标控件尚未挂载），此时直接展示会得到
  /// 空高亮；开屏动画覆盖期间展示则会高亮到被遮盖的位置。因此这里按帧轮询等待，
  /// 超过 [timeout] 后无论如何都展示一次，避免提示永远不来。
  static void showWhenReady(
    BuildContext context, {
    required List<CoachMarkStep> Function() stepsBuilder,
    required String guideId,
    VoidCallback? onFinish,
    Duration timeout = const Duration(seconds: 8),
  }) {
    final deadline = DateTime.now().add(timeout);
    var tabRequested = false;
    var shown = false;
    Timer? retryTimer;
    Timer? kickTimer;

    void attempt() {
      // Timer 兜底与帧回调可能先后各跑一次，show 过就不再进入
      if (shown || !context.mounted) {
        kickTimer?.cancel();
        return;
      }

      // 等待开屏结束/目标挂载用低频轮询：逐帧 scheduleFrame 会让整机在
      // 最长 8 秒的等待期里持续满帧渲染，且完全看不出差别
      void scheduleRetry() {
        retryTimer?.cancel();
        retryTimer = Timer(const Duration(milliseconds: 100), () {
          if (context.mounted) attempt();
        });
      }

      final expired = DateTime.now().isAfter(deadline);
      // 开屏未结束且未超时：继续等
      if (!AppInitializationService.splashCompleted.value && !expired) {
        scheduleRetry();
        return;
      }
      final steps = stepsBuilder();
      if (steps.isEmpty) return;
      // 首步可能落在别的 Tab 上：切过去一次即可，避免重复请求
      final firstTab = steps.first.tabIndex;
      if (!tabRequested && firstTab != null) {
        tabRequested = true;
        GuideService.requestTab(firstTab);
      }
      if (isReady(steps.first.targetKey) || expired) {
        shown = true;
        retryTimer?.cancel();
        kickTimer?.cancel();
        show(
          context,
          steps: steps,
          onFinish: () {
            GuideService.markSeen(guideId);
            onFinish?.call();
          },
        );
        return;
      }
      scheduleRetry();
    }

    // 首发驱动不能只靠帧回调：新手引导刚结束、首页完全静止（Android 无
    // 循环动效）时不会再产生新帧，postFrame 回调会一直挂着不执行——
    // 表现为"点一下屏幕（触发按压动画产帧）才弹功能提示"。
    // Timer 由事件循环驱动、与帧无关，作为首发驱动；后到的 attempt 靠
    // shown 标志幂等跳过。
    kickTimer = Timer(const Duration(milliseconds: 120), () {
      if (context.mounted) attempt();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }
}

class _CoachMarkHost extends StatefulWidget {
  final List<CoachMarkStep> steps;
  final VoidCallback onFinish;

  /// 目标挂载超时时的结束路径：与 [onFinish] 的区别是不标记"已看过"，
  /// 让这次没显示成功的引导下次进入时还能补上
  final VoidCallback? onAbort;

  const _CoachMarkHost({
    required this.steps,
    required this.onFinish,
    this.onAbort,
  });

  @override
  State<_CoachMarkHost> createState() => _CoachMarkHostState();
}

class _CoachMarkHostState extends State<_CoachMarkHost> {
  /// 切页后的缓冲时间：让用户看清"跳到了哪个 Tab"再弹气泡
  static const Duration _settleDelay = Duration(milliseconds: 420);

  int _index = 0;
  DateTime? _settleUntil;
  bool _settling = false;

  /// 等待目标就位的低频轮询定时器（避免逐帧强制出帧）
  Timer? _retryTimer;

  /// 本次等待目标挂载的起始时间；超过 [_maxWaitForTarget] 就放弃高亮
  DateTime? _waitStartedAt;

  /// 等待锚点挂载的最长时间：超时后气泡改为居中展示，
  /// 避免锚点永远不出现时遮罩一直盖住界面
  static const Duration _maxWaitForTarget = Duration(seconds: 8);

  /// 气泡本体，用于测量真实高度
  final GlobalKey _bubbleKey = GlobalKey();

  /// 当前这一步气泡的实测高度；null 表示还没量到（首帧按估值定位）
  double? _bubbleHeight;

  /// 量一次气泡高度。
  ///
  /// 每条提示的文案长短不一，只有拿到真实高度才能判断"能不能完整地
  /// 放在目标下方"，否则遇到长文案就会伸出屏幕底部被裁掉。
  /// 放在帧回调里测量，量到之后再重建一次定位。
  void _scheduleBubbleMeasure() {
    if (_bubbleHeight != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _bubbleHeight != null) return;
      final box = _bubbleKey.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || box.size.height <= 0) return;
      setState(() => _bubbleHeight = box.size.height);
    });
  }

  CoachMarkStep get _step => widget.steps[_index];
  bool get _isLast => _index == widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _enterStep();
  }

  /// 进入当前步骤：必要时先切换 Tab / 滚动到目标，然后等待目标控件就位
  void _enterStep() {
    final tab = _step.tabIndex;
    final onEnter = _step.onEnter;
    if (tab != null) {
      GuideService.requestTab(tab);
      _settleUntil = DateTime.now().add(_settleDelay);
      _settling = true;
    } else {
      _settleUntil = null;
    }
    if (onEnter != null) {
      // 滚动动画同样需要缓冲，否则气泡会先落在旧位置上
      _settleUntil = DateTime.now().add(_settleDelay);
      _settling = true;
      onEnter();
    }
    _awaitTarget();
  }

  void _awaitTarget() {
    if (!mounted) return;

    void retryFrame() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _awaitTarget();
      });
      WidgetsBinding.instance.scheduleFrame();
    }

    //等待目标挂载用低频轮询即可：挂载与否由某次 build 决定，
    //逐帧 scheduleFrame 会让整个等待期持续满帧渲染（最长可达数秒）
    void retryLater() {
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(milliseconds: 80), () {
        if (mounted) _awaitTarget();
      });
    }

    final settleUntil = _settleUntil;
    if (settleUntil != null && DateTime.now().isBefore(settleUntil)) {
      // 缓冲期间逐帧重建：切 Tab / 滚动时目标一直在动，气泡与镂空要跟着走，
      // 否则会短暂停在上一帧的位置上。放在帧回调里是为了不依赖当前
      // 是否处于 initState（首步进入时就还在首帧内）。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      retryFrame();
      return;
    }
    if (!CoachMarkOverlay.isReady(_step.targetKey)) {
      final startedAt = _waitStartedAt ??= DateTime.now();
      if (DateTime.now().difference(startedAt) > _maxWaitForTarget) {
        // 目标始终没有挂载（页面状态变化把入口去掉了、或锚点 Key 失效）：
        // 直接结束引导，否则全屏遮罩会一直盖着界面，按钮全部点不动。
        // 必须走 onAbort 而不是 onFinish：onFinish 会 markSeen，等于
        // "一次都没显示却把提示永久标记为已看过"。
        _retryTimer?.cancel();
        if (widget.onAbort != null) {
          widget.onAbort!();
        } else {
          widget.onFinish();
        }
        return;
      }
      if (!_settling) setState(() => _settling = true);
      retryLater();
      return;
    }
    _retryTimer?.cancel();
    _settleUntil = null;
    _waitStartedAt = null;
    if (_settling) setState(() => _settling = false);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onFinish();
      return;
    }
    setState(() {
      _index++;
      // 下一步的文案长短不同，高度要重新量
      _bubbleHeight = null;
      // 新步骤的"等待锚点"计时独立计算
      _waitStartedAt = null;
    });
    _enterStep();
  }

  /// 读取目标控件的全局位置与尺寸；未完成布局时返回 null。
  Rect? _targetRect() {
    final targetContext = _step.targetKey.currentContext;
    if (targetContext == null) return null;
    final renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final glass = context.select<ThemeProvider, bool>((p) => p.isLiquidGlass);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    const accent = Color(0xFF6366F1);

    final screen = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final rect = _targetRect();

    // 气泡宽度：窄屏铺满留边，宽屏限制最大宽度
    final bubbleWidth = (screen.width - 32).clamp(200.0, 340.0);

    // 气泡与高亮框之间的留白
    const bubbleGap = 16.0;
    // 气泡高度还没量到时的估值：只影响首帧，量到后立刻校正
    const estimatedBubbleHeight = 200.0;
    final bubbleHeight = _bubbleHeight ?? estimatedBubbleHeight;

    // 屏幕内可用的竖直范围：气泡必须整体落在里面，否则会被系统栏或屏幕边缘
    // 裁掉（"有些引导显示不全"就是长文案气泡伸出了下边缘）
    final availableTop = safe.top + 8;
    final availableBottom = screen.height - safe.bottom - 8;
    final maxBubbleHeight = (availableBottom - availableTop).clamp(
      120.0,
      screen.height,
    );

    // 居中展示的提示不需要贴着锚点排布
    final centerBubble = _step.centerBubble;

    double? bubbleTop;
    double? bubbleLeft;
    if (rect != null && !centerBubble) {
      bubbleLeft = (rect.center.dx - bubbleWidth / 2).clamp(
        16.0,
        (screen.width - bubbleWidth - 16).clamp(16.0, screen.width),
      );
      final spaceBelow = availableBottom - rect.bottom - bubbleGap;
      final spaceAbove = rect.top - availableTop - bubbleGap;
      final fitsBelow = spaceBelow >= bubbleHeight;
      final fitsAbove = spaceAbove >= bubbleHeight;
      // 下方放得下就放下方；两边都放不下时选更宽裕的一侧，
      // 再把气泡拉进可用范围，保证整块可见
      final desiredTop = fitsBelow || (!fitsAbove && spaceBelow >= spaceAbove)
          ? rect.bottom + bubbleGap
          : rect.top - bubbleGap - bubbleHeight;
      final maxTop = math.max(availableTop, availableBottom - bubbleHeight);
      bubbleTop = desiredTop.clamp(availableTop, maxTop);
    }
    // 气泡比可用空间还高时才需要内部滚动（极长文案 + 小屏）
    final bubbleOverflows = bubbleHeight > maxBubbleHeight;

    final bubble = KeyedSubtree(
      key: _bubbleKey,
      child: _buildBubble(
        isDark: isDark,
        glass: glass,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
      ),
    );
    // 量到真实高度后重排一次，把气泡完整放进屏幕
    _scheduleBubbleMeasure();

    return PopScope(
      canPop: false,
      // Android 返回键＝跳过本次引导。
      // 此前 canPop:false 且没有回调，引导层显示期间返回键完全无响应，
      // 单步引导时连"跳过"按钮都不显示，用户会以为界面卡死。
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onFinish();
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _next,
                child: CustomPaint(
                  painter: _SpotlightPainter(
                    rect: rect,
                    dimColor: Colors.black.withValues(
                      alpha: isDark ? 0.72 : 0.62,
                    ),
                    glowColor: accent.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
            if (rect != null && !centerBubble)
              Positioned(
                left: bubbleLeft,
                top: bubbleTop,
                width: bubbleWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxBubbleHeight),
                  // 极长文案在小屏上仍可能超出可用高度，此时气泡内部滚动，
                  // 「跳过 / 知道了」按钮始终点得到
                  child: bubbleOverflows
                      ? SingleChildScrollView(child: bubble)
                      : bubble,
                ),
              )
            else
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: bubbleWidth,
                    maxHeight: maxBubbleHeight,
                  ),
                  child: bubbleOverflows
                      ? SingleChildScrollView(child: bubble)
                      : bubble,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble({
    required bool isDark,
    required bool glass,
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
  }) {
    final counterText = '${_index + 1}/${widget.steps.length}';

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.24 : 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_step.icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _step.title,
                  style: FluidTheme.labelLarge(isDark).copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _step.message,
            style: FluidTheme.bodySmall(
              isDark,
            ).copyWith(color: textSecondary, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                counterText,
                style: FluidTheme.bodySmall(
                  isDark,
                ).copyWith(color: textSecondary),
              ),
              const Spacer(),
              // 始终提供跳过入口，单步引导也要能随时退出，避免用户以为界面卡死
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onFinish,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Text(
                    context.tr.skip,
                    style: FluidTheme.bodySmall(isDark).copyWith(
                      color: FluidTheme.primaryAccessible(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _CoachPillButton(
                label: _isLast ? context.tr.coachDone : context.tr.nextStep,
                accent: accent,
                onPressed: _next,
              ),
            ],
          ),
        ],
      ),
    );

    if (glass) {
      return GlassSurface(
        borderRadius: 20,
        padding: EdgeInsets.zero,
        emphasized: true,
        grain: true,
        glowColor: accent,
        child: content,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: FluidTheme.getElevatedSurfaceColor(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.45 : 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: content,
    );
  }
}

/// 遮罩 + 目标镂空 + 边缘发光
class _SpotlightPainter extends CustomPainter {
  final Rect? rect;
  final Color dimColor;
  final Color glowColor;

  _SpotlightPainter({
    required this.rect,
    required this.dimColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final target = rect?.inflate(8);
    if (target == null) {
      canvas.drawRect(full, Paint()..color = dimColor);
      return;
    }
    final rrect = RRect.fromRectAndRadius(target, const Radius.circular(18));
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(full),
      Path()..addRRect(rrect),
    );
    canvas.drawPath(path, Paint()..color = dimColor);
    // 高亮边缘：柔光描边，让目标控件从遮罩里"浮"出来
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = glowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.rect != rect ||
      old.dimColor != dimColor ||
      old.glowColor != glowColor;
}

/// 气泡右下角的胶囊按钮：玻璃模式用发光胶囊，经典模式用渐变胶囊
class _CoachPillButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onPressed;

  const _CoachPillButton({
    required this.label,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isLiquidGlass) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: GlowCapsule(
          color: accent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, accent.withValues(alpha: 0.78)],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
