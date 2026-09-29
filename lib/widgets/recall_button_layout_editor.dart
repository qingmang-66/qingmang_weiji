import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recall_button_layout.dart';
import '../services/providers/study_settings_provider.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import 'fluid_background.dart';
import 'liquid_glass.dart';
import 'recall_quality_action_bar.dart';

/// 测试定位用的 Key 集合：编辑器的每个可交互部件都有稳定 key，
/// widget 测试据此驱动，不必依赖文案（文案随中英切换会变）。
abstract final class RecallLayoutKeys {
  static const previewCard = Key('recallLayout.previewCard');
  static const previewArea = Key('recallLayout.previewArea');
  static const saveButton = Key('recallLayout.save');
  static const resetButton = Key('recallLayout.reset');
  static const widthSlider = Key('recallLayout.width');
  static const heightSlider = Key('recallLayout.height');
  static const opacitySlider = Key('recallLayout.opacity');
  static const nudgeUp = Key('recallLayout.nudgeUp');
  static const nudgeDown = Key('recallLayout.nudgeDown');
  static const nudgeLeft = Key('recallLayout.nudgeLeft');
  static const nudgeRight = Key('recallLayout.nudgeRight');
  static const revealToggle = Key('recallLayout.revealToggle');
  static const panelToggle = Key('recallLayout.panelToggle');

  static Key button(int quality) => Key('recallLayout.button.$quality');
  static Key selectButton(int quality) => Key('recallLayout.select.$quality');
}

/// 回忆模式评分键的自定义布局编辑器（锚点 + dp 偏移模型）。
///
/// 预览区就是整块屏幕（与学习页回忆模式同构：AppBar 之下、SafeArea 之内的
/// 内容区），参考手游的键位编辑：键摆在哪、实际就在哪，不再用中间一块
/// 缩小预览框「示意」——预览框与实机尺寸不同，摆位手感全靠脑补。
/// 宽高/透明度/微调收进**顶部**可收起的参数面板，收起时整屏都是摆位区。
/// 面板必须在顶部：默认三颗键都贴底，原底部面板展开时正好压在被调的键上。
///
/// 几何与学习页共用同一条公式（[RecallButtonSpec.resolve]）：
/// 1. 预览区用与学习页同一个 [RecallQualityButton] 与同一条几何公式，
///    不再有一套平行的换算。
/// 2. 每颗键独立设置宽/高/透明度，调一颗不会影响另外两颗。
/// 3. 位置以「锚点 + dp 间距」存储，换设备、缩放窗口都不会漂移。
class RecallButtonLayoutEditor extends StatefulWidget {
  const RecallButtonLayoutEditor({super.key});

  @override
  State<RecallButtonLayoutEditor> createState() =>
      _RecallButtonLayoutEditorState();
}

class _RecallButtonLayoutEditorState extends State<RecallButtonLayoutEditor> {
  /// 本地编辑态：保存前不动 Provider（学习页就在 Provider 上）
  late RecallButtonLayout _layout;
  int _selected = 3;
  bool _showDefinition = false;

  /// 顶部参数面板是否展开：默认收起，整屏都留给摆位
  bool _panelOpen = false;

  /// 正在拖动的键 + 已累计的位移（像素）
  int? _dragging;
  Offset _dragDelta = Offset.zero;
  Size _areaSize = Size.zero;

  /// 微调步长（dp）：与拖拽吸附同一档，按一次看得见移动又不会跳太远
  static const double _nudgeStep = kRecallSnapGrid;

  @override
  void initState() {
    super.initState();
    _layout = context.read<StudySettingsProvider>().recallButtonLayout;
  }

  /// 编辑器预览与学习页同一参考系：fx/fy 都相对整块内容区，
  /// 这里换算出的矩形直接喂给 [RecallButtonSpec.fromRect]。
  Rect _liveRectFor(int quality, Size area) {
    final base = _layout.specFor(quality).resolve(area);
    if (_dragging != quality) return base;
    final moved = base.shift(_dragDelta);
    return Rect.fromLTWH(
      moved.left.clamp(
        0.0,
        (area.width - base.width).clamp(0.0, double.infinity),
      ),
      moved.top.clamp(
        0.0,
        (area.height - base.height).clamp(0.0, double.infinity),
      ),
      base.width,
      base.height,
    );
  }

  void _select(int quality) {
    if (_selected == quality) return;
    setState(() => _selected = quality);
  }

  void _updateSelected(RecallButtonSpec Function(RecallButtonSpec) update) {
    setState(() {
      _layout = _layout.withSpec(_selected, update(_layout.specFor(_selected)));
    });
  }

  /// 方向微调：按 dp 改当前锚点的间距（超界由 resolve 收敛）
  void _nudge({double dx = 0, double dy = 0}) {
    _updateSelected((spec) {
      var next = spec;
      switch (spec.h) {
        case RecallHAnchor.left:
          next = next.copyWith(gapLeft: spec.gapLeft + dx);
        case RecallHAnchor.right:
          next = next.copyWith(gapRight: spec.gapRight - dx);
        case RecallHAnchor.center:
          next = next.copyWith(
            gapLeft: spec.gapLeft + dx / 2,
            gapRight: spec.gapRight - dx / 2,
          );
      }
      switch (spec.v) {
        case RecallVAnchor.top:
          next = next.copyWith(gapTop: spec.gapTop + dy);
        case RecallVAnchor.bottom:
          next = next.copyWith(gapBottom: spec.gapBottom - dy);
        case RecallVAnchor.middle:
          next = next.copyWith(gapMidY: spec.gapMidY + dy);
      }
      return next;
    });
  }

  /// 拖拽起点落在哪颗键上就拖哪颗（键以外的空白不拖）。
  /// [local] 与预览区的参考系一致（都是 LayoutBuilder 给的内容区尺寸）。
  void _onDragStart(Offset local) {
    for (final q in const [1, 3, 4]) {
      if (_liveRectFor(q, _areaSize).contains(local)) {
        setState(() {
          _dragging = q;
          _dragDelta = Offset.zero;
          _selected = q;
        });
        return;
      }
    }
  }

  void _onDragUpdate(Offset delta) {
    if (_dragging == null) return;
    setState(() => _dragDelta += delta);
  }

  void _onDragEnd() {
    final quality = _dragging;
    if (quality == null || _areaSize.width == 0) return;
    final dragged = _liveRectFor(quality, _areaSize);
    final spec = _layout.specFor(quality);
    setState(() {
      _layout = _layout.withSpec(
        quality,
        RecallButtonSpec.fromRect(dragged, _areaSize, w: spec.w, hPx: spec.hPx),
      );
      _dragging = null;
      _dragDelta = Offset.zero;
    });
  }

  void _onDragCancel() {
    if (_dragging == null) return;
    setState(() {
      _dragging = null;
      _dragDelta = Offset.zero;
    });
  }

  Future<void> _save() async {
    await context.read<StudySettingsProvider>().applyRecallButtonLayout(
      _layout,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    final settings = context.read<StudySettingsProvider>();
    await settings.resetRecallButtonLayout();
    if (!mounted) return;
    setState(() {
      _layout = settings.recallButtonLayout;
      _dragging = null;
      _dragDelta = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final tr = context.tr;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    return Scaffold(
      backgroundColor: context.isLiquidGlass
          ? Colors.transparent
          : FluidTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text(
          tr.t('自定义按键位置', 'Customize Button Layout'),
          style: FluidTheme.headingSmall(isDark).copyWith(color: textPrimary),
        ),
        actions: [
          //展开释义：检查键有没有压住展开后的正文
          IconButton(
            key: RecallLayoutKeys.revealToggle,
            icon: Icon(
              _showDefinition ? Icons.menu_book : Icons.menu_book_outlined,
              color: _showDefinition
                  ? FluidTheme.primaryFluidGradient[0]
                  : textPrimary,
            ),
            tooltip: tr.t('展开释义', 'Show meaning'),
            onPressed: () => setState(() => _showDefinition = !_showDefinition),
          ),
          TextButton(
            key: RecallLayoutKeys.resetButton,
            onPressed: _reset,
            child: Text(tr.t('恢复默认', 'Reset')),
          ),
          TextButton(
            key: RecallLayoutKeys.saveButton,
            onPressed: _save,
            child: Text(tr.confirm),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FluidBackground(
        child: Column(
          children: [
            //学习页内容区顶部有一条 4dp 进度条：这里补同高占位，
            //保证预览参考系与学习页逐像素一致
            const SizedBox(height: 4),
            Expanded(
              child: Stack(
                children: [
                  //全屏预览：与学习页回忆模式同构（SafeArea 内的整块内容区）
                  Positioned.fill(
                    child: SafeArea(top: false, child: _buildPreview(isDark)),
                  ),
                  //顶部参数面板：浮在预览上方。默认三颗键都贴底，
                  //从顶部落下不会正好压在被调的键上（原底部面板展开时
                  //把贴底的三颗键全挡住了）；收起时整屏都是摆位区
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: _buildTopPanel(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 全屏预览区：题面卡片 + 三颗可拖动的评分键。
  /// 参考区尺寸 = 学习页内容区尺寸（SafeArea 后），所见即所得。
  Widget _buildPreview(bool isDark) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (d) => _onDragStart(d.localPosition),
      onPanUpdate: (d) => _onDragUpdate(d.delta),
      onPanEnd: (_) => _onDragEnd(),
      onPanCancel: _onDragCancel,
      child: Container(
        key: RecallLayoutKeys.previewArea,
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, c) {
            _areaSize = Size(c.maxWidth, c.maxHeight);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: _buildPrompt(isDark)),
                for (final quality in const [1, 3, 4])
                  _buildKeyButton(quality, isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 题面示意：与学习页回忆模式同样的卡片内边距与字号（全屏后 1:1），
  /// 释义可展开——展开后卡片变高，用来检查键有没有压住正文
  Widget _buildPrompt(bool isDark) {
    final tr = context.tr;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            key: RecallLayoutKeys.previewCard,
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 44),
            decoration: BoxDecoration(
              color: FluidTheme.getMutedOverlayColor(isDark),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'example',
                  style: TextStyle(
                    fontSize: 52,
                    height: 1.08,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '/ɪɡˈzæmpl/',
                  style: TextStyle(fontSize: 21, color: textSecondary),
                ),
                const SizedBox(height: 20),
                Icon(
                  Icons.volume_up_outlined,
                  size: 36,
                  color: FluidTheme.primaryFluidGradient[0],
                ),
                if (_showDefinition) ...[
                  const SizedBox(height: 24),
                  Divider(
                    color: FluidTheme.getBorderColor(isDark),
                    thickness: 1,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr.t('n. 例子；实例', 'n. a thing illustrative of a type'),
                    textAlign: TextAlign.left,
                    style: FluidTheme.bodyMedium(isDark).copyWith(
                      color: textPrimary,
                      fontSize: 20,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 编辑器里的键：复用 [RecallQualityButton] 外观，但位置取"拖动中的临时矩形"，
  /// 且点击不真的评分（只做选中）。
  Widget _buildKeyButton(int quality, bool isDark) {
    final rect = _liveRectFor(quality, _areaSize);
    if (_areaSize.width == 0) return const SizedBox.shrink();
    final spec = _layout.specFor(quality);
    final selected = _selected == quality;
    final dragging = _dragging == quality;
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Opacity(
        // 非选中键淡出，选中/拖动的那颗清晰——三键叠在题面上时也要分得清
        opacity: selected || dragging ? 1.0 : 0.72,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: dragging || selected
                ? Border.all(
                    color: FluidTheme.primaryFluidGradient[0],
                    width: dragging ? 2 : 1.4,
                  )
                : null,
          ),
          child: RecallQualityButton(
            key: RecallLayoutKeys.button(quality),
            label: _labelFor(quality),
            color: _colorFor(quality),
            isDark: isDark,
            opacity: spec.opacity,
            onTap: () => _select(quality),
          ),
        ),
      ),
    );
  }

  String _labelFor(int quality) {
    final tr = context.tr;
    switch (quality) {
      case 1:
        return tr.unknownLabel;
      case 3:
        return tr.vague;
      default:
        return tr.recallKnown;
    }
  }

  Color _colorFor(int quality) {
    // 1=不认识 / 3=模糊 / 4=认识（与学习页评分表一致）
    switch (quality) {
      case 1:
        return Colors.red;
      case 3:
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  /// 顶部参数面板：把手常显（点按展开/收起），展开后是选键 + 宽高/透明度 + 微调。
  ///
  /// 玻璃风格下材质与底部导航条同款（[GlassSurface] + [LiquidGlass.blurSigmaHeavy]）：
  /// 实时 BackdropFilter 把面板背后的题面卡/按键折射模糊地透上来，
  /// 而不是原实现那层 92% 不透明的纯色板 —— 纯色板既挡视线又毫无玻璃质感。
  /// 经典流体风格保持原纯色面板，与全站"风格各走各的材质"一致。
  Widget _buildTopPanel(bool isDark) {
    final tr = context.tr;
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: RecallLayoutKeys.panelToggle,
          onTap: () => setState(() => _panelOpen = !_panelOpen),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                Icon(
                  Icons.tune,
                  size: 18,
                  color: FluidTheme.primaryFluidGradient[0],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr.t(
                      '按键参数 · ${_labelFor(_selected)}',
                      'Key params · ${_labelFor(_selected)}',
                    ),
                    style: FluidTheme.labelLarge(
                      isDark,
                    ).copyWith(color: textSecondary),
                  ),
                ),
                Icon(
                  //面板在顶部：收起时向下指（拉下来展开），展开时向上指（收回顶部）
                  _panelOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_panelOpen) ...[
          const Divider(height: 1),
          _buildSelector(isDark),
          _buildKeyPanel(isDark),
          const SizedBox(height: 8),
        ],
      ],
    );

    //悬浮胶囊式摆放，与导航条一致：左右留边、离顶 8
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: context.isLiquidGlass
          //玻璃风格：与导航条同款实时模糊玻璃，背后按键/题面折射透上来
          ? GlassSurface(
              borderRadius: 24,
              blurSigma: LiquidGlass.blurSigmaHeavy,
              child: content,
            )
          //经典流体风格：保持原纯色面板
          : Container(
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1A1D24) : Colors.white)
                    .withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(color: FluidTheme.getBorderColor(isDark)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: content,
            ),
    );
  }

  Widget _buildSelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          for (final quality in const [1, 3, 4])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton(
                  key: RecallLayoutKeys.selectButton(quality),
                  onPressed: () => _select(quality),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _selected == quality
                          ? FluidTheme.primaryFluidGradient[0]
                          : FluidTheme.getBorderColor(isDark),
                    ),
                  ),
                  child: Text(_labelFor(quality)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 逐键面板：宽 / 高 / 透明度 + 四向微调，全部只作用于当前选中的那颗键
  Widget _buildKeyPanel(bool isDark) {
    final spec = _layout.specFor(_selected);
    final tr = context.tr;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Column(
        children: [
          _sliderRow(
            isDark: isDark,
            icon: Icons.width_full,
            label: tr.t('宽度', 'Width'),
            value: '${spec.w.round()}dp',
            slider: Slider(
              key: RecallLayoutKeys.widthSlider,
              value: spec.w.clamp(kRecallButtonMinW, kRecallButtonMaxW),
              min: kRecallButtonMinW,
              max: kRecallButtonMaxW,
              divisions: ((kRecallButtonMaxW - kRecallButtonMinW) / 10).round(),
              onChanged: (v) => _updateSelected((s) => s.copyWith(w: v)),
            ),
          ),
          _sliderRow(
            isDark: isDark,
            icon: Icons.height,
            label: tr.t('高度', 'Height'),
            value: '${spec.hPx.round()}dp',
            slider: Slider(
              key: RecallLayoutKeys.heightSlider,
              value: spec.hPx.clamp(kRecallButtonMinH, kRecallButtonMaxH),
              min: kRecallButtonMinH,
              max: kRecallButtonMaxH,
              divisions: ((kRecallButtonMaxH - kRecallButtonMinH) / 4).round(),
              onChanged: (v) => _updateSelected((s) => s.copyWith(hPx: v)),
            ),
          ),
          _sliderRow(
            isDark: isDark,
            icon: Icons.opacity_outlined,
            label: tr.t('透明度', 'Opacity'),
            value: '${(spec.opacity * 100).round()}%',
            slider: Slider(
              key: RecallLayoutKeys.opacitySlider,
              value: spec.opacity.clamp(
                kRecallButtonMinOpacity,
                kRecallButtonMaxOpacity,
              ),
              min: kRecallButtonMinOpacity,
              max: kRecallButtonMaxOpacity,
              divisions: 14,
              onChanged: (v) => _updateSelected((s) => s.copyWith(opacity: v)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tr.t('微调', 'Nudge'),
                style: FluidTheme.bodySmall(
                  isDark,
                ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
              ),
              const SizedBox(width: 12),
              _nudgeButton(
                RecallLayoutKeys.nudgeLeft,
                Icons.chevron_left,
                dx: -_nudgeStep,
              ),
              _nudgeButton(
                RecallLayoutKeys.nudgeRight,
                Icons.chevron_right,
                dx: _nudgeStep,
              ),
              _nudgeButton(
                RecallLayoutKeys.nudgeUp,
                Icons.keyboard_arrow_up,
                dy: -_nudgeStep,
              ),
              _nudgeButton(
                RecallLayoutKeys.nudgeDown,
                Icons.keyboard_arrow_down,
                dy: _nudgeStep,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nudgeButton(Key key, IconData icon, {double dx = 0, double dy = 0}) {
    return IconButton(
      key: key,
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: () => _nudge(dx: dx, dy: dy),
      icon: Icon(icon),
    );
  }

  Widget _sliderRow({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required Widget slider,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: FluidTheme.primaryFluidGradient[0]),
        const SizedBox(width: 8),
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: FluidTheme.labelLarge(
              isDark,
            ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
          ),
        ),
        Expanded(child: slider),
        SizedBox(
          width: 56,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: FluidTheme.bodySmall(
              isDark,
            ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
          ),
        ),
      ],
    );
  }
}
