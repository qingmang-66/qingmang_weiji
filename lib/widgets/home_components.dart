import 'package:flutter/material.dart';

import '../theme/fluid_theme.dart';
import 'liquid_glass.dart';

/// 统计卡片
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value.toString(),
              style: FluidTheme.numberStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
    //玻璃模式用带品牌色淡 tint 的玻璃表面，经典模式保留半透明色块
    if (context.isLiquidGlass) {
      return GlassSurface(
        borderRadius: 16,
        padding: const EdgeInsets.all(16),
        tint: color.withValues(alpha: 0.1),
        child: content,
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: content,
    );
  }
}

/// 快捷操作卡片
///
/// 首页「词集」段用它并排摆两个入口（错题集 / 收藏夹）。数量徽标是否显示
/// 由调用方通过 [showCount] 控制 —— 词集设置里可以各自关掉。
class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  /// 数量徽标的值；为 null 表示没有数量可展示
  final int? count;

  /// 是否显示数量徽标
  final bool showCount;

  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.count,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badge = (count != null && showCount)
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${count!}',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : null;

    final content = Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (badge != null) ...[const SizedBox(width: 6), badge],
          ],
        ),
      ],
    );
    //玻璃模式用玻璃表面 + 手势点击，经典模式保留 Card 水波纹
    if (context.isLiquidGlass) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: GlassSurface(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: content,
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: content,
        ),
      ),
    );
  }
}
