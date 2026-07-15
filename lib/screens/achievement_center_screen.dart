import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/achievement_category.dart';
import '../models/achievement_progress.dart';
import '../services/di_container.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import '../widgets/achievement_category_filter.dart';
import '../widgets/achievement_tile.dart';
import '../widgets/fluid_background.dart';

/// 阶段四：成就中心主页
class AchievementCenterScreen extends StatefulWidget {
  const AchievementCenterScreen({super.key});

  @override
  State<AchievementCenterScreen> createState() =>
      _AchievementCenterScreenState();
}

class _AchievementCenterScreenState extends State<AchievementCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  AchievementCategory? _category;
  List<AchievementProgress> _all = const [];
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final repo = DIContainer.instance.achievementRepository;
      final list = await repo.loadAndCheck();
      if (!mounted) return;
      setState(() => _all = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final unlockedCount = _all.where((a) => a.isUnlocked).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FluidBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark, unlockedCount),
              TabBar(
                controller: _tab,
                labelColor: FluidTheme.primaryFluidGradient.first,
                unselectedLabelColor: FluidTheme.getTextSecondaryColor(isDark),
                indicatorColor: FluidTheme.primaryFluidGradient.first,
                tabs: [
                  Tab(text: context.tr.tabAll),
                  Tab(text: context.tr.tabUnlocked),
                  Tab(text: context.tr.tabLocked),
                ],
              ),
              const SizedBox(height: 8),
              AchievementCategoryFilter(
                selected: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _buildList(_AchievementFilter.all),
                    _buildList(_AchievementFilter.unlocked),
                    _buildList(_AchievementFilter.locked),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(_AchievementFilter filter) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr.loadAchievementsFailed),
            const SizedBox(height: 8),
            TextButton(onPressed: _refresh, child: Text(context.tr.retry)),
          ],
        ),
      );
    }
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final list = _all.where((a) {
      if (_category != null && a.definition.category != _category) {
        return false;
      }
      switch (filter) {
        case _AchievementFilter.all:
          return true;
        case _AchievementFilter.unlocked:
          return a.isUnlocked;
        case _AchievementFilter.locked:
          return !a.isUnlocked;
      }
    }).toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: FluidTheme.getTextTertiaryColor(isDark),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr.noAchievementsInCategory,
              style: FluidTheme.bodyMedium(isDark),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.78,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: list.length,
        itemBuilder: (ctx, i) => AchievementTile(progress: list[i]),
      ),
    );
  }

  Widget _buildHeader(bool isDark, int unlocked) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
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
            child: Text(
              context.tr.achievementCenter,
              style: FluidTheme.headingSmall(isDark),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: FluidTheme.warningFluidGradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$unlocked/${_all.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 状态过滤维度
enum _AchievementFilter { all, unlocked, locked }
