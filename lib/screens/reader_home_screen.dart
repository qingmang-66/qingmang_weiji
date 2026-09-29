import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/providers/providers.dart';
import '../theme/fluid_theme.dart';
import '../utils/guide_keys.dart';
import '../utils/page_transitions.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../utils/wordbook_localization.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_card.dart';
import 'wordbook_reader_screen.dart';

/// 阅读书架：列出词书，点击进入小说式翻页阅读
class ReaderHomeScreen extends StatefulWidget {
  const ReaderHomeScreen({super.key});

  @override
  State<ReaderHomeScreen> createState() => _ReaderHomeScreenState();
}

class _ReaderHomeScreenState extends State<ReaderHomeScreen> {
  //词书id -> 已读到的词序号
  Map<int, int> _progressMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    //post-frame 触发，避免加载中 notifyListeners 打断 build
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProgress());
  }

  Future<void> _loadProgress() async {
    final provider = context.read<WordBookProvider>();
    //书架常驻tab，可能早于词书列表加载，这里兜底刷新
    if (provider.wordBooks.isEmpty) {
      await provider.loadWordBooks();
    }
    final ids = provider.wordBooks.map((b) => b.id).whereType<int>().toList();
    final map = await DatabaseService.readerDao.getProgressMap(ids);
    if (!mounted) return;
    setState(() {
      _progressMap = map;
      _loading = false;
    });
  }

  Future<void> _openReader(WordBook book) async {
    //book.id 为 int?，防御脏数据：无 id 的词书无法进入阅读器，直接跳过
    final bookId = book.id;
    if (bookId == null) return;
    await Navigator.push(
      context,
      PageTransitions.slideFromRight(
        page: WordbookReaderScreen(bookId: bookId),
      ),
    );
    if (mounted) setState(() => _loading = true);
    await _loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    //风格在 build 里订阅一次：itemBuilder 回调里再调 context.select 会
    //每帧抛 provider 断言（见回忆模式引导的同款修法）
    final isGlass = context.select<ThemeProvider, bool>((p) => p.isLiquidGlass);
    // 订阅粒度收窄到 wordBooks：provider 其它字段（dueCount、加载态等）
    // 的通知不再重建整个书架页
    final books = context.select((WordBookProvider p) => p.wordBooks);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    return FluidBackground(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                FluidGradientContainer(
                  colors: FluidTheme.primaryFluidGradient,
                  borderRadius: FluidTheme.smallBorderRadius,
                  padding: const EdgeInsets.all(10),
                  animationDuration: const Duration(seconds: 8),
                  child: const Icon(
                    Icons.auto_stories,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  context.tr.readerMode,
                  style: FluidTheme.headingMedium(
                    isDark,
                  ).copyWith(color: textPrimary),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : books.isEmpty
                ? KeyedSubtree(
                    key: guideReaderEmptyKey,
                    child: _emptyState(isDark),
                  )
                : ReorderableListView.builder(
                    //与词库页同一套排序交互：桌面端拖右侧手柄，移动端长按整卡
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) {
                      context.read<WordBookProvider>().reorderWordBooks(
                        oldIndex,
                        newIndex,
                      );
                    },
                    //底部动态避让悬浮导航条，固定 24 会被遮
                    padding: EdgeInsets.fromLTRB(
                      20,
                      4,
                      20,
                      MediaQuery.paddingOf(context).bottom + 16,
                    ),
                    itemCount: books.length,
                    itemBuilder: (context, i) {
                      final card = _bookCard(
                        books[i],
                        isDark,
                        isGlass,
                        dragHandleIndex: PlatformAdapt.isDesktop ? i : null,
                      );
                      final draggable = PlatformAdapt.isDesktop
                          ? card
                          : ReorderableDelayedDragStartListener(
                              index: i,
                              child: card,
                            );
                      //排序 key 必须挂在 itemBuilder 顶层；引导锚点只给第一本
                      return KeyedSubtree(
                        key: ValueKey(books[i].id ?? i),
                        child: i == 0
                            ? KeyedSubtree(
                                key: guideReaderBookKey,
                                child: draggable,
                              )
                            : draggable,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool isDark) {
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 56,
            color: textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr.readerEmptyHint,
            style: FluidTheme.bodyMedium(isDark).copyWith(color: textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _bookCard(
    WordBook book,
    bool isDark,
    bool isGlass, {
    int? dragHandleIndex,
  }) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final total = book.totalWords;
    final idx = _progressMap[book.id] ?? -1;
    final started = idx >= 0 && total > 0;
    final pct = started ? ((idx + 1) / total).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FluidCard(
        enableShimmer: false,
        padding: const EdgeInsets.all(16),
        onTap: () => _openReader(book),
        child: Row(
          children: [
            FluidGradientContainer(
              colors: FluidTheme.primaryFluidGradient,
              borderRadius: 10,
              padding: const EdgeInsets.all(10),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.wordBookName(book.name),
                    style: FluidTheme.labelLarge(
                      isDark,
                    ).copyWith(color: textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr.readerWordsCount(total),
                    style: FluidTheme.bodySmall(
                      isDark,
                    ).copyWith(color: textSecondary),
                  ),
                  if (started) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 4,
                        backgroundColor: FluidTheme.getProgressTrackColor(
                          isDark,
                          isGlass,
                        ),
                        valueColor: AlwaysStoppedAnimation(
                          FluidTheme.primaryFluidGradient[0],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr.readerProgressLabel(
                        idx + 1,
                        total,
                        (pct * 100).round(),
                      ),
                      style: FluidTheme.bodySmall(
                        isDark,
                      ).copyWith(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: textSecondary),
            //桌面端排序手柄：阅读书架也要能像词库页一样调整顺序
            if (dragHandleIndex != null)
              ReorderableDragStartListener(
                index: dragHandleIndex,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: PlatformAdapt.isDesktop ? 8 : 4,
                      right: 4,
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      size: PlatformAdapt.isDesktop ? 30 : 20,
                      color: textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
