import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/providers/providers.dart';
import '../services/asset_wordbook_service.dart';
import '../theme/fluid_theme.dart';
import '../utils/guide_keys.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../utils/error_handler.dart';
import '../utils/page_transitions.dart';
import '../utils/wordbook_localization.dart';
import '../widgets/anchored_menu.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/fluid_loading.dart';
import '../widgets/liquid_controls.dart';
import '../widgets/wordbook_badge.dart';
import '../widgets/liquid_glass.dart';
import 'word_detail_screen.dart';

/// 词库管理页 - 流体渐变风格
class WordBookScreen extends StatefulWidget {
  const WordBookScreen({super.key});

  @override
  State<WordBookScreen> createState() => _WordBookScreenState();
}

class _WordBookScreenState extends State<WordBookScreen> {
  bool _isImporting = false;
  int _importProgress = 0;
  int _importTotal = 0;
  Future<Map<int, WordBookProgress>>? _progressFuture;
  // 构建 _progressFuture 时使用的词库 id，用于感知列表变化后重建
  List<int> _progressBookIds = const [];

  // 多选模式状态
  bool _isMultiSelectMode = false;
  Set<int> _selectedBookIds = {};

  // 批量导入模式状态
  bool _isBatchImportMode = false;
  final Set<String> _selectedBuiltInBooks = {};

  @override
  void initState() {
    super.initState();
    _refreshProgressFuture();
  }

  void _refreshProgressFuture() {
    final provider = context.read<WordBookProvider>();
    final bookIds = _bookIdsOf(provider);
    _progressBookIds = bookIds;
    _progressFuture = DIContainer.instance.reviewRepository
        .getWordBookProgressMap(bookIds);
  }

  static List<int> _bookIdsOf(WordBookProvider provider) => provider.wordBooks
      .map((book) => book.id)
      .whereType<int>()
      .toList(growable: false);

  /// 词库列表变化时重建进度 Future。
  /// WordBookProvider.init() 是异步的：首帧词库为空 → 进度查询返回空 map，
  /// 若不同步重建，卡片会一直显示「0 已学 / 0 待复习」且只能靠下拉刷新自愈。
  void _syncProgressFuture(WordBookProvider provider) {
    final bookIds = _bookIdsOf(provider);
    var same = _progressBookIds.length == bookIds.length;
    if (same) {
      for (var i = 0; i < bookIds.length; i++) {
        if (_progressBookIds[i] != bookIds[i]) {
          same = false;
          break;
        }
      }
    }
    if (same) return;
    _progressBookIds = bookIds;
    _progressFuture = DIContainer.instance.reviewRepository
        .getWordBookProgressMap(bookIds);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WordBookProvider>();
    //词库列表异步加载完成/增删词库后同步重建进度 Future（幂等）
    _syncProgressFuture(provider);

    // 首页 Tab 外层已有顶部 SafeArea
    return RepaintBoundary(
      child: FluidBackground(
        child: Column(
          children: [
            _buildAppBar(provider),
            if (_isImporting) _buildImportProgress(),
            if (_isMultiSelectMode) _buildBatchDeleteBar(),
            Expanded(child: _buildWordBookList(provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(WordBookProvider provider) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final iconColor = FluidTheme.getTextSecondaryColor(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          FluidGradientContainer(
            colors: FluidTheme.primaryFluidGradient,
            borderRadius: FluidTheme.smallBorderRadius,
            padding: const EdgeInsets.all(10),
            animationDuration: const Duration(seconds: 8),
            child: const Icon(Icons.menu_book, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 14),
          // 标题在窄屏 + 英文 + 多选态下会与右侧图标按钮挤在一起，
          // 用 Expanded + 省略号，保证右侧按钮不被顶出屏幕
          Expanded(
            child: Text(
              _isMultiSelectMode
                  ? '${context.tr.selectedCount} ${_selectedBookIds.length}${context.tr.wordBooksCount}'
                  : context.tr.wordBooksTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FluidTheme.headingMedium(
                isDark,
              ).copyWith(color: textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          if (_isMultiSelectMode) ...[
            IconButton(
              icon: Icon(
                _selectedBookIds.length == provider.wordBooks.length
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: iconColor,
              ),
              onPressed: () {
                if (_selectedBookIds.length == provider.wordBooks.length) {
                  setState(() => _selectedBookIds.clear());
                } else {
                  setState(() {
                    _selectedBookIds = provider.wordBooks
                        .map((b) => b.id)
                        .whereType<int>()
                        .toSet();
                  });
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.close, color: iconColor),
              onPressed: _exitMultiSelectMode,
            ),
          ],
          if (!_isMultiSelectMode) ...[
            IconButton(
              key: guideWordBookImportKey,
              icon: Icon(Icons.download, color: iconColor),
              onPressed: _showBuiltInBooksDialog,
              tooltip: context.tr.builtInBooks,
            ),
            IconButton(
              key: guideWordBookBatchKey,
              icon: Icon(Icons.checklist, color: iconColor),
              onPressed: provider.wordBooks.isEmpty
                  ? null
                  : _enterMultiSelectMode,
              tooltip: context.tr.batchDelete,
            ),
            IconButton(
              icon: Icon(Icons.add, color: iconColor),
              onPressed: _showCreateDialog,
              tooltip: context.tr.createWordBook,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImportProgress() {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final isGlass = context.isLiquidGlass;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: FluidCard(
        enableShimmer: false,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _importTotal > 0 ? _importProgress / _importTotal : 0,
              backgroundColor: FluidTheme.getProgressTrackColor(
                isDark,
                isGlass,
              ),
              valueColor: AlwaysStoppedAnimation<Color>(
                FluidTheme.primaryFluidGradient[0],
              ),
              borderRadius: BorderRadius.circular(4),
              minHeight: 4,
            ),
            const SizedBox(height: 8),
            Text(
              '${context.tr.importing} ($_importProgress/$_importTotal)',
              style: FluidTheme.bodyMedium(
                isDark,
              ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
            ),
          ],
        ),
      ),
    );
  }

  /// 多选底部操作条
  ///
  /// 布局：主操作占满剩余宽度的胶囊（未选中时是禁用态提示），
  /// 取消固定为右侧 48dp 圆形图标按钮 —— 早先是「长胶囊 + 文字链接」，
  /// 两个控件基线不同、右边缘参差，看着别扭。
  Widget _buildBatchDeleteBar() {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final iconColor = FluidTheme.getTextSecondaryColor(isDark);
    final hasSelection = _selectedBookIds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        //液态玻璃模式下半透明底部栏
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.12),
        border: Border(
          top: BorderSide(color: FluidTheme.getBorderColor(isDark)),
        ),
      ),
      child: SafeArea(
        //本栏实际位于页面顶部（AppBar 之下），只用于状态栏避让；
        //若保持默认 bottom:true，会把主 Scaffold extendBody 注入的
        //悬浮导航条高度全额应用到栏下方，形成一大截死空白。
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: FluidButton(
                text: hasSelection
                    ? '${context.tr.deleteCount} ${_selectedBookIds.length}${context.tr.wordBooksCount}'
                    : context.tr.pleaseSelect,
                icon: hasSelection ? Icons.delete_outline : Icons.touch_app,
                fontSize: 14,
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                isEnabled: hasSelection,
                onPressed: hasSelection ? _confirmBatchDelete : null,
                colors: FluidTheme.errorFluidGradient,
              ),
            ),
            const SizedBox(width: 12),
            //圆形取消：与胶囊等高，视觉上成组而不是"吊在一边的链接"
            Tooltip(
              message: context.tr.exitMultiSelect,
              child: SizedBox(
                width: 46,
                height: 46,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _exitMultiSelectMode,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: FluidTheme.getMutedOverlayColor(isDark),
                        border: Border.all(
                          color: FluidTheme.getBorderColor(isDark),
                        ),
                      ),
                      child: Icon(Icons.close, size: 20, color: iconColor),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordBookList(WordBookProvider provider) {
    if (provider.isLoading) {
      return Center(child: FluidLoading(message: context.tr.loading));
    }

    if (provider.wordBooks.isEmpty) {
      return _buildEmptyState();
    }

    return FutureBuilder<Map<int, WordBookProgress>>(
      future: _progressFuture,
      builder: (context, snapshot) {
        final progressMap = snapshot.data ?? const <int, WordBookProgress>{};
        return _isMultiSelectMode
            ? ListView.builder(
                //底部动态避让悬浮导航条（extendBody 注入的 padding.bottom）
                padding: EdgeInsets.only(
                  top: 8,
                  bottom: MediaQuery.paddingOf(context).bottom + 16,
                ),
                itemCount: provider.wordBooks.length,
                itemBuilder: (context, index) {
                  final book = provider.wordBooks[index];
                  if (book.id == null) return const SizedBox.shrink();
                  final isSelected = provider.currentBook?.id == book.id;
                  final isChecked = _selectedBookIds.contains(book.id);
                  return _WordBookCard(
                    book: book,
                    isSelected: isSelected,
                    isChecked: isChecked,
                    isMultiSelectMode: _isMultiSelectMode,
                    onTap: () {
                      setState(() {
                        if (isChecked) {
                          _selectedBookIds.remove(book.id);
                        } else {
                          _selectedBookIds.add(book.id!);
                        }
                      });
                    },
                    onBrowse: () => _browseWords(book),
                    onDelete: () => _confirmDelete(book),
                    onShowInfo: () => _showBookInfo(book, progressMap[book.id]),
                    onResetProgress: () => _confirmResetProgress(book),
                    isShuffled: provider.isShuffledOrder(book.id),
                    onToggleSort: () => provider.setShuffledOrder(
                      book,
                      !provider.isShuffledOrder(book.id),
                    ),
                  );
                },
              )
            : ReorderableListView.builder(
                buildDefaultDragHandles: false, // 不使用默认的左侧拖拽手柄
                //底部动态避让悬浮导航条
                padding: EdgeInsets.only(
                  top: 8,
                  bottom: MediaQuery.paddingOf(context).bottom + 16,
                ),
                itemCount: provider.wordBooks.length,
                onReorder: (oldIndex, newIndex) {
                  provider.reorderWordBooks(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final book = provider.wordBooks[index];
                  if (book.id == null) {
                    //ReorderableListView 要求每个条目带 Key，无 Key 会触发框架断言
                    return SizedBox.shrink(key: ValueKey('null_book_$index'));
                  }
                  final isSelected = provider.currentBook?.id == book.id;
                  final isChecked = _selectedBookIds.contains(book.id);
                  //桌面端用右侧手柄启动拖拽，移动端仍长按整卡
                  final handleIndex = PlatformAdapt.isDesktop ? index : null;
                  final card = _WordBookCard(
                    book: book,
                    isSelected: isSelected,
                    isChecked: isChecked,
                    isMultiSelectMode: _isMultiSelectMode,
                    dragHandleIndex: handleIndex,
                    onTap: () {
                      provider.selectWordBook(book);
                    },
                    onBrowse: () => _browseWords(book),
                    onDelete: () => _confirmDelete(book),
                    onShowInfo: () => _showBookInfo(book, progressMap[book.id]),
                    onResetProgress: () => _confirmResetProgress(book),
                    isShuffled: provider.isShuffledOrder(book.id),
                    onToggleSort: () => provider.setShuffledOrder(
                      book,
                      !provider.isShuffledOrder(book.id),
                    ),
                  );
                  // 移动端：排序靠**长按整张卡片**触发。桌面端由卡片右侧手柄
                  // （dragHandleIndex）启动，这里不再包整卡监听器——
                  // ReorderableDragStartListener 会立刻抢占手势，把「更多」菜单
                  // 和点选词库一起吃掉。
                  // 多选不再由长按触发，改由顶栏的批量删除入口进入，两者不冲突。
                  final draggable = PlatformAdapt.isDesktop
                      ? card
                      : ReorderableDelayedDragStartListener(
                          index: index,
                          child: card,
                        );
                  // 排序用的 key 必须挂在 itemBuilder 的顶层（拖拽靠它追踪条目），
                  // 引导锚点只能再套一层，且只给第一张卡片，避免拖拽后 key 跟着换人
                  return KeyedSubtree(
                    key: ValueKey(book.id),
                    child: index == 0
                        ? KeyedSubtree(
                            key: guideWordBookFirstKey,
                            child: draggable,
                          )
                        : draggable,
                  );
                },
              );
      },
    );
  }

  Widget _buildEmptyState() {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FluidGradientContainer(
              colors: FluidTheme.primaryFluidGradient,
              borderRadius: 50,
              padding: const EdgeInsets.all(24),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr.noWordBooksYet,
              style: FluidTheme.headingMedium(
                isDark,
              ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr.noWordBooksDesc,
              style: FluidTheme.bodyMedium(
                isDark,
              ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
            ),
            const SizedBox(height: 32),
            // 两个按钮统一宽度：此前各自按内容定宽，中文下「添加内置词库」
            // 明显长于「创建词库」，两个胶囊一长一短很突兀。
            // Wrap 保证窄屏 / 大字体下仍能换行不溢出。
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                FluidButton(
                  text: context.tr.addBuiltIn,
                  icon: Icons.download,
                  width: _emptyActionWidth(context),
                  onPressed: _showBuiltInBooksDialog,
                ),
                FluidButton(
                  text: context.tr.createWordBook,
                  icon: Icons.add,
                  width: _emptyActionWidth(context),
                  onPressed: _showCreateDialog,
                  colors: FluidTheme.successFluidGradient,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 空态两个操作按钮的统一宽度：以较长的「添加内置词库」为基准，
  /// 窄屏时收缩到安全宽度内（按钮内的 FittedBox 会等比缩小文字，不会溢出）
  double _emptyActionWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return math.min(240.0, math.max(160.0, screenWidth - 96));
  }

  void _enterMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = true;
      _selectedBookIds.clear();
    });
  }

  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedBookIds.clear();
    });
  }

  void _confirmBatchDelete() {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    showFluidDialog(
      context: context,
      content: Text(
        '${context.tr.confirmDeleteBooks} ${_selectedBookIds.length}${context.tr.wordBooksCount}',
        style: FluidTheme.bodyMedium(isDark).copyWith(color: textPrimary),
      ),
      title: context.tr.confirmDeleteTitle,
      actions: [
        FluidTextButton(
          text: context.tr.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        FluidButton(
          text: context.tr.delete,
          onPressed: () {
            Navigator.pop(context);
            _executeBatchDelete();
          },
          colors: FluidTheme.errorFluidGradient,
        ),
      ],
    );
  }

  void _executeBatchDelete() async {
    final ids = _selectedBookIds.toList();
    _exitMultiSelectMode();
    try {
      await context.read<WordBookProvider>().deleteWordBooksBatch(ids);
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(
          context,
          e,
          fallbackMessage: context.tr.confirmDeleteTitle,
        );
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.tr.deletedCount} ${ids.length}${context.tr.wordBooksCount}',
          ),
          backgroundColor: FluidTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _showCreateDialog() async {
    final themeProvider = context.read<ThemeProvider>();
    final result = await showFluidDialog<({String name, String desc})>(
      context: context,
      content: _CreateBookForm(isDark: themeProvider.isDarkMode),
      title: context.tr.createWordBook,
    );
    //对话框关闭（确认返回结果 / 取消或遮罩返回 null）后再执行创建，
    //避免异步创建期间对话框被遮罩关闭导致 pop 误弹词库页
    if (result == null || !mounted) return;
    final provider = context.read<WordBookProvider>();
    try {
      await provider.createWordBook(result.name, result.desc);
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(
          context,
          e,
          fallbackMessage: context.tr.createWordBook,
        );
      }
    }
  }

  void _browseWords(WordBook book) {
    showFluidDialog(
      context: context,
      // 内容自带定高（屏幕 60%）与内层 ListView，再套一层外层滚动只会多出
      // 一个无用的 Scrollable 与手势识别器（外层永远不会真正滚动）
      scrollable: false,
      content: _WordListSheet(
        book: book,
        onRefresh: () {
          context.read<WordBookProvider>().loadWordBooks();
        },
      ),
    );
  }

  /// 词库信息二级弹窗：完成度 / 总词数 / 已学 / 未学 / 待复习。
  ///
  /// 移动端屏幕窄，这些统计直接铺在卡片上会把卡片撑得很高、信息密度失衡，
  /// 统一收进这里查看（入口是卡片右侧「信息」按钮，见 [_WordBookCard]）。
  void _showBookInfo(WordBook book, WordBookProgress? progress) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final stats =
        progress ??
        WordBookProgress(
          bookId: book.id ?? 0,
          totalWords: book.totalWords,
          unlearnedWords: book.totalWords,
          dueWords: 0,
        );

    Widget infoRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: FluidTheme.bodyMedium(
                  isDark,
                ).copyWith(color: textSecondary),
              ),
            ),
            Text(
              value,
              style: FluidTheme.labelLarge(isDark).copyWith(color: textPrimary),
            ),
          ],
        ),
      );
    }

    showFluidDialog(
      context: context,
      title: context.wordBookName(book.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: stats.learnedRatio,
              minHeight: 8,
              backgroundColor: FluidTheme.getProgressTrackColor(
                isDark,
                // 这里在弹窗回调里，不在 build 中：不能用 context.isLiquidGlass
                // （内部是 context.select，会触发 provider 断言）
                context.read<ThemeProvider>().isLiquidGlass,
              ),
              valueColor: AlwaysStoppedAnimation<Color>(
                FluidTheme.primaryFluidGradient[0],
              ),
            ),
          ),
          const SizedBox(height: 16),
          infoRow(context.tr.progressPercentLabel, '${stats.learnedPercent}%'),
          infoRow(context.tr.totalWordsLabel, '${stats.totalWords}'),
          infoRow(context.tr.learnedWordsLabel, '${stats.learnedWords}'),
          infoRow(context.tr.unlearnedWordsLabel, '${stats.unlearnedWords}'),
          infoRow(context.tr.dueReviewsLabel, '${stats.dueWords}'),
        ],
      ),
      actions: [
        FluidButton(
          text: context.tr.confirm,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  /// 重置词库学习进度：二次确认后清复习记录/错词/会话/阅读进度，保留单词
  void _confirmResetProgress(WordBook book) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final tr = context.tr;
    showFluidDialog(
      context: context,
      title: tr.t('重置学习进度', 'Reset Progress'),
      content: Text(
        tr.t(
          '将清除「${context.wordBookName(book.name)}」的复习记录、错词本、学习会话与阅读进度，单词本身保留。此操作不可恢复。',
          'This clears review records, wrong words, study sessions and reading progress for "${book.name}". Words are kept. This cannot be undone.',
        ),
        style: FluidTheme.bodyMedium(isDark),
      ),
      actions: [
        FluidTextButton(
          text: tr.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        FluidButton(
          text: tr.t('重置', 'Reset'),
          onPressed: () async {
            Navigator.pop(context);
            try {
              await context.read<WordBookProvider>().resetWordBookProgress(
                book.id!,
              );
              //进度卡片与统计缓存都要重取
              setState(_refreshProgressFuture);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr.t('学习进度已重置', 'Progress reset'))),
                );
              }
            } catch (e) {
              if (mounted) {
                ErrorHandler.handleException(context, e);
              }
            }
          },
        ),
      ],
    );
  }

  void _confirmDelete(WordBook book) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    showFluidDialog(
      context: context,
      content: Text(
        '${context.tr.confirmDeleteBook} "${context.wordBookName(book.name)}"?',
        style: FluidTheme.bodyMedium(isDark),
      ),
      title: context.tr.confirmDeleteTitle,
      actions: [
        FluidTextButton(
          text: context.tr.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        FluidButton(
          text: context.tr.delete,
          onPressed: () async {
            Navigator.pop(context);
            try {
              await context.read<WordBookProvider>().deleteWordBook(book.id!);
            } catch (e) {
              if (mounted) {
                ErrorHandler.handleException(
                  context,
                  e,
                  fallbackMessage: context.tr.confirmDeleteTitle,
                );
              }
            }
          },
          colors: FluidTheme.errorFluidGradient,
        ),
      ],
    );
  }

  Future<void> _showBuiltInBooksDialog() async {
    final books = await AssetWordBookService.getAllBuiltInBooks();

    if (!mounted) return;

    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    // 已导入的词库沉到列表末尾：这个弹窗的语义是"还能再导入什么"，
    // 已经躺在词库页里的那些留在最上面只会干扰勾选
    final wordBookProvider = context.read<WordBookProvider>();
    final orderedBooks = <Map<String, dynamic>>[
      ...books.where(
        (b) => !wordBookProvider.isBookNameExists(b['name'] as String),
      ),
      ...books.where(
        (b) => wordBookProvider.isBookNameExists(b['name'] as String),
      ),
    ];

    showFluidDialog(
      context: context,
      // 内容自带定高与内层 ListView，外层再包滚动层纯属冗余
      scrollable: false,
      content: StatefulBuilder(
        builder: (ctx, setModalState) => SizedBox(
          width: double.maxFinite,
          height: MediaQuery.sizeOf(ctx).height * 0.6,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.file_upload,
                    color: FluidTheme.primaryFluidGradient[0],
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isBatchImportMode
                          ? '${ctx.tr.selectedCount} ${_selectedBuiltInBooks.length}${ctx.tr.wordBooksCount}'
                          : ctx.tr.builtInBooks,
                      style: FluidTheme.headingSmall(
                        isDark,
                      ).copyWith(color: textPrimary),
                    ),
                  ),
                  if (_isBatchImportMode) ...[
                    FluidTextButton(
                      text: ctx.tr.cancel,
                      onPressed: () {
                        setModalState(() {
                          _isBatchImportMode = false;
                          _selectedBuiltInBooks.clear();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FluidButton(
                      text: ctx.tr.importSelected,
                      onPressed: () => _executeBatchImport(ctx),
                      colors: FluidTheme.successFluidGradient,
                    ),
                  ] else ...[
                    FluidButton(
                      text: ctx.tr.selectAll,
                      onPressed: () {
                        setModalState(() {
                          _isBatchImportMode = true;
                          final provider = ctx.read<WordBookProvider>();
                          _selectedBuiltInBooks.clear();
                          for (final book in books) {
                            final bookName = book['name']!;
                            if (!provider.isBookNameExists(bookName)) {
                              _selectedBuiltInBooks.add(bookName);
                            }
                          }
                        });
                      },
                      colors: FluidTheme.secondaryFluidGradient,
                    ),
                    const SizedBox(width: 8),
                    FluidTextButton(
                      text: ctx.tr.close,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    _selectedBuiltInBooks.isNotEmpty ? 20 : 16,
                  ),
                  itemCount: orderedBooks.length,
                  itemBuilder: (context, index) {
                    final book = orderedBooks[index];
                    final bookName = book['name'] as String;
                    return _buildBuiltInBookItemForBatchImport(
                      ctx,
                      bookName,
                      book['description']!,
                      book['wordCount'] as int,
                      setModalState,
                      isDark: isDark,
                      alreadyImported: wordBookProvider.isBookNameExists(
                        bookName,
                      ),
                    );
                  },
                ),
              ),
              if (_selectedBuiltInBooks.isNotEmpty)
                //液态玻璃模式下用嵌套玻璃条承托导入按钮，经典模式保留半透明 Container
                if (ctx.isLiquidGlass)
                  GlassSurface(
                    borderRadius: 18,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: _buildBatchImportButton(ctx),
                  )
                else
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.12),
                      border: Border(
                        top: BorderSide(
                          color: FluidTheme.getBorderColor(isDark),
                        ),
                      ),
                    ),
                    child: _buildBatchImportButton(ctx),
                  ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      // 弹窗以任何方式关闭（关闭按钮 / 遮罩 / 返回键）后复位批量导入状态：
      // 此前只在"取消"与"导入成功"两条路径复位，直接关掉弹窗会把批量模式
      // 与上次勾选带到下次打开，点"导入选中"静默重复导入同名副本
      if (!mounted) return;
      _isBatchImportMode = false;
      _selectedBuiltInBooks.clear();
    });
  }

  //底部批量导入按钮，玻璃条与经典 Container 共用
  Widget _buildBatchImportButton(BuildContext ctx) {
    return FluidButton(
      text: '${ctx.tr.importSelected} (${_selectedBuiltInBooks.length})',
      icon: Icons.download,
      expanded: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      onPressed: () => _executeBatchImport(ctx),
      colors: FluidTheme.successFluidGradient,
      fontSize: 14,
    );
  }

  Widget _buildBuiltInBookItemForBatchImport(
    BuildContext ctx,
    String name,
    String desc,
    int count,
    StateSetter setModalState, {
    required bool isDark,
    bool alreadyImported = false,
  }) {
    final isSelected = !alreadyImported && _selectedBuiltInBooks.contains(name);
    //主题值由调用方在打开弹窗之前读好传入：itemBuilder 属布局阶段调用，
    //内部用 context.select 会触发 provider 断言（见上方弹窗回调处的说明）
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    //卡片点击与勾选框共用的选中切换
    void toggle() {
      //已导入的条目不可再选：重复导入会生成同名副本，没有意义
      if (alreadyImported) return;
      setModalState(() {
        if (isSelected) {
          _selectedBuiltInBooks.remove(name);
        } else {
          _selectedBuiltInBooks.add(name);
        }
      });
    }

    final card = FluidCard(
      enableShimmer: isSelected,
      enableBorderGradient: isSelected,
      borderColors: isSelected ? FluidTheme.primaryFluidGradient : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          //按词库类型区分图标与配色，选中态加强光晕
          WordBookBadge(name: name, selected: isSelected),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        context.wordBookName(name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FluidTheme.labelLarge(
                          isDark,
                        ).copyWith(color: textPrimary),
                      ),
                    ),
                    if (alreadyImported) ...[
                      const SizedBox(width: 8),
                      //已导入标记：比单纯置灰多一层文字说明，
                      //否则用户会以为"变灰 = 不可点"是选中过的状态
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FluidTheme.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: FluidTheme.success.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          ctx.tr.alreadyImported,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: FluidTheme.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$count${context.tr.wordsSuffix}',
                  style: FluidTheme.bodyMedium(
                    isDark,
                  ).copyWith(color: textSecondary),
                ),
              ],
            ),
          ),
          //已导入的不再提供勾选框，避免"看着能选、点了没反应"
          if (!alreadyImported)
            LiquidCheckbox(
              value: isSelected,
              onChanged: (_) => toggle(),
              activeColor: FluidTheme.primaryFluidGradient[0],
            ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: toggle,
        //已导入的整行压暗并置于列表末尾，视觉上退到次要层级
        child: alreadyImported ? Opacity(opacity: 0.55, child: card) : card,
      ),
    );
  }

  Future<void> _executeBatchImport(BuildContext ctx) async {
    Navigator.pop(ctx);
    final provider = context.read<WordBookProvider>();
    final selectedBooks = List<String>.from(_selectedBuiltInBooks);

    if (selectedBooks.isEmpty) return;

    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = selectedBooks.length;
      _isBatchImportMode = false;
      _selectedBuiltInBooks.clear();
    });

    var importedCount = 0;
    String? lastError;

    try {
      final books = await AssetWordBookService.getAllBuiltInBooks();
      for (final bookName in selectedBooks) {
        try {
          final bookData = books.firstWhere((b) => b['name'] == bookName);
          final words = await AssetWordBookService.loadBookWords(
            bookData['file'] as String,
          );
          if (words.isEmpty) {
            throw Exception('词库「$bookName」加载失败或为空');
          }
          final imported = await provider.importBuiltInBook(
            bookName,
            bookData['description']!,
            words,
          );
          //同名且已有内容时会被跳过：只有真的写入了才算"已导入"
          if (imported) importedCount += 1;
        } catch (e) {
          lastError = e.toString();
          debugPrint('导入词库失败 $bookName: $e');
        }

        if (!mounted) return;
        setState(() => _importProgress = importedCount);
      }

      if (!mounted) return;
      if (importedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.tr.importSuccessCount} $importedCount${context.tr.wordBooksCount}',
            ),
            backgroundColor: FluidTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lastError != null
                  ? '${context.tr.importFailedRetry}：$lastError'
                  : context.tr.importFailedRetry,
            ),
            backgroundColor: FluidTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.importFailedRetry),
          backgroundColor: FluidTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _importProgress = 0;
          _importTotal = 0;
        });
      }
    }
  }
}

/// 词库卡片 - 流体渐变风格
///
/// 卡片只保留「徽章 + 名称 + 描述」三样信息：
/// - 学习进度统一走右侧「信息」按钮的二级弹窗（卡片上不再铺进度条/统计胶囊）；
/// - 排序在移动端长按卡片进入拖拽，桌面端拖右侧手柄
///   （见 [_buildWordBookList] 里的 `dragHandleIndex`）；
/// - 多选态下右侧操作按钮整组隐藏，名称与描述占用整行宽度。
class _WordBookCard extends StatelessWidget {
  final WordBook book;
  final bool isSelected;
  final bool isChecked;
  final bool isMultiSelectMode;
  final VoidCallback onTap;
  final VoidCallback onBrowse;
  final VoidCallback onDelete;
  final VoidCallback onShowInfo;

  /// 重置该词库的学习进度（保留单词）
  final VoidCallback onResetProgress;

  /// 该词库当前是否为乱序排序（菜单里展示并切换）
  final bool isShuffled;

  /// 切换正序/乱序
  final VoidCallback onToggleSort;

  /// 桌面端：非空时在卡片最右侧显示拖拽手柄，手柄自身即拖拽起点。
  /// 移动端传 null —— 那里用长按整卡进入拖拽（更符合触屏直觉）。
  final int? dragHandleIndex;

  const _WordBookCard({
    required this.book,
    required this.isSelected,
    required this.isChecked,
    required this.isMultiSelectMode,
    required this.onTap,
    required this.onBrowse,
    required this.onDelete,
    required this.onShowInfo,
    required this.onResetProgress,
    required this.isShuffled,
    required this.onToggleSort,
    this.dragHandleIndex,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final iconColor = FluidTheme.getTextSecondaryColor(isDark);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FluidCard(
        onTap: onTap,
        // 「当前词库」不再跑 shimmer：那是一层持续流动的彩色光带，
        // 只有当前词库的卡片有，看起来就像"这张卡和别的卡不是一个材质"
        // （用户反馈"除了最后一本词库，其他词库都发灰"）。
        // 当前词库由渐变描边 + 徽章勾角标表达，其余卡片外观完全一致。
        enableShimmer: false,
        // 始终画出描边：未选中卡此前无边框也无阴影，Android 上相邻卡片
        // 几乎融成一片，看不出边界在哪（反馈"点到别的卡片还以为在同一张"）
        enableBorderGradient: true,
        // 未选中的卡片也用**同一色相**的浅色描边，而不是中性黑：
        // 卡片本体是 82%~96% 半透的白渐变，描边色会整片透过来 ——
        // 黑色描边把整张卡"染灰"，只有当前词库那张（彩色描边）看着有色，
        // 就是"其他词库都有点发灰"的来源。换成品牌色的浅色变体后，
        // 每张卡都保持同样的淡彩底，当前词库仍靠更亮的描边 + 徽章勾角标区分。
        borderColors: isSelected
            ? FluidTheme.primaryFluidGradient
            : [
                Color.lerp(
                  FluidTheme.primaryFluidGradient[0],
                  Colors.white,
                  0.30,
                )!,
                Color.lerp(
                  FluidTheme.primaryFluidGradient[2],
                  Colors.white,
                  0.30,
                )!,
              ],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (isMultiSelectMode) ...[
              Icon(
                isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isChecked
                    ? FluidTheme.primaryFluidGradient[0]
                    : iconColor,
                size: 22,
              ),
              const SizedBox(width: 12),
            ],
            //词库卡片徽章：不同类型不同图标/配色，选中态光晕更亮。
            //「当前词库」用徽章右下角的勾角标表达：不占用标题行宽度，
            //所有卡片（含选中卡）高度完全一致
            Stack(
              clipBehavior: Clip.none,
              children: [
                WordBookBadge(name: book.name, size: 46, selected: isSelected),
                if (isSelected)
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 19,
                      height: 19,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF093FB), Color(0xFF4FACFE)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: FluidTheme.getElevatedSurfaceColor(isDark),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //标题不再放「当前词库」徽章：徽章挤压标题宽度导致换行、
                  //选中卡变高；选中态由图标勾角标+渐变描边表达，所有卡片等高
                  Text(
                    //英文界面下内置词库显示英文名（数据库里仍存中文原名）
                    context.wordBookName(book.name),
                    style: FluidTheme.labelLarge(
                      isDark,
                    ).copyWith(color: textPrimary),
                  ),
                  if (book.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      context.wordBookDescription(book.description),
                      style: FluidTheme.bodySmall(
                        isDark,
                      ).copyWith(color: textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // 多选态：右侧操作按钮整组隐藏，让名称/描述占满整行
            if (!isMultiSelectMode) ...[
              const SizedBox(width: 8),
              //浏览 / 进度 / 删除收进一个「更多」按钮：点击后在按钮原地
              //弹出列表再选功能，不再并排铺三个图标挤占卡片宽度
              _cardMenu(
                context,
                onBrowse: onBrowse,
                onShowInfo: onShowInfo,
                onResetProgress: onResetProgress,
                onDelete: onDelete,
              ),
            ],
            //桌面端排序手柄：鼠标长按整卡既不直观（长按通常等于选中文本），
            //也容易误拖，改由这颗显式的握把启动拖拽（Android 仍走长按整卡）
            if (dragHandleIndex != null && !isMultiSelectMode)
              ReorderableDragStartListener(
                index: dragHandleIndex!,
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
                      color: iconColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 卡片右侧的「更多」按钮：点击后在按钮原地展开操作列表，
  /// 再选浏览词表 / 学习进度 / 排序方式 / 删除。
  /// 菜单用 [showAnchoredMenu]：液态玻璃模式下与全局弹窗同一套玻璃材质
  /// （Material 自带的 PopupMenu 是不透明纯色卡，两种风格下都脱离体系）。
  Widget _cardMenu(
    BuildContext context, {
    required VoidCallback onBrowse,
    required VoidCallback onShowInfo,
    required VoidCallback onResetProgress,
    required VoidCallback onDelete,
  }) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final tr = context.tr;
    //桌面端不缺横向空间，「更多」与拖拽手柄放大到拇指友好的尺寸；
    //移动端仍保持紧凑，避免挤占卡片标题宽度
    final iconSize = PlatformAdapt.isDesktop ? 28.0 : 20.0;
    //Builder 提供按钮自身的 context：菜单锚定在「···」按钮原地展开
    //（直接用卡片 context 的话，锚点是整张卡片的渲染框，位置会偏）
    return Builder(
      builder: (buttonContext) => IconButton(
        icon: Icon(
          Icons.more_horiz,
          color: FluidTheme.getTextSecondaryColor(isDark),
          size: iconSize,
        ),
        tooltip: tr.moreOptions,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(6),
        constraints: BoxConstraints(
          minWidth: iconSize * 1.6,
          minHeight: iconSize * 1.6,
        ),
        onPressed: () async {
          final action = await showAnchoredMenu(
            anchorContext: buttonContext,
            items: [
              AnchoredMenuItem(
                value: 'browse',
                icon: Icons.visibility_outlined,
                label: tr.browseWordList,
              ),
              AnchoredMenuItem(
                value: 'info',
                icon: Icons.info_outline,
                label: tr.learningProgress,
              ),
              AnchoredMenuItem(
                value: 'reset',
                icon: Icons.restart_alt,
                label: tr.t('重置学习进度', 'Reset Progress'),
              ),
              AnchoredMenuItem(
                value: 'sort',
                icon: isShuffled ? Icons.shuffle : Icons.format_list_numbered,
                label: isShuffled
                    ? tr.t('排序方式：乱序', 'Order: Shuffled')
                    : tr.t('排序方式：正序', 'Order: Default'),
              ),
              AnchoredMenuItem(
                value: 'delete',
                icon: Icons.delete_outline,
                label: tr.delete,
                color: FluidTheme.error,
              ),
            ],
          );
          switch (action) {
            case 'browse':
              onBrowse();
            case 'info':
              onShowInfo();
            case 'reset':
              onResetProgress();
            case 'sort':
              onToggleSort();
            case 'delete':
              onDelete();
          }
        },
      ),
    );
  }
}

/// 创建词库对话框的输入表单：自持 controller，在其自身 dispose（对话框动画结束后）释放，
/// 确认按钮同步 pop 返回结果，避免异步创建期间遮罩关闭导致误弹词库页
class _CreateBookForm extends StatefulWidget {
  final bool isDark;
  const _CreateBookForm({required this.isDark});

  @override
  State<_CreateBookForm> createState() => _CreateBookFormState();
}

class _CreateBookFormState extends State<_CreateBookForm> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color),
  );

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    //用本组件的 context 同步 pop，出栈的一定是对话框自身
    Navigator.pop(context, (name: name, desc: _descController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final borderColor = FluidTheme.getBorderColor(isDark);
    final inputTextColor = FluidTheme.getTextPrimaryColor(isDark);
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.10);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          // Android 不自动调起输入法（除拼写/听力模式外都要用户主动点击）
          autofocus: PlatformAdapt.isDesktop,
          onSubmitted: (_) => _submit(),
          style: TextStyle(color: inputTextColor),
          cursorColor: FluidTheme.primaryFluidGradient[0],
          decoration: InputDecoration(
            filled: true,
            fillColor: fill,
            labelText: context.tr.bookNameLabel,
            hintText: context.tr.bookNameExample,
            labelStyle: TextStyle(
              color: inputTextColor.withValues(alpha: 0.72),
            ),
            hintStyle: TextStyle(
              //原 0.45 在玻璃上仅约 2.6:1，输入提示几乎看不见
              color: inputTextColor.withValues(alpha: 0.7),
            ),
            enabledBorder: _border(borderColor),
            focusedBorder: _border(FluidTheme.primaryFluidGradient[0]),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descController,
          style: TextStyle(color: inputTextColor),
          cursorColor: FluidTheme.primaryFluidGradient[0],
          decoration: InputDecoration(
            filled: true,
            fillColor: fill,
            labelText: context.tr.descriptionLabel,
            labelStyle: TextStyle(
              color: inputTextColor.withValues(alpha: 0.72),
            ),
            enabledBorder: _border(borderColor),
            focusedBorder: _border(FluidTheme.primaryFluidGradient[0]),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FluidTextButton(
              text: context.tr.cancel,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            FluidButton(text: context.tr.create, onPressed: _submit),
          ],
        ),
      ],
    );
  }
}

/// 单词列表底部弹窗 - 分页加载
class _WordListSheet extends StatefulWidget {
  final WordBook book;
  final VoidCallback onRefresh;

  const _WordListSheet({required this.book, required this.onRefresh});

  @override
  State<_WordListSheet> createState() => _WordListSheetState();
}

class _WordListSheetState extends State<_WordListSheet> {
  static const int _pageSize = 50;
  final List<Word> _words = [];
  final ScrollController _scrollController = ScrollController();
  int _page = 1;
  int _totalCount = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final repo = context.read<DIContainer>().wordRepository;
    final bookId = widget.book.id!;
    try {
      final results = await Future.wait([
        repo.getWordCountInBook(bookId),
        repo.getWordsPaginated(bookId, page: 1, pageSize: _pageSize),
      ]);
      if (!mounted) return;
      final totalCount = results[0] as int;
      final firstPage = results[1] as List<Word>;
      setState(() {
        _totalCount = totalCount > 0 ? totalCount : widget.book.totalWords;
        _words
          ..clear()
          ..addAll(firstPage);
        _page = 1;
        _hasMore = firstPage.length >= _pageSize && _words.length < _totalCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _words.clear();
        _hasMore = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr.loadingError}：$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    try {
      final pageWords = await context
          .read<DIContainer>()
          .wordRepository
          .getWordsPaginated(
            widget.book.id!,
            page: nextPage,
            pageSize: _pageSize,
          );
      if (!mounted) return;
      setState(() {
        _words.addAll(pageWords);
        _page = nextPage;
        _hasMore = pageWords.length >= _pageSize && _words.length < _totalCount;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr.loadingError}：$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !_hasMore || _isLoadingMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final countLabel = _totalCount > 0 ? _totalCount : _words.length;

    return SizedBox(
      width: double.maxFinite,
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: Column(
        children: [
          Row(
            children: [
              WordBookBadge(name: widget.book.name, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.wordBookName(widget.book.name),
                      style: FluidTheme.headingSmall(
                        isDark,
                      ).copyWith(color: textPrimary),
                    ),
                    Text(
                      '$countLabel${context.tr.wordList}',
                      style: FluidTheme.bodySmall(
                        isDark,
                      ).copyWith(color: textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FluidButton(
              text: context.tr.addFromBuiltIn,
              icon: Icons.library_add,
              expanded: true,
              onPressed: () {
                Navigator.push(
                  context,
                  PageTransitions.slideFromBottom(
                    page: _AddFromBuiltInScreen(
                      targetBookId: widget.book.id!,
                      onAdded: () {
                        widget.onRefresh();
                        _loadInitial();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: FluidLoading())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _words.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _words.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: FluidLoading()),
                        );
                      }
                      final word = _words[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: FluidCard(
                          enableShimmer: false,
                          padding: const EdgeInsets.all(14),
                          onTap: () {
                            Navigator.push(
                              context,
                              PageTransitions.slideFromRight(
                                page: WordDetailScreen(word: word),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                word.word,
                                style: FluidTheme.labelLarge(
                                  isDark,
                                ).copyWith(color: textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                word.definition,
                                style: FluidTheme.bodySmall(
                                  isDark,
                                ).copyWith(color: textSecondary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 从内置词库添加单词页面
class _AddFromBuiltInScreen extends StatefulWidget {
  final int targetBookId;
  final VoidCallback onAdded;

  const _AddFromBuiltInScreen({
    required this.targetBookId,
    required this.onAdded,
  });

  @override
  State<_AddFromBuiltInScreen> createState() => _AddFromBuiltInScreenState();
}

class _AddFromBuiltInScreenState extends State<_AddFromBuiltInScreen> {
  List<Map<String, dynamic>> _builtInBooks = [];
  List<Map<String, dynamic>> _words = [];
  int? _selectedBookIndex;
  String _searchQuery = '';
  //搜索过滤结果缓存：该 getter 会在 itemCount 与每个 itemBuilder 中重复求值，
  //词库数千条时每次重建都全量过滤会明显掉帧
  List<Map<String, dynamic>>? _filteredCache;
  String _filteredCacheQuery = '';
  List<Map<String, dynamic>>? _filteredCacheSource;
  final Set<String> _selectedWords = {};
  bool _isLoading = true;
  bool _isAdding = false;

  /// 搜索输入防抖定时器：每次按键都全表 toLowerCase 过滤（数千词库时
  /// 产生上万临时字符串），250ms 内的连续输入只在停顿后过滤一次
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadBuiltInBooks();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || _searchQuery == value) return;
      setState(() => _searchQuery = value);
    });
  }

  Future<void> _loadBuiltInBooks() async {
    final books = await AssetWordBookService.getAllBuiltInBooks();
    if (mounted) {
      setState(() {
        _builtInBooks = books;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWords(int index) async {
    //先校验索引：非法 index 若在 setState 之后才 return，会留下 _isLoading=true
    //让界面永久停在加载态
    if (index < 0 || index >= _builtInBooks.length) return;
    setState(() {
      _isLoading = true;
      _selectedBookIndex = index;
      _words = [];
      _selectedWords.clear();
    });
    final book = _builtInBooks[index];
    final fileName = book['file'] as String? ?? '';
    final wordList = fileName.isEmpty
        ? <Map<String, String>>[]
        : await AssetWordBookService.loadBookWords(fileName);
    if (!mounted || _selectedBookIndex != index) return;
    setState(() {
      _words = wordList.cast<Map<String, dynamic>>();
      _isLoading = false;
    });
  }

  Future<void> _addSelectedWords() async {
    if (_selectedWords.isEmpty) return;

    setState(() => _isAdding = true);

    final di = context.read<DIContainer>();
    final wordRepository = di.wordRepository;
    final wordBookRepository = di.wordBookRepository;

    // 1) 目标词库里已有的词（小写归一化后比较）：重复添加会在词库里留下
    //    重复词条，学习/统计都会把它们当成两个词
    final existing = <String>{};
    try {
      final current = await wordRepository.getWordsByBook(widget.targetBookId);
      existing.addAll(current.map((w) => w.word.toLowerCase().trim()));
    } catch (e) {
      debugPrint('读取词库已有单词失败（将按不去重处理）: $e');
    }

    // 2) 去重 + 组装（同一批内按小写归一化去重）
    final picked = <String, Word>{};
    for (final wordData in _words) {
      final wordText = (wordData['word'] as String? ?? '').trim();
      if (wordText.isEmpty || !_selectedWords.contains(wordText)) continue;
      final key = wordText.toLowerCase();
      if (existing.contains(key) || picked.containsKey(key)) continue;
      picked[key] = Word(
        word: wordText,
        phonetic: wordData['phonetic'] as String? ?? '',
        definition: wordData['definition'] as String? ?? '',
        example: wordData['example'] as String?,
        exampleTranslation: wordData['exampleTranslation'] as String?,
        wordBookId: widget.targetBookId,
      );
    }

    var added = 0;
    if (picked.isNotEmpty) {
      try {
        // 3) 批量插入（此前逐条 insert，勾选上百词就是上百次独立写事务）
        await wordRepository.insertWordsBatchFast(picked.values.toList());
        added = picked.length;
        // 4) 词库总词数必须同步：否则卡片词数/进度百分比/分页判定全部偏小
        await wordBookRepository.updateWordBookTotalWords(widget.targetBookId);
      } catch (e) {
        debugPrint('批量添加单词失败: $e');
        added = 0;
      }
    }

    if (mounted) {
      setState(() => _isAdding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr.added} ${context.tr.wordsCount(added)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onAdded();
      Navigator.pop(context);
    }
  }

  List<Map<String, dynamic>> get _filteredWords {
    if (_searchQuery.isEmpty) return _words;
    //同一个 query 与同一份词表只过滤一次
    if (_filteredCache != null &&
        _filteredCacheQuery == _searchQuery &&
        identical(_filteredCacheSource, _words)) {
      return _filteredCache!;
    }
    final query = _searchQuery.toLowerCase();
    final filtered = _words.where((w) {
      final word = (w['word'] as String? ?? '').toLowerCase();
      final def = (w['definition'] as String? ?? '').toLowerCase();
      return word.contains(query) || def.contains(query);
    }).toList();
    _filteredCache = filtered;
    _filteredCacheQuery = _searchQuery;
    _filteredCacheSource = _words;
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Scaffold(
      backgroundColor: context.isLiquidGlass
          ? Colors.transparent
          : FluidTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        title: Text(
          context.tr.addFromBuiltIn,
          style: FluidTheme.headingSmall(isDark).copyWith(color: textPrimary),
        ),
        actions: [
          if (_selectedWords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_selectedWords.length} ${context.tr.selected}',
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: FluidTheme.primaryAccessible(isDark)),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 内置词库选择
          if (_builtInBooks.isNotEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _builtInBooks.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final book = _builtInBooks[index];
                  final isSelected = _selectedBookIndex == index;
                  return LiquidChoiceChip(
                    label: book['name'] as String? ?? '',
                    selected: isSelected,
                    onTap: () => _loadWords(index),
                  );
                },
              ),
            ),

          //搜索框：选中内置书后水波展开
          LiquidExpand(
            expanded: _selectedBookIndex != null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: _onSearchChanged,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: context.tr.searchWordHint,
                  hintStyle: TextStyle(color: textSecondary),
                  prefixIcon: Icon(Icons.search, color: textSecondary),
                  filled: true,
                  //液态玻璃模式下搜索框半透明填充
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          // 单词列表
          Expanded(
            child: _isLoading
                ? Center(child: FluidLoading(message: context.tr.loading))
                : _selectedBookIndex == null
                ? Center(
                    child: Text(
                      context.tr.selectBuiltInBookHint,
                      style: FluidTheme.bodyLarge(
                        isDark,
                      ).copyWith(color: textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredWords.length,
                    itemBuilder: (context, index) {
                      final wordData = _filteredWords[index];
                      final wordText = wordData['word'] as String? ?? '';
                      final isSelected = _selectedWords.contains(wordText);

                      //卡片点击与勾选框共用的单词选中切换
                      void toggleWord() {
                        setState(() {
                          if (isSelected) {
                            _selectedWords.remove(wordText);
                          } else {
                            _selectedWords.add(wordText);
                          }
                        });
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: FluidCard(
                          enableShimmer: false,
                          padding: const EdgeInsets.all(12),
                          onTap: toggleWord,
                          child: Row(
                            children: [
                              LiquidCheckbox(
                                value: isSelected,
                                onChanged: (_) => toggleWord(),
                                activeColor: FluidTheme.primaryFluidGradient[0],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      wordText,
                                      style: FluidTheme.labelLarge(isDark)
                                          .copyWith(
                                            color: textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      wordData['definition'] as String? ?? '',
                                      style: FluidTheme.bodySmall(
                                        isDark,
                                      ).copyWith(color: textSecondary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 底部添加按钮
          if (_selectedWords.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FluidButton(
                  text: '${context.tr.addSelected} (${_selectedWords.length})',
                  icon: Icons.add,
                  expanded: true,
                  onPressed: _isAdding ? null : _addSelectedWords,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
