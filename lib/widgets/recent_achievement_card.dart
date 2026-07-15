import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/achievement_progress.dart';
import '../screens/achievement_center_screen.dart';
import '../services/di_container.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import 'achievement_tile.dart';
import 'fluid_background.dart';
import 'fluid_card.dart';

/// 阶段四：首页"最近成就"卡片
///
/// 展示最近 3 条已解锁成就，溢出箭头跳转成就中心。
class RecentAchievementCard extends StatelessWidget {
  const RecentAchievementCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final repo = DIContainer.instance.achievementRepository;
    return FutureBuilder<List<AchievementProgress>>(
      future: repo.getRecent(limit: 3),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final list = snap.data ?? const <AchievementProgress>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return FluidCard(
          enableShimmer: false,
          padding: const EdgeInsets.all(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AchievementCenterScreen(),
              ),
            );
          },
          child: Row(
            children: [
              FluidGradientContainer(
                colors: FluidTheme.warningFluidGradient,
                borderRadius: FluidTheme.smallBorderRadius,
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr.recentAchievements,
                      style: FluidTheme.labelLarge(isDark),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: list
                          .map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: AchievementTile(
                                progress: p,
                                compact: true,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: FluidTheme.getTextSecondaryColor(isDark),
              ),
            ],
          ),
        );
      },
    );
  }
}
