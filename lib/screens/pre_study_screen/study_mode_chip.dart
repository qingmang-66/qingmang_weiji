part of '../pre_study_screen.dart';

/// 学习模式选择芯片
class StudyModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const StudyModeChip({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final unselectedColor = FluidTheme.getTextSecondaryColor(isDark);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: FluidTheme.primaryFluidGradient)
              : null,
          color: isSelected ? null : FluidTheme.getMutedOverlayColor(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : FluidTheme.getBorderColor(isDark),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              // 选中态在品牌渐变底上：用主题提供的可读前景色（8.34:1），
              // 纯白在 #F093FB 渐变上只有 2.04:1，两种模式都不达 WCAG AA
              color: isSelected
                  ? FluidTheme.onGradientForeground
                  : unselectedColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? FluidTheme.onGradientForeground
                    : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
