import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/recall_button_layout.dart';
import '../services/providers/study_settings_provider.dart';
import '../services/providers/theme_provider.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import 'liquid_glass.dart';

/// 回忆模式评分键的**唯一**渲染入口。
///
/// 学习页与「自定义按键位置」编辑器共用这一个 widget：编辑器把它叠在
/// 题面示意之上，所见即所得从此是同一段代码，不存在第二套几何公式
/// （旧实现在学习页与编辑器各写了一遍键宽换算，口径还不一样）。
class RecallQualityActionBar extends StatelessWidget {
  const RecallQualityActionBar({
    super.key,
    this.layout,
    required this.onTapQuality,
    this.enabled = true,
    this.isDark,
  });

  /// 三颗键的锚点布局。为 null 时从 [StudySettingsProvider] 订阅（学习页）；
  /// 编辑器传入本地编辑态，从而预览与实机走同一段渲染代码。
  final RecallButtonLayout? layout;

  /// quality 编码：1=不认识 3=模糊 4=认识
  final ValueChanged<int> onTapQuality;

  /// 保存中临时禁用（学习页写库期间）
  final bool enabled;

  /// 学习页传入已算好的 isDark，避免在浮层里重复订阅主题
  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final dark =
        isDark ?? context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    // layout == null 时订阅设置：布局是个不可变对象，只在保存时换新引用，
    // 所以 select 能判定"未变化"，无关设置变更不会重建学习页。
    final resolved =
        layout ??
        context.select<StudySettingsProvider, RecallButtonLayout>(
          (s) => s.recallButtonLayout,
        );
    // 1=不认识 / 3=模糊 / 4=认识（与学习页 _onQualitySelected 的评分表一致）
    final meta = <int, ({String label, Color color})>{
      1: (label: context.tr.unknownLabel, color: Colors.red),
      3: (label: context.tr.vague, color: Colors.orange),
      4: (label: context.tr.recallKnown, color: Colors.green),
    };
    return LayoutBuilder(
      builder: (context, c) {
        final area = Size(c.maxWidth, c.maxHeight);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final quality in const [1, 3, 4])
              _positionedButton(
                context: context,
                resolved: resolved,
                quality: quality,
                area: area,
                meta: meta,
                dark: dark,
              ),
          ],
        );
      },
    );
  }

  Widget _positionedButton({
    required BuildContext context,
    required RecallButtonLayout resolved,
    required int quality,
    required Size area,
    required Map<int, ({String label, Color color})> meta,
    required bool dark,
  }) {
    final spec = resolved.specFor(quality);
    final rect = spec.resolve(area);
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: RecallQualityButton(
        label: meta[quality]!.label,
        color: meta[quality]!.color,
        onTap: () => onTapQuality(quality),
        isDark: dark,
        enabled: enabled,
        opacity: spec.opacity,
      ),
    );
  }
}

/// 单颗评分键的外观（玻璃 / 经典双分支）。
///
/// 手感与测验选项对齐：按下立即缩小，松手用 easeOutBack 回弹（缩放会短暂
/// 越过 1.0 再回落），移动端附带一次轻震动。
/// 回忆模式自定义键位也直接复用它，保证"预览 = 实际"。
class RecallQualityButton extends StatefulWidget {
  const RecallQualityButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    required this.isDark,
    this.enabled = true,
    this.opacity = 1.0,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  /// 保存中的弱化/禁用态：点击评分后按钮要有即时反馈
  final bool enabled;

  /// 按键不透明度（自定义键位布局：0.3 ~ 1.0，1.0 = 完全不透明）
  final double opacity;

  @override
  State<RecallQualityButton> createState() => _RecallQualityButtonState();
}

class _RecallQualityButtonState extends State<RecallQualityButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (PlatformAdapt.isMobile) HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    //自定义键位布局的透明度：直接作用在键的基色上，
    //文字/描边/背景随之同步变淡（背景自身的 alpha 系数保持不变）
    final color = widget.opacity >= 1.0
        ? widget.color
        : widget.color.withValues(alpha: widget.opacity);
    final labelWidget = Text(
      widget.label,
      maxLines: 1,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
    //禁用时用透明度弱化（带过渡），而不是让按钮"点了没反应"；
    //Center：键宽由外部约束（自定义键位下每颗键各自的宽高），文字保持水平居中。
    //FittedBox scaleDown：键被压窄时（或长译文如"不认识"）文字整体缩小而不是
    //被裁掉半边，这是"底部三键文字显示不全"的修法
    final Widget content = AnimatedOpacity(
      opacity: widget.enabled ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 160),
      child: Center(
        child: FittedBox(fit: BoxFit.scaleDown, child: labelWidget),
      ),
    );
    final enabled = widget.enabled;
    // 垂直内边距固定：键高已由外层 Positioned（布局的 hPx）决定，
    // 不再像旧实现那样从全局 scale 推导 padding
    const vPadding = 8.0;

    final Widget card;
    if (context.isLiquidGlass) {
      //玻璃模式：彩色强调果冻按钮
      card = GlassSurface(
        borderRadius: 12,
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: vPadding),
        emphasized: true,
        glowColor: color,
        tint: LiquidGlass.accentTint(color, widget.isDark),
        child: content,
      );
    } else {
      card = Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: vPadding),
        decoration: BoxDecoration(
          color: color.withValues(alpha: widget.isDark ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: widget.isDark ? 0.55 : 0.35),
          ),
        ),
        child: content,
      );
    }

    final interactive = enabled;
    return GestureDetector(
      onTapDown: interactive ? (_) => _setPressed(true) : null,
      onTapUp: interactive ? (_) => _setPressed(false) : null,
      onTapCancel: interactive ? () => _setPressed(false) : null,
      onTap: interactive ? _handleTap : null,
      child: AnimatedScale(
        //按下快（90ms）、回弹慢（260ms）且带 overshoot，指下有明确"弹回"感
        scale: _pressed ? 0.94 : 1.0,
        duration: Duration(milliseconds: _pressed ? 90 : 260),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: card,
      ),
    );
  }
}
