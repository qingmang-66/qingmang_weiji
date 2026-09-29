import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/fluid_theme.dart';
import '../utils/platform_adapt.dart';

/// 摁下即可滑动切换的分段选择器（交互语义与 [LiquidPillNavBar] 一致）。
///
/// 原生 [SegmentedButton] 只能"松手再点下一段"：想从第一档换到第三档要
/// 抬手指再落一次。导航条的胶囊是"摁住不放、滑到哪段选哪段"，设置页的
/// 档位选择沿用同一套手感：pointer down 立即选中落点段，按住滑动实时
/// 跟随，松手即定稿（中途滑出控件范围也不回滚，跟手指的最后一段）。
///
/// 视觉保持分段按钮的方角容器 + 高亮块滑动动画，双风格共用一套配色。
class SlideSegmentedControl<T> extends StatefulWidget {
  const SlideSegmentedControl({
    super.key,
    required this.values,
    required this.labelBuilder,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final Widget Function(T value, bool selected) labelBuilder;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  State<SlideSegmentedControl<T>> createState() =>
      _SlideSegmentedControlState<T>();
}

class _SlideSegmentedControlState<T> extends State<SlideSegmentedControl<T>> {
  bool _pressed = false;

  int get _selectedIndex {
    final idx = widget.values.indexOf(widget.selected);
    return idx < 0 ? 0 : idx;
  }

  /// 落点横坐标 → 段下标（等宽分段）
  int _indexAt(Offset local, Size size) {
    final n = widget.values.length;
    if (n == 0 || size.width <= 0) return 0;
    final raw = (local.dx / (size.width / n)).floor();
    return raw.clamp(0, n - 1);
  }

  void _selectIndex(int index) {
    if (index < 0 || index >= widget.values.length) return;
    final value = widget.values[index];
    if (value == widget.selected) return;
    if (PlatformAdapt.isMobile) HapticFeedback.selectionClick();
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = FluidTheme.primaryFluidGradient[0];
    final n = widget.values.length;
    final selected = _selectedIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cellW = n == 0 ? width : width / n;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            setState(() => _pressed = true);
            _selectIndex(_indexAt(e.localPosition, Size(width, 1)));
          },
          onPointerMove: (e) {
            if (!_pressed) return;
            _selectIndex(_indexAt(e.localPosition, Size(width, 1)));
          },
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: FluidTheme.getMutedOverlayColor(isDark),
              border: Border.all(
                color: _pressed
                    ? accent.withValues(alpha: 0.55)
                    : FluidTheme.getBorderColor(isDark),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // 高亮块：等宽分段间滑动，弹簧感交给 AnimatedPositioned 的曲线
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  left: selected * cellW + 2,
                  top: 2,
                  bottom: 2,
                  width: cellW - 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: accent.withValues(alpha: isDark ? 0.32 : 0.16),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: Center(
                          child: widget.labelBuilder(
                            widget.values[i],
                            i == selected,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
