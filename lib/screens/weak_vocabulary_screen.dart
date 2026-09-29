import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/di_container.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/page_transitions.dart';
import '../utils/translations.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/liquid_glass.dart';
import 'pre_study_screen.dart';

enum _WeaknessFilter { all, critical, weak, shaky }

enum _WeakWordSortType { scoreDesc, wrongCountDesc, recentWrong, masteryAsc }

class WeakVocabularyScreen extends StatefulWidget {
  const WeakVocabularyScreen({super.key});

  @override
  State<WeakVocabularyScreen> createState() => _WeakVocabularyScreenState();
}

class _WeakVocabularyScreenState extends State<WeakVocabularyScreen> {
  late Future<WeaknessOverview> _future;
  _WeaknessFilter _filter = _WeaknessFilter.all;
  _WeakWordSortType _sort = _WeakWordSortType.scoreDesc;
  WeaknessOverview? _cachedOverview;
  _WeaknessFilter? _cachedFilter;
  _WeakWordSortType? _cachedSort;
  List<WeakWordEntry> _cachedVisibleEntries = const [];

  @override
  void initState() {
    super.initState();
    _future = DIContainer.instance.weakVocabularyRepository.loadOverview();
  }

  Future<void> _reload() async {
    setState(() {
      _future = DIContainer.instance.weakVocabularyRepository.loadOverview(
        forceRefresh: true,
      );
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FluidBackground(
        child: SafeArea(
          child: FutureBuilder<WeaknessOverview>(
            future: _future,
            builder: (context, snapshot) {
              final overview = snapshot.data;
              final entries = overview == null
                  ? const <WeakWordEntry>[]
                  : _visibleEntries(overview);
              return RefreshIndicator(
                onRefresh: _reload,
                color: FluidTheme.primaryFluidGradient[0],
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          children: [
                            _buildHeader(isDark, snapshot.connectionState),
                            const SizedBox(height: 16),
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                overview == null)
                              _buildLoading(isDark)
                            else if (overview == null ||
                                overview.entries.isEmpty)
                              _buildEmpty(isDark)
                            else ...[
                              _buildOverviewCard(isDark, overview),
                              const SizedBox(height: 16),
                              _buildFilterBar(isDark, overview),
                              const SizedBox(height: 12),
                              _buildSortBar(isDark),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (overview != null && overview.entries.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.builder(
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _WeakWordTile(
                                entry: entry,
                                onExplain: () => _showReason(entry),
                                onReview: () => _startReview([entry]),
                              ),
                            );
                          },
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        sliver: SliverToBoxAdapter(
                          child: FluidButton(
                            text: context.tr.conquerTopWeakWords,
                            icon: Icons.bolt,
                            onPressed: () => _startReview(
                              overview.entries
                                  .where(
                                    (entry) =>
                                        entry.level.priority >=
                                        WeaknessLevel.shaky.priority,
                                  )
                                  .take(10)
                                  .toList(growable: false),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  //筛选/排序结果缓存，条件未变时复用
  List<WeakWordEntry> _visibleEntries(WeaknessOverview overview) {
    if (identical(_cachedOverview, overview) &&
        _cachedFilter == _filter &&
        _cachedSort == _sort) {
      return _cachedVisibleEntries;
    }
    final filtered = overview.entries
        .where((entry) {
          return switch (_filter) {
            _WeaknessFilter.all => true,
            _WeaknessFilter.critical => entry.level == WeaknessLevel.critical,
            _WeaknessFilter.weak => entry.level == WeaknessLevel.weak,
            _WeaknessFilter.shaky => entry.level == WeaknessLevel.shaky,
          };
        })
        .toList(growable: true);
    filtered.sort((a, b) {
      return switch (_sort) {
        _WeakWordSortType.scoreDesc => b.score.compareTo(a.score),
        _WeakWordSortType.wrongCountDesc => b.wrongCount.compareTo(
          a.wrongCount,
        ),
        _WeakWordSortType.recentWrong => b.lastWrongTime.compareTo(
          a.lastWrongTime,
        ),
        _WeakWordSortType.masteryAsc => a.avgSessionScore.compareTo(
          b.avgSessionScore,
        ),
      };
    });
    _cachedOverview = overview;
    _cachedFilter = _filter;
    _cachedSort = _sort;
    _cachedVisibleEntries = List<WeakWordEntry>.unmodifiable(filtered);
    return _cachedVisibleEntries;
  }

  Widget _buildHeader(bool isDark, ConnectionState state) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: FluidTheme.getTextPrimaryColor(isDark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr.weakVocabulary,
                style: FluidTheme.headingMedium(
                  isDark,
                ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
              ),
              Text(
                context.tr.weakVocabularySubtitle,
                style: FluidTheme.bodySmall(
                  isDark,
                ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            state == ConnectionState.waiting
                ? Icons.hourglass_top
                : Icons.refresh,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          onPressed: _reload,
        ),
      ],
    );
  }

  Widget _buildOverviewCard(bool isDark, WeaknessOverview overview) {
    return FluidCard(
      //原为常驻 true，同 wrong_words_screen：关闭常驻 shimmer 以降低噪音
      enableShimmer: false,
      enableBorderGradient: overview.criticalCount > 0,
      borderColors: overview.criticalCount > 0
          ? FluidTheme.errorFluidGradient
          : FluidTheme.warningFluidGradient,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${context.tr.currentWeakWords} ${overview.totalCount}',
            style: FluidTheme.headingSmall(
              isDark,
            ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatPill(
                context.tr.criticalWeak,
                overview.criticalCount,
                FluidTheme.error,
              ),
              const SizedBox(width: 8),
              _buildStatPill(
                context.tr.weakLevelWeak,
                overview.weakCount,
                FluidTheme.warning,
              ),
              const SizedBox(width: 8),
              _buildStatPill(
                context.tr.shakyWeak,
                overview.shakyCount,
                FluidTheme.primaryFluidGradient[0],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${context.tr.averageWeaknessScore} ${overview.averageScore.toStringAsFixed(1)}',
            style: FluidTheme.bodyMedium(
              isDark,
            ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$label $value',
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildFilterBar(bool isDark, WeaknessOverview overview) {
    final items = [
      (_WeaknessFilter.all, context.tr.tabAll),
      (_WeaknessFilter.critical, context.tr.criticalWeak),
      (_WeaknessFilter.weak, context.tr.weakLevelWeak),
      (_WeaknessFilter.shaky, context.tr.shakyWeak),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(isDark, item.$2, () {
                  setState(() => _filter = item.$1);
                }, selected: _filter == item.$1),
              ),
            )
            .toList(),
      ),
    );
  }

  ///筛选胶囊：玻璃模式用玻璃片/发光胶囊，经典模式保留 ChoiceChip
  Widget _buildFilterChip(
    bool isDark,
    String label,
    VoidCallback onTap, {
    required bool selected,
  }) {
    if (context.isLiquidGlass) {
      final accent = FluidTheme.primaryFluidGradient[0];
      final contentColor = selected
          //选中态文字用可读版主色：发光胶囊浅色下接近白底，主色原色仅 1.91:1
          ? FluidTheme.primaryAccessible(isDark)
          : FluidTheme.getTextSecondaryColor(isDark);
      final content = Text(
        label,
        style: TextStyle(
          color: contentColor,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      );
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: selected
            ? GlowCapsule(
                color: accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: content,
              )
            : GlassSurface(
                borderRadius: 999,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: content,
              ),
      );
    }
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: FluidTheme.primaryFluidGradient[0].withValues(alpha: 0.22),
      backgroundColor: FluidTheme.getMutedOverlayColor(isDark),
      labelStyle: TextStyle(
        color: selected
            ? FluidTheme.primaryAccessible(isDark)
            : FluidTheme.getTextSecondaryColor(isDark),
      ),
    );
  }

  Widget _buildSortBar(bool isDark) {
    return DropdownButtonFormField<_WeakWordSortType>(
      // 新版 Flutter 中 initialValue 取代了 value，用于设置初始选中项
      initialValue: _sort,
      decoration: InputDecoration(
        filled: true,
        fillColor: FluidTheme.getMutedOverlayColor(isDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: FluidTheme.getBorderColor(isDark)),
        ),
      ),
      dropdownColor: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.18),
      items: [
        DropdownMenuItem(
          value: _WeakWordSortType.scoreDesc,
          child: Text(context.tr.sortByWeakness),
        ),
        DropdownMenuItem(
          value: _WeakWordSortType.wrongCountDesc,
          child: Text(context.tr.sortByWrongCount),
        ),
        DropdownMenuItem(
          value: _WeakWordSortType.recentWrong,
          child: Text(context.tr.sortByRecentWrong),
        ),
        DropdownMenuItem(
          value: _WeakWordSortType.masteryAsc,
          child: Text(context.tr.sortByMastery),
        ),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _sort = value);
      },
    );
  }

  Widget _buildLoading(bool isDark) {
    return FluidCard(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          context.tr.loading,
          style: FluidTheme.bodyMedium(
            isDark,
          ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return FluidCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.verified,
            size: 56,
            color: FluidTheme.successFluidGradient[0],
          ),
          const SizedBox(height: 12),
          Text(
            context.tr.noWeakWords,
            style: FluidTheme.headingSmall(
              isDark,
            ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr.noWeakWordsDesc,
            textAlign: TextAlign.center,
            style: FluidTheme.bodyMedium(
              isDark,
            ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
          ),
        ],
      ),
    );
  }

  void _showReason(WeakWordEntry entry) {
    showFluidDialog(
      context: context,
      title: context.tr.whyWeak,
      content: _WeakWordReasonSheet(entry: entry),
    );
  }

  void _startReview(List<WeakWordEntry> entries) {
    final words = entries
        .map((entry) => entry.word)
        .where((word) => word.id != null)
        .toList(growable: false);
    if (words.isEmpty) return;
    final request = SpecializedStudyRequest(
      // 用通用复习来源而不是 wrongWords：弱词列表不完全等于错词本，
      // 此前误用 wrongWords 会把弱词练习的"连续答对"写回错词表，
      // 用弱词练习的进度触发错词本的移出判定（语义串台）
      source: StudySource.review,
      title: context.tr.weakVocabularyReviewTitle,
      wordBookId: words.first.wordBookId,
      wordIds: words.map((word) => word.id!).toList(growable: false),
      studyMode: 1,
      isReview: true,
    );
    Navigator.push(
      context,
      PageTransitions.slideFromRight(
        page: PreStudyScreen.specialized(request: request, words: words),
      ),
    );
  }
}

class _WeakWordTile extends StatelessWidget {
  final WeakWordEntry entry;
  final VoidCallback onExplain;
  final VoidCallback onReview;

  const _WeakWordTile({
    required this.entry,
    required this.onExplain,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final color = _levelColor(entry.level);
    return FluidCard(
      enableShimmer: entry.level == WeaknessLevel.critical,
      enableBorderGradient: entry.level.priority >= WeaknessLevel.weak.priority,
      borderColors: [color, FluidTheme.warningFluidGradient.last],
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LevelBadge(level: entry.level),
              const Spacer(),
              Text(
                '${context.tr.weaknessScore} ${entry.score.toStringAsFixed(0)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.word.word,
            style: FluidTheme.headingSmall(
              isDark,
            ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
          ),
          if (entry.word.phonetic.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              entry.word.phonetic,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: FluidTheme.getTextTertiaryColor(isDark)),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            entry.word.definition,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FluidTheme.bodyMedium(
              isDark,
            ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (entry.score / 100).clamp(0.0, 1.0),
            minHeight: 5,
            color: color,
            backgroundColor: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 10),
          Text(
            '${context.tr.wrongCountLabel} ${entry.wrongCount} · ${context.tr.viewedAnswerCountLabel} ${entry.viewedAnswerCount} · ${context.tr.correctStreakLabel} ${entry.consecutiveCorrect}',
            style: FluidTheme.bodySmall(
              isDark,
            ).copyWith(color: FluidTheme.getTextTertiaryColor(isDark)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(onPressed: onExplain, child: Text(context.tr.whyWeak)),
              const Spacer(),
              TextButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.bolt, size: 18),
                label: Text(context.tr.startWeakReview),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _levelColor(WeaknessLevel level) {
    return switch (level) {
      WeaknessLevel.critical => FluidTheme.error,
      WeaknessLevel.weak => FluidTheme.warning,
      WeaknessLevel.shaky => FluidTheme.warningFluidGradient[1],
      WeaknessLevel.normal => FluidTheme.primaryFluidGradient[0],
      WeaknessLevel.solid => Colors.grey,
    };
  }
}

class _LevelBadge extends StatelessWidget {
  final WeaknessLevel level;

  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = _WeakWordTile._levelColor(level);
    final label = switch (level) {
      WeaknessLevel.critical => context.tr.criticalWeak,
      WeaknessLevel.weak => context.tr.weakLevelWeak,
      WeaknessLevel.shaky => context.tr.shakyWeak,
      WeaknessLevel.normal => context.tr.normalWeak,
      WeaknessLevel.solid => context.tr.solidWeak,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _WeakWordReasonSheet extends StatelessWidget {
  final WeakWordEntry entry;

  const _WeakWordReasonSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BreakdownBar(
          label: context.tr.wrongFrequency,
          value: entry.breakdown.wrongFreqScore,
          max: 30,
        ),
        _BreakdownBar(
          label: context.tr.masteryGap,
          value: entry.breakdown.masteryScore,
          max: 25,
        ),
        _BreakdownBar(
          label: context.tr.memoryStability,
          value: entry.breakdown.memoryScore,
          max: 20,
        ),
        _BreakdownBar(
          label: context.tr.recentMistake,
          value: entry.breakdown.recencyScore,
          max: 15,
        ),
        _BreakdownBar(
          label: context.tr.behaviorSignal,
          value: entry.breakdown.behaviorScore,
          max: 10,
        ),
      ],
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;

  const _BreakdownBar({
    required this.label,
    required this.value,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: FluidTheme.bodySmall(
                    isDark,
                  ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
                ),
              ),
              Text('${value.toStringAsFixed(0)} / ${max.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (value / max).clamp(0.0, 1.0),
            color: FluidTheme.warningFluidGradient[0],
            backgroundColor: FluidTheme.warningFluidGradient[0].withValues(
              alpha: 0.12,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }
}
