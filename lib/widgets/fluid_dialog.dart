import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/fluid_theme.dart';
import '../services/providers/theme_provider.dart';
import '../utils/color_utils.dart';
import 'fluid_button.dart';
import 'liquid_glass.dart';

/// 流体对话框组件
///
/// 特性：
/// - 支持深浅色主题
/// - 弹簧物理弹出动画
/// - 流体渐变边框
/// - Shimmer光泽效果
class FluidDialog extends StatefulWidget {
  final Widget content;
  final String? title;
  final List<Widget>? actions;
  final bool barrierDismissible;
  final double? width;
  final double? maxWidth;

  /// 内容区是否可滚动；滚轮选择器等嵌套滚动场景应关闭
  final bool scrollable;

  /// 标题栏右侧的动作位（如目录弹窗的搜索按钮）。
  ///
  /// 与 [actions]（底部按钮区）不同，这里紧贴标题右侧，
  /// 适合"对整个弹窗内容生效"的低频动作。
  final Widget? titleTrailing;

  /// 回车键触发的「确定」动作。
  ///
  /// 不传时回退到 [actions] 的最后一个动作（Material 惯例：肯定操作放最后），
  /// 「确定」按钮写在 [content] 里的弹窗（如周期选择器、时间选择器）
  /// 需要显式传入。
  final VoidCallback? onConfirm;

  const FluidDialog({
    super.key,
    required this.content,
    this.title,
    this.actions,
    this.barrierDismissible = true,
    this.width,
    this.maxWidth,
    this.scrollable = true,
    this.titleTrailing,
    this.onConfirm,
  });

  @override
  State<FluidDialog> createState() => _FluidDialogState();
}

class _FluidDialogState extends State<FluidDialog>
    with TickerProviderStateMixin {
  late AnimationController _jellyController;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  /// 承载「回车=确定」的焦点节点
  final FocusNode _confirmFocusNode = FocusNode(
    debugLabel: 'FluidDialogConfirm',
  );

  @override
  void initState() {
    super.initState();

    //两种风格共用的果冻入场：真实弹簧驱动，底部上弹并带挤压形变
    _jellyController = AnimationController(vsync: this);
    LiquidMotion.run(_jellyController, spring: LiquidMotion.jellyEntrance);

    _shimmerController = AnimationController(
      duration: FluidTheme.shimmerDuration,
      vsync: this,
    );

    _shimmerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_shimmerController);

    // 弹窗内若没有任何控件获得焦点（如只展示按钮的提示弹窗），
    // 需要把焦点收到弹窗根节点上，回车键才能冒泡到「确定」处理。
    // 先等一帧：让内容里的 autofocus（输入框、滚轮）先生效，绝不抢走它们的焦点。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final primary = FocusManager.instance.primaryFocus;
        final inside =
            primary != null &&
            (primary == _confirmFocusNode ||
                _confirmFocusNode.descendants.contains(primary));
        if (!inside) _confirmFocusNode.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _jellyController.dispose();
    _shimmerController.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  /// 回车键触发「确定」；Esc 关闭由路由默认处理
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    // 输入框里的回车交给输入框自己处理（换行或 onSubmitted），避免重复提交
    if (_isTextFieldHandlingEnter()) return KeyEventResult.ignored;
    return _triggerConfirm() ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  /// 当前焦点是否落在输入框里（多行输入回车应换行；单行已有提交回调用回调）
  bool _isTextFieldHandlingEnter() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    final field = ctx?.findAncestorWidgetOfExactType<TextField>();
    if (field == null) return false;
    if ((field.maxLines ?? 1) != 1) return true;
    return field.onSubmitted != null;
  }

  /// 触发「确定」：优先用显式 [FluidDialog.onConfirm]，否则用最后一个动作
  bool _triggerConfirm() {
    final explicit = widget.onConfirm;
    if (explicit != null) {
      explicit();
      return true;
    }
    final actions = widget.actions;
    if (actions == null || actions.isEmpty) return false;
    final callback = _onPressedOf(actions.last);
    if (callback == null) return false;
    callback();
    return true;
  }

  /// 取出按钮的点击回调（禁用状态返回 null）
  VoidCallback? _onPressedOf(Widget action) {
    //等宽按钮常用 Row+Expanded 排布，回车确认时先解包到真正的按钮
    if (action is Row) {
      final children = action.children;
      if (children.isEmpty) return null;
      return _onPressedOf(children.last);
    }
    if (action is Expanded) return _onPressedOf(action.child);
    if (action is FluidButton) return action.onPressed;
    if (action is FluidTextButton) return action.onPressed;
    if (action is TextButton) return action.onPressed;
    if (action is FilledButton) return action.onPressed;
    if (action is ElevatedButton) return action.onPressed;
    if (action is OutlinedButton) return action.onPressed;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isMobile = screenWidth < 600;
    final dialogMaxWidth =
        widget.maxWidth ??
        (widget.width ?? (isMobile ? screenWidth * 0.92 : 480.0));
    //键盘弹起时（如带输入框的弹窗）可用高度被压缩，仍按整屏高算会把内容顶出屏幕
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxContentHeight = math.max(
      140.0,
      (screenHeight - keyboardInset) * (isMobile ? 0.68 : 0.74),
    );
    //仅深色主题循环 shimmer，避免常驻动画阻塞 pumpAndSettle
    final tickerEnabled = isDark && TickerMode.valuesOf(context).enabled;
    if (tickerEnabled && !_shimmerController.isAnimating) {
      _shimmerController.repeat();
    } else if (!tickerEnabled && _shimmerController.isAnimating) {
      _shimmerController.stop();
    }

    final isLiquidGlass = context.select<ThemeProvider, bool>(
      (p) => p.isLiquidGlass,
    );
    return Focus(
      focusNode: _confirmFocusNode,
      //可被程序化聚焦以兜住回车键，但不参与 Tab 遍历
      canRequestFocus: true,
      skipTraversal: true,
      onKeyEvent: _onKeyEvent,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 16,
          vertical: isMobile ? 24 : 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dialogMaxWidth),
          //两种风格共用同一套果冻入场：此前经典（流体渐变）模式走
          //scale 0→1 的 elasticOut，弹窗从"一个点"炸开再剧烈超调，
          //观感过于夸张；统一为玻璃模式的轻上弹+挤压回弹后，
          //同一台设备切风格时弹窗动作也保持一致。
          child: _buildJellyEntrance(
            isLiquidGlass
                ? _buildGlassDialog(isDark, maxContentHeight)
                : _buildFluidDialog(isDark, maxContentHeight),
          ),
        ),
      ),
    );
  }

  /// 果冻入场：底部上弹 + 非均匀挤压回弹 + 快速淡入
  Widget _buildJellyEntrance(Widget child) {
    return AnimatedBuilder(
      animation: _jellyController,
      builder: (context, child) {
        final t = _jellyController.value;
        final tc = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: (t * 2.4).clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, (1 - tc) * 72, 0.0, 1.0)
              //横向先微宽、竖向先压扁；超调时竖向拉伸，呈现果冻感
              ..scaleByDouble(1.05 - 0.05 * t, 0.88 + 0.12 * t, 1.0, 1.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// 液态玻璃对话框：强模糊折射 + 通透材质 + 表面噪点
  Widget _buildGlassDialog(bool isDark, double maxContentHeight) {
    return GlassSurface(
      borderRadius: FluidTheme.dialogBorderRadius,
      blurSigma: LiquidGlass.blurSigmaHeavy,
      emphasized: true,
      grain: true,
      //弹窗背后是遮罩，用更厚的纱保证可读性（否则会透出被压暗的页面而发灰）
      tint: LiquidGlass.overlayTint(isDark),
      child: _buildBody(isDark, maxContentHeight, shimmer: false),
    );
  }

  Widget _buildFluidDialog(bool isDark, double maxContentHeight) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FluidTheme.dialogBorderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FluidTheme.primaryFluidGradient[0].withValues(
              alpha: isDark ? 0.3 : 0.15,
            ),
            FluidTheme.primaryFluidGradient[2].withValues(
              alpha: isDark ? 0.1 : 0.05,
            ),
          ],
        ),
        boxShadow: FluidTheme.dialogShadow,
      ),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            FluidTheme.dialogBorderRadius - 1.5,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: FluidTheme.getSurfaceGradientColors(isDark),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            FluidTheme.dialogBorderRadius - 1.5,
          ),
          child: _buildBody(isDark, maxContentHeight, shimmer: true),
        ),
      ),
    );
  }

  Widget _buildBody(
    bool isDark,
    double maxContentHeight, {
    required bool shimmer,
  }) {
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.title != null) _buildTitle(widget.title!, isDark),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxContentHeight),
                child: widget.scrollable
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: DefaultTextStyle(
                          style: FluidTheme.textStyle(
                            isDark,
                            color: FluidTheme.getTextPrimaryColor(isDark),
                          ),
                          child: widget.content,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: DefaultTextStyle(
                          style: FluidTheme.textStyle(
                            isDark,
                            color: FluidTheme.getTextPrimaryColor(isDark),
                          ),
                          child: widget.content,
                        ),
                      ),
              ),
            ),
            if (widget.actions != null && widget.actions!.isNotEmpty)
              _buildActions(widget.actions!, isDark),
          ],
        ),
        if (isDark && shimmer) _buildShimmerEffect(),
      ],
    );
  }

  Widget _buildTitle(String title, bool isDark) {
    final textColor = FluidTheme.getTextPrimaryColor(isDark);

    Widget titleWidget;
    if (isDark) {
      titleWidget = AnimatedBuilder(
        animation: _shimmerAnimation,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(-1 + _shimmerAnimation.value * 2, 0),
                end: Alignment(1 + _shimmerAnimation.value * 2, 0),
                colors: FluidTheme.primaryFluidGradient,
              ).createShader(bounds);
            },
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          );
        },
      );
    } else {
      titleWidget = Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      );
    }

    final trailing = widget.titleTrailing;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 24, trailing == null ? 24 : 12, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: trailing == null
          ? titleWidget
          : Row(
              children: [
                Expanded(child: titleWidget),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
    );
  }

  Widget _buildActions(List<Widget> actions, bool isDark) {
    final glass = context.read<ThemeProvider>().isLiquidGlass;
    return Container(
      //撑满弹窗宽度：否则宽松约束下只按子 Wrap 收缩，按钮区底色比卡片短，左右留白突兀
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      decoration: BoxDecoration(
        //玻璃模式下按钮区保持通透，不叠不透明色块
        color: glass
            ? Colors.transparent
            : FluidTheme.getMutedOverlayColor(isDark),
        border: Border(
          top: BorderSide(
            //玻璃模式用亮白受光边，强化果冻分隔质感
            color: glass
                ? Colors.white.withValues(alpha: isDark ? 0.22 : 0.45)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1)),
            width: 1,
          ),
        ),
      ),
      // 窄屏（小尺寸 Android）上三个「内容定宽」按钮一行放不下时，
      // Row 会向右溢出并被 ClipRRect 静默裁掉最右侧按钮（如「初始化」显示不全）。
      // 改用 Wrap：放得下保持右对齐一行，放不下自动换行，任何屏宽都能完整显示。
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: actions,
      ),
    );
  }

  Widget _buildShimmerEffect() {
    // 深色弹窗标题的流光：渐变恒定，只有位移动画，提到 builder 外只算一次
    final shimmer = FluidTheme.getShimmerColor(true);
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [transparentLike(shimmer), shimmer, transparentLike(shimmer)],
      stops: const [0.0, 0.5, 1.0],
    );
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: RepaintBoundary(
            child: Transform.translate(
              offset: Offset(
                MediaQuery.sizeOf(context).width *
                    (_shimmerAnimation.value - 0.5),
                0,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: gradient),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 显示流体对话框的辅助函数
Future<T?> showFluidDialog<T>({
  required BuildContext context,
  required Widget content,
  String? title,
  List<Widget>? actions,
  bool barrierDismissible = true,
  double? width,
  double? maxWidth,
  bool scrollable = true,
  Widget? titleTrailing,
  VoidCallback? onConfirm,
}) {
  final glass = context.read<ThemeProvider>().isLiquidGlass;
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    //玻璃模式用轻遮罩，让模糊折射透出页面内容
    barrierColor: Colors.black.withValues(alpha: glass ? 0.25 : 0.5),
    builder: (context) => FluidDialog(
      content: content,
      title: title,
      actions: actions,
      barrierDismissible: barrierDismissible,
      width: width,
      maxWidth: maxWidth,
      scrollable: scrollable,
      titleTrailing: titleTrailing,
      onConfirm: onConfirm,
    ),
  );
}
