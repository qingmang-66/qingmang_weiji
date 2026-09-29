import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import 'liquid_controls.dart';
import 'liquid_glass.dart';

/// 设置面板的统一外观：分组容器 / 开关行 / 描边按钮
///
/// 阅读模式、错题集、收藏夹三处设置面板共用这一套，避免各写一份
/// "玻璃分组 + 开关行"导致视觉随主题漂移。玻璃风格走 [GlassSurface]，
/// 经典风格走渐变面 —— 与其余卡片一致。
class FluidSettingsSection extends StatelessWidget {
  /// 分组标题；为 null 时不绘制标题（弹窗自身已有标题时用）
  final String? title;
  final List<Widget> children;

  const FluidSettingsSection({super.key, required this.children, this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final isGlass = context.select<ThemeProvider, bool>((p) => p.isLiquidGlass);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                return LinearGradient(
                  //浅色玻璃上原渐变对比度不足，用压暗变体保证标题可读
                  colors: FluidTheme.textGradient(isDark),
                ).createShader(bounds);
              },
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, title == null ? 16 : 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ],
    );

    if (isGlass) {
      return GlassSurface(
        margin: EdgeInsets.zero,
        borderRadius: FluidTheme.cardBorderRadius,
        child: body,
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: FluidTheme.getSurfaceGradientColors(isDark),
        ),
        borderRadius: BorderRadius.circular(FluidTheme.cardBorderRadius),
        border: Border.all(color: FluidTheme.getBorderColor(isDark)),
      ),
      child: body,
    );
  }
}

/// 开关行：标签（+ 可选说明）+ [LiquidSwitch]
Widget fluidSettingsSwitchRow({
  required BuildContext context,
  required String label,
  String? hint,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: FluidTheme.getTextPrimaryColor(isDark),
                  fontSize: 14,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: TextStyle(
                    color: FluidTheme.getTextTertiaryColor(isDark),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        LiquidSwitch(
          value: value,
          activeColor: FluidTheme.primaryFluidGradient[0],
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

/// 玻璃模式用玻璃描边胶囊按钮，经典模式保留 OutlinedButton
Widget fluidSettingsOutlineButton({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback onPressed,
}) {
  if (context.select<ThemeProvider, bool>((p) => p.isLiquidGlass)) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: GlassSurface(
        borderRadius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
  return OutlinedButton.icon(
    icon: Icon(icon),
    label: Text(label),
    onPressed: onPressed,
  );
}
