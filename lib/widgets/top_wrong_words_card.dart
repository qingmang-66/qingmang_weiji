import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import 'fluid_loading.dart';

/// 阶段四：高频错词 Top N 通用卡片
///
/// 用于：
/// - 统计页（Top 10）
/// - 周报（Top 5）
/// - 月报（Top 10）
class TopWrongWordsCard extends StatefulWidget {
  /// 取前几条
  final int limit;

  /// 仅看时间窗口（null = 全部）
  final DateTime? since;

  /// 是否显示"查看全部"按钮
  final bool showViewAll;

  /// 整张卡片标题（可空，默认 "高频错词"）
  final String? title;

  const TopWrongWordsCard({
    super.key,
    this.limit = 10,
    this.since,
    this.showViewAll = true,
    this.title,
  });

  @override
  State<TopWrongWordsCard> createState() => _TopWrongWordsCardState();
}

class _TopWrongWordsCardState extends State<TopWrongWordsCard> {
  late Future<List<WrongWordRankingItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(TopWrongWordsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.limit != widget.limit || oldWidget.since != widget.since) {
      _future = _load();
    }
  }

  Future<List<WrongWordRankingItem>> _load() async {
    // 拉取全量后截断，让业务层做排序
    final service = DIContainer.instance.wrongWordRankingService;
    return service.getTopWrongWords(limit: widget.limit, since: widget.since);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: FluidTheme.getSurfaceGradientColors(isDark),
        ),
        borderRadius: BorderRadius.circular(FluidTheme.cardBorderRadius),
        border: Border.all(color: FluidTheme.getBorderColor(isDark), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: FluidTheme.errorFluidGradient,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_fire_department_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title ?? context.tr.topWrongWords,
                    style: FluidTheme.labelLarge(
                      isDark,
                    ).copyWith(color: textPrimary),
                  ),
                ),
                if (widget.showViewAll)
                  TextButton(
                    onPressed: () {
                      // 跳转到错词页（按热度排序）
                      Navigator.of(context).pushNamed('/wrong-words');
                    },
                    child: Text(
                      context.tr.refresh,
                      style: TextStyle(color: FluidTheme.accentPrimary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.tr.topWrongWordsDesc,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textSecondary),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<WrongWordRankingItem>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: FluidLoading(),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      context.tr.initFailed,
                      style: TextStyle(color: textSecondary),
                    ),
                  );
                }
                final items = snapshot.data ?? const <WrongWordRankingItem>[];
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr.noWrongWordsRanked,
                          style: FluidTheme.labelLarge(
                            isDark,
                          ).copyWith(color: textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr.noWrongWordsRankedHint,
                          style: FluidTheme.bodySmall(
                            isDark,
                          ).copyWith(color: textSecondary),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: List.generate(items.length, (i) {
                    return WrongWordRankingItemTile(
                      rank: i + 1,
                      item: items[i],
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 单条排行项的展示组件
class WrongWordRankingItemTile extends StatelessWidget {
  final int rank;
  final WrongWordRankingItem item;

  /// 紧凑模式（用于周报/月报）
  final bool compact;

  const WrongWordRankingItemTile({
    super.key,
    required this.rank,
    required this.item,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final dangerColor = FluidTheme.error;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 排名
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _rankColor(isDark, rank).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$rank',
              style: FluidTheme.labelLarge(isDark).copyWith(
                color: _rankColor(isDark, rank),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 单词信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.word.word,
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.word.phonetic.isNotEmpty)
                  Text(
                    item.word.phonetic,
                    style: FluidTheme.bodySmall(
                      isDark,
                    ).copyWith(color: textSecondary, fontSize: 11),
                  ),
                if (!compact && item.word.definition.isNotEmpty)
                  Text(
                    item.word.definition,
                    style: FluidTheme.bodySmall(
                      isDark,
                    ).copyWith(color: textSecondary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 评分
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: dangerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.score.toStringAsFixed(0),
              style: FluidTheme.labelLarge(
                isDark,
              ).copyWith(color: dangerColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Color _rankColor(bool isDark, int rank) {
    if (rank == 1) return const Color(0xFFFFB300);
    if (rank == 2) return const Color(0xFFBDBDBD);
    if (rank == 3) return const Color(0xFFB87333);
    return FluidTheme.error;
  }
}
