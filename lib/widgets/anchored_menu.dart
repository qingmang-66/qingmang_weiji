import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import 'liquid_glass.dart';

/// 锚定弹出菜单的一项
class AnchoredMenuItem {
  final String value;
  final IconData icon;
  final String label;
  final Color? color;

  const AnchoredMenuItem({
    required this.value,
    required this.icon,
    required this.label,
    this.color,
  });
}

/// 在 [anchorContext]（通常是触发按钮的 context）原地展开的弹出菜单。
///
/// 项目的弹层统一走 FluidDialog/GlassSurface 材质；Material 自带的
/// PopupMenuButton 是不透明纯色卡，在液态玻璃风格下会脱离体系。
/// 本组件两种风格都适配：
/// - 液态玻璃：GlassSurface（实时模糊 + 果冻描边 + 噪点），与弹窗同材质；
/// - 经典流体：FluidTheme 对话框表面色圆角卡。
///
/// 实现走 [showGeneralDialog]（与 showDialog 同源的 DialogRoute：
/// 遮罩/语义/路由栈管理全部交给框架），不要自管全屏手势层。
/// 选中项通过返回值（[AnchoredMenuItem.value]）带回；点遮罩关闭返回 null。
Future<String?> showAnchoredMenu({
  required BuildContext anchorContext,
  required List<AnchoredMenuItem> items,
}) {
  final box = anchorContext.findRenderObject();
  if (box is! RenderBox || !box.attached || !anchorContext.mounted) {
    return Future.value();
  }
  final rect = box.localToGlobal(Offset.zero) & box.size;
  final isGlass = anchorContext.read<ThemeProvider>().isLiquidGlass;
  return showGeneralDialog<String>(
    context: anchorContext,
    //与 FluidDialog 同源：点遮罩关闭，遮罩浓度也保持一致
    barrierDismissible: true,
    barrierLabel: 'AnchoredMenu',
    barrierColor: Colors.black.withValues(alpha: isGlass ? 0.18 : 0.28),
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _AnchoredMenuOverlay(anchorRect: rect, items: items),
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
  );
}

class _AnchoredMenuOverlay extends StatelessWidget {
  final Rect anchorRect;
  final List<AnchoredMenuItem> items;

  const _AnchoredMenuOverlay({required this.anchorRect, required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final isGlass = context.select<ThemeProvider, bool>((p) => p.isLiquidGlass);
    final size = MediaQuery.sizeOf(context);
    const menuWidth = 184.0;
    const menuGap = 6.0;
    final estimatedHeight = items.length * 44.0 + 12.0;

    //菜单锚在按钮正下方，越界时向上翻 / 水平收进屏幕内。
    //clamp 的上限必须 >= 下限：短窗口/窄窗下 size - menu - 8 可能小于 8，
    //直接 clamp 会因上下限颠倒抛 ArgumentError（菜单一弹就崩）
    final maxLeft = size.width - menuWidth - 8.0;
    final left = (anchorRect.right - menuWidth).clamp(
      8.0,
      maxLeft < 8.0 ? 8.0 : maxLeft,
    );
    final openDownward =
        anchorRect.bottom + estimatedHeight < size.height ||
        anchorRect.top < estimatedHeight;
    final rawTop = openDownward
        ? anchorRect.bottom + menuGap
        : anchorRect.top - menuGap - estimatedHeight;
    final maxTop = size.height - estimatedHeight - 8.0;

    return Padding(
      padding: EdgeInsets.only(
        left: left,
        top: rawTop.clamp(8.0, maxTop < 8.0 ? 8.0 : maxTop),
      ),
      // Align 给 child 松约束：Dialog 路由的页面子树拿到的是**全屏紧约束**，
      // 直接传下去的话 Column 的 mainAxisSize.min 失效，菜单会被纵向拉伸到
      // 屏幕底部（4 项之下全是空白玻璃）。松绑后面板按内容收缩。
      //Material(transparency)：InkWell 必须有 Material 祖先（水波纹与命中）
      child: Align(
        alignment: Alignment.topLeft,
        child: Material(
          type: MaterialType.transparency,
          child: _MenuPanel(isDark: isDark, isGlass: isGlass, items: items),
        ),
      ),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  final bool isDark;
  final bool isGlass;
  final List<AnchoredMenuItem> items;

  const _MenuPanel({
    required this.isDark,
    required this.isGlass,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    Widget panel = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 0.7,
              indent: 14,
              endIndent: 14,
              color: FluidTheme.getBorderColor(isDark),
            ),
          _MenuRow(item: items[i], isDark: isDark, textPrimary: textPrimary),
        ],
      ],
    );

    if (isGlass) {
      //与 FluidDialog 弹窗同一套玻璃材质：实时模糊 + 果冻高光 + 噪点
      panel = GlassSurface(
        borderRadius: 16,
        blurSigma: LiquidGlass.blurSigmaHeavy,
        emphasized: true,
        grain: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: panel,
      );
    } else {
      panel = Container(
        decoration: BoxDecoration(
          color: FluidTheme.getDialogSurfaceColor(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FluidTheme.getBorderColor(isDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: panel,
      );
    }

    //菜单内容定宽：玻璃模式 GlassSurface 不约束宽度时会尽量撑开
    return SizedBox(width: 184, child: panel);
  }
}

class _MenuRow extends StatelessWidget {
  final AnchoredMenuItem item;
  final bool isDark;
  final Color textPrimary;

  const _MenuRow({
    required this.item,
    required this.isDark,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? textPrimary;
    return InkWell(
      onTap: () => Navigator.of(context).pop(item.value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(item.icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: FluidTheme.labelLarge(isDark).copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
