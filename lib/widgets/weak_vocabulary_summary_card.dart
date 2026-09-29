import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/weakness_overview.dart';
import '../screens/weak_vocabulary_screen.dart';
import '../services/di_container.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/page_transitions.dart';
import '../utils/translations.dart';
import 'fluid_card.dart';

class WeakVocabularySummaryCard extends StatefulWidget {
  const WeakVocabularySummaryCard({super.key, this.refreshToken = 0});

  /// 外部刷新信号：首页在「学习返回 / 下拉刷新 / 数据库刷新」时自增，
  /// 卡片据此重建数据。否则 future 只在 initState 建一次，刚学完产生的
  /// 新错词要等整页重建才会出现。
  final int refreshToken;

  @override
  State<WeakVocabularySummaryCard> createState() =>
      _WeakVocabularySummaryCardState();
}

class _WeakVocabularySummaryCardState
    extends State<WeakVocabularySummaryCard> {
  //Future 放进 State：首页频繁重建，若在 build 中新建 future，
  //FutureBuilder 会不断重置状态，缓存过期后每次重建都触发一次全量聚合查询
  late Future<WeaknessOverview> _future;

  @override
  void initState() {
    super.initState();
    _future = DIContainer.instance.weakVocabularyRepository.loadOverview();
  }

  @override
  void didUpdateWidget(covariant WeakVocabularySummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      //收到刷新信号时绕过 TTL 缓存，保证刚产生的错词立即可见
      setState(() {
        _future = DIContainer.instance.weakVocabularyRepository.loadOverview(
          forceRefresh: true,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeaknessOverview>(
      future: _future,
      builder: (context, snapshot) {
        final overview = snapshot.data;
        if (overview == null || overview.totalCount == 0) {
          return const SizedBox.shrink();
        }
        final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
        return FluidCard(
          enableShimmer: overview.criticalCount > 0,
          enableBorderGradient: true,
          borderColors: overview.criticalCount > 0
              ? FluidTheme.errorFluidGradient
              : FluidTheme.warningFluidGradient,
          padding: const EdgeInsets.all(16),
          onTap: () {
            Navigator.push(
              context,
              PageTransitions.slideFromRight(
                page: const WeakVocabularyScreen(),
              ),
            );
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FluidTheme.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology_alt,
                  color: FluidTheme.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr.weakVocabulary,
                      style: FluidTheme.labelLarge(
                        isDark,
                      ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.tr.criticalWeak} ${overview.criticalCount} · ${context.tr.weakLevelWeak} ${overview.weakCount}',
                      style: FluidTheme.bodyMedium(isDark).copyWith(
                        color: FluidTheme.getTextSecondaryColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: FluidTheme.getTextTertiaryColor(isDark),
              ),
            ],
          ),
        );
      },
    );
  }
}
