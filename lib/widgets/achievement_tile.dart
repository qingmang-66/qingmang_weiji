import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/achievement_progress.dart';
import '../theme/fluid_theme.dart';
import '../services/providers/theme_provider.dart';
import '../utils/translations.dart';
import 'fluid_card.dart';

/// 阶段四：成就单元（通用）
///
/// compact=true 时省去描述与日期，用于首页"最近成就"卡片。
/// compact=false 时为完整版，用于成就中心列表。
class AchievementTile extends StatelessWidget {
  final AchievementProgress progress;
  final bool compact;
  final VoidCallback? onTap;

  const AchievementTile({
    super.key,
    required this.progress,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final def = progress.definition;
    final unlocked = progress.isUnlocked;

    // 解锁态：金色渐变 + shimmer；未解锁：单色灰
    final gradient = unlocked
        ? FluidTheme.warningFluidGradient
        : <Color>[
            FluidTheme.getBorderColor(isDark),
            FluidTheme.getBorderColor(isDark),
          ];
    final iconColor = unlocked
        ? Colors.white
        : FluidTheme.getTextTertiaryColor(isDark);
    final titleColor = unlocked
        ? FluidTheme.getTextPrimaryColor(isDark)
        : FluidTheme.getTextTertiaryColor(isDark);
    final descColor = FluidTheme.getTextSecondaryColor(isDark);

    final shape = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        child: FluidCard(
          enableShimmer: unlocked,
          enableBorderGradient: unlocked,
          borderColors: unlocked ? gradient : null,
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: compact ? 36 : 52,
                height: compact ? 36 : 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: gradient),
                ),
                child: Icon(
                  def.icon,
                  color: iconColor,
                  size: compact ? 20 : 28,
                ),
              ),
              SizedBox(height: compact ? 4 : 8),
              Text(
                _trTitle(context, def.titleKey),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (compact
                            ? FluidTheme.bodySmall(isDark)
                            : FluidTheme.labelLarge(isDark))
                        .copyWith(color: titleColor),
              ),
              if (!compact) ...[
                const SizedBox(height: 4),
                Text(
                  _trDesc(context, def.descriptionKey),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FluidTheme.bodySmall(
                    isDark,
                  ).copyWith(color: descColor),
                ),
              ],
              SizedBox(height: compact ? 4 : 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.progressRatio,
                  minHeight: compact ? 4 : 6,
                  backgroundColor: gradient.first.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(gradient.first),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _progressText(context, progress),
                style: FluidTheme.numberStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: descColor,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return shape;
  }

  /// 进度文字：已解锁显示日期，未解锁显示「当前/目标」
  String _progressText(BuildContext context, AchievementProgress p) {
    if (p.isUnlocked && p.unlockedAt != null) {
      return _formatDate(p.unlockedAt!);
    }
    return '${p.currentValue}/${p.definition.targetValue}';
  }

  String _formatDate(DateTime t) {
    final l = t.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  /// 标题翻译映射
  String _trTitle(BuildContext context, String key) {
    final tr = context.tr;
    switch (key) {
      case 'ach.study10Title':
        return tr.achStudy10Title;
      case 'ach.study50Title':
        return tr.achStudy50Title;
      case 'ach.study100Title':
        return tr.achStudy100Title;
      case 'ach.study500Title':
        return tr.achStudy500Title;
      case 'ach.study1000Title':
        return tr.achStudy1000Title;
      case 'ach.review10Title':
        return tr.achReview10Title;
      case 'ach.review50Title':
        return tr.achReview50Title;
      case 'ach.review200Title':
        return tr.achReview200Title;
      case 'ach.review1000Title':
        return tr.achReview1000Title;
      case 'ach.streak3Title':
        return tr.achStreak3Title;
      case 'ach.streak7Title':
        return tr.achStreak7Title;
      case 'ach.streak30Title':
        return tr.achStreak30Title;
      case 'ach.streak100Title':
        return tr.achStreak100Title;
      case 'ach.favFirstTitle':
        return tr.achFavFirstTitle;
      case 'ach.fav20Title':
        return tr.achFav20Title;
      case 'ach.fav100Title':
        return tr.achFav100Title;
      case 'ach.favGroup3Title':
        return tr.achFavGroup3Title;
      case 'ach.favStudiedTitle':
        return tr.achFavStudiedTitle;
      case 'ach.setFirstTitle':
        return tr.achSetFirstTitle;
      case 'ach.set5Title':
        return tr.achSet5Title;
      case 'ach.setStudiedTitle':
        return tr.achSetStudiedTitle;
      case 'ach.planWeek3Title':
        return tr.achPlanWeek3Title;
      case 'ach.planWeek5Title':
        return tr.achPlanWeek5Title;
      case 'ach.planWeek7Title':
        return tr.achPlanWeek7Title;
      case 'ach.planStudy5Title':
        return tr.achPlanStudy5Title;
      case 'ach.planStudy7Title':
        return tr.achPlanStudy7Title;
      case 'ach.wrongStreak3Title':
        return tr.achWrongStreak3Title;
      case 'ach.wrongStreak10Title':
        return tr.achWrongStreak10Title;
      case 'ach.mastery50Title':
        return tr.achMastery50Title;
      case 'ach.mastery80Title':
        return tr.achMastery80Title;
      default:
        return key;
    }
  }

  /// 描述翻译映射
  String _trDesc(BuildContext context, String key) {
    final tr = context.tr;
    switch (key) {
      case 'ach.study10Desc':
        return tr.achStudy10Desc;
      case 'ach.study50Desc':
        return tr.achStudy50Desc;
      case 'ach.study100Desc':
        return tr.achStudy100Desc;
      case 'ach.study500Desc':
        return tr.achStudy500Desc;
      case 'ach.study1000Desc':
        return tr.achStudy1000Desc;
      case 'ach.review10Desc':
        return tr.achReview10Desc;
      case 'ach.review50Desc':
        return tr.achReview50Desc;
      case 'ach.review200Desc':
        return tr.achReview200Desc;
      case 'ach.review1000Desc':
        return tr.achReview1000Desc;
      case 'ach.streak3Desc':
        return tr.achStreak3Desc;
      case 'ach.streak7Desc':
        return tr.achStreak7Desc;
      case 'ach.streak30Desc':
        return tr.achStreak30Desc;
      case 'ach.streak100Desc':
        return tr.achStreak100Desc;
      case 'ach.favFirstDesc':
        return tr.achFavFirstDesc;
      case 'ach.fav20Desc':
        return tr.achFav20Desc;
      case 'ach.fav100Desc':
        return tr.achFav100Desc;
      case 'ach.favGroup3Desc':
        return tr.achFavGroup3Desc;
      case 'ach.favStudiedDesc':
        return tr.achFavStudiedDesc;
      case 'ach.setFirstDesc':
        return tr.achSetFirstDesc;
      case 'ach.set5Desc':
        return tr.achSet5Desc;
      case 'ach.setStudiedDesc':
        return tr.achSetStudiedDesc;
      case 'ach.planWeek3Desc':
        return tr.achPlanWeek3Desc;
      case 'ach.planWeek5Desc':
        return tr.achPlanWeek5Desc;
      case 'ach.planWeek7Desc':
        return tr.achPlanWeek7Desc;
      case 'ach.planStudy5Desc':
        return tr.achPlanStudy5Desc;
      case 'ach.planStudy7Desc':
        return tr.achPlanStudy7Desc;
      case 'ach.wrongStreak3Desc':
        return tr.achWrongStreak3Desc;
      case 'ach.wrongStreak10Desc':
        return tr.achWrongStreak10Desc;
      case 'ach.mastery50Desc':
        return tr.achMastery50Desc;
      case 'ach.mastery80Desc':
        return tr.achMastery80Desc;
      default:
        return key;
    }
  }
}
