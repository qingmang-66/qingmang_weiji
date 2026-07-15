import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/achievement_category.dart';
import '../theme/fluid_theme.dart';
import '../services/providers/theme_provider.dart';
import '../utils/translations.dart';

/// 阶段四：成就类别筛选条
///
/// 横向滚动的类别芯片，单选。null 表示"全部"。
class AchievementCategoryFilter extends StatelessWidget {
  final AchievementCategory? selected;
  final ValueChanged<AchievementCategory?> onChanged;

  const AchievementCategoryFilter({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final tr = context.tr;
    final categories = <(AchievementCategory?, String, IconData)>[
      (null, tr.filterAll, Icons.apps),
      (AchievementCategory.study, tr.categoryStudy, Icons.school),
      (AchievementCategory.review, tr.categoryReview, Icons.replay),
      (
        AchievementCategory.streak,
        tr.categoryStreak,
        Icons.local_fire_department,
      ),
      (AchievementCategory.favorite, tr.categoryFavorite, Icons.bookmark),
      (AchievementCategory.customSet, tr.categoryCustomSet, Icons.folder),
      (AchievementCategory.plan, tr.categoryPlan, Icons.flag),
      (AchievementCategory.specialized, tr.categorySpecialized, Icons.style),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final (cat, label, icon) = categories[i];
          final isSelected = cat == selected;
          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: 4),
                Text(label),
              ],
            ),
            selected: isSelected,
            onSelected: (_) => onChanged(cat),
            selectedColor: FluidTheme.primaryFluidGradient.first.withValues(
              alpha: 0.18,
            ),
            backgroundColor: FluidTheme.getSurfaceColor(isDark),
            side: BorderSide(
              color: isSelected
                  ? FluidTheme.primaryFluidGradient.first
                  : FluidTheme.getBorderColor(isDark),
            ),
          );
        },
      ),
    );
  }
}
