import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/app_initialization_service.dart';
import '../services/di_container.dart';
import '../services/guide_service.dart';
import '../services/providers/providers.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/guide_keys.dart';
import '../utils/page_transitions.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../utils/wordbook_localization.dart';
import '../widgets/coach_mark_overlay.dart';
import '../widgets/dictionary_dialog.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/liquid_controls.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/word_collection_settings_panel.dart';
import 'pre_study_screen.dart';

/// 收藏夹
///
/// 与错题集（WrongWordsScreen）并列的一个"词集"。收藏是**单词级、跨词库、
/// 全局唯一**的：学习模式顶栏星标、阅读器词条菜单都写入同一张表，
/// 所以这里看到的是全部来源的收藏。
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selected = {};

  List<WordFavorite> _favorites = [];

  /// 有收藏的词库汇总，作为「按词库筛选」胶囊的数据源
  List<FavoriteBookSummary> _bookSummaries = [];
  bool _isLoading = true;
  bool _isSelecting = false;
  String _keyword = '';
  bool _hasAnyFavorite = false;
  Timer? _searchDebounce;

  /// 本页实例是否已调度过引导（列表数据到齐后只提示一次）
  bool _guideScheduled = false;

  /// 来源筛选；null 表示全部来源
  FavoriteSource? _sourceFilter;

  /// 词库筛选；null 表示全部词库
  int? _bookFilter;

  /// 收藏时间范围筛选
  FavoriteTimeRange _timeRange = FavoriteTimeRange.all;

  /// 排序方向：true = 最早在前，false = 最新在前（默认）
  bool _sortAscending = false;

  bool get _hasFilter =>
      _sourceFilter != null ||
      _bookFilter != null ||
      _timeRange != FavoriteTimeRange.all;

  /// 词集设置（收藏夹筛选状态的持久化位置）
  WordCollectionSettingsProvider get _settings =>
      context.read<WordCollectionSettingsProvider>();

  @override
  void initState() {
    super.initState();
    //恢复上次的筛选与排序：收藏是长期积累的列表，每次进来都从"全部"开始翻很烦
    final settings = context.read<WordCollectionSettingsProvider>();
    _sourceFilter = settings.favoriteSourceFilter;
    _bookFilter = settings.favoriteBookFilter;
    _timeRange = settings.favoriteTimeRange;
    _sortAscending = settings.favoriteSortAscending;
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// 数据加载世代号：_load 被 4 个筛选/排序入口 + 搜索防抖并发触发，
  /// 先发出的慢查询可能后返回并覆盖新结果（"筛了 A 却显示 B"）。
  /// 只允许最新一代的结果上屏。
  int _loadGeneration = 0;

  /// [silent] 为 true 时保留当前列表不清屏（切换筛选胶囊用，避免整页闪一下）
  Future<void> _load({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isLoading = true);
    final generation = ++_loadGeneration;
    try {
      final service = DIContainer.instance.favoriteService;
      // 「词库分组」与「收藏总数」互不依赖：先同时发出，避免把两次
      // 全表扫描排成一队（每次进页面、每次筛选/搜索防抖后都会跑一遍）。
      // favorites 仍要等 bookSummaries 回来才能判断"选中的词库是否已删"。
      final booksFuture = service.getBookSummaries();
      final totalFuture = service.getCount();
      final books = await booksFuture;
      //选中的词库已经没有收藏了（刚把该词库最后一个词取消收藏）→ 自动回到"全部词库"，
      //否则会卡在一个必然为空的筛选里
      var bookId = _bookFilter;
      if (bookId != null && !books.any((b) => b.wordBookId == bookId)) {
        bookId = null;
      }
      final favorites = await service.getAll(
        keyword: _keyword,
        source: _sourceFilter,
        wordBookId: bookId,
        timeRange: _timeRange,
        ascending: _sortAscending,
      );
      //"收藏夹本身是不是空的"必须用不带筛选的总数，否则筛选无结果会被误报成空收藏夹
      final total = await totalFuture;
      if (!mounted) return;
      //有更新的加载已发起：本次结果已过期，直接丢弃，避免旧结果覆盖新筛选
      if (generation != _loadGeneration) return;
      //自动复位也同步落盘，否则每次进页面都要重算一次（词库可能已被删除）
      if (bookId != _bookFilter) {
        unawaited(_settings.setFavoriteBookFilter(bookId));
      }
      setState(() {
        _bookSummaries = books;
        _bookFilter = bookId;
        _favorites = favorites;
        _hasAnyFavorite = total > 0;
        _selected.removeWhere((id) => !favorites.any((f) => f.word.id == id));
        _isLoading = false;
      });
      //数据到齐、目标控件挂上之后再调度一次性引导
      if (!_guideScheduled) {
        _guideScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showGuide();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: context.tr.operationFailed,
      );
    }
  }

  /// 首次进入收藏夹：介绍搜索、筛选调整与专项复习。
  ///
  /// 收藏夹为空时这些控件都不存在，步骤为空会被 [CoachMarkOverlay] 跳过，
  /// 留到用户真正收藏了词之后再提示。
  Future<void> _showGuide() async {
    if (!mounted || _favorites.isEmpty) return;
    await CoachMarkOverlay.maybeShow(
      context,
      guideId: GuideService.tipFavorites,
      steps: () => [
        CoachMarkStep(
          targetKey: guideFavoritesStudyKey,
          title: context.tr.coachFavoritesStudyTitle,
          message: context.tr.coachFavoritesStudyMsg,
          icon: Icons.school_outlined,
        ),
        CoachMarkStep(
          targetKey: guideFavoritesSearchKey,
          title: context.tr.coachFavoritesSearchTitle,
          message: context.tr.coachFavoritesSearchMsg,
          icon: Icons.search,
        ),
      ],
    );
  }

  /// 切换来源筛选。清空已选集合：选择态是"对当前可见列表的操作"，换了筛选就不再成立
  void _setSourceFilter(FavoriteSource? source) {
    setState(() {
      _sourceFilter = source;
      _selected.clear();
    });
    unawaited(_settings.setFavoriteSourceFilter(source));
    _load(silent: true);
  }

  void _setBookFilter(int? wordBookId) {
    setState(() {
      _bookFilter = wordBookId;
      _selected.clear();
    });
    unawaited(_settings.setFavoriteBookFilter(wordBookId));
    _load(silent: true);
  }

  void _setTimeRange(FavoriteTimeRange range) {
    setState(() {
      _timeRange = range;
      _selected.clear();
    });
    unawaited(_settings.setFavoriteTimeRange(range));
    _load(silent: true);
  }

  /// 收藏时间排序方向：最新在前 ⇄ 最早在前
  void _setSortOrder(bool ascending) {
    if (ascending == _sortAscending) return;
    setState(() => _sortAscending = ascending);
    unawaited(_settings.setFavoriteSortAscending(ascending));
    _load(silent: true);
  }

  void _clearFilters() {
    setState(() {
      _sourceFilter = null;
      _bookFilter = null;
      _timeRange = FavoriteTimeRange.all;
      _selected.clear();
    });
    //排序方向保留：它不属于"筛选"，没有隐藏任何条目
    unawaited(_settings.clearFavoriteFilters());
    _load(silent: true);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      _keyword = value.trim();
      //silent：搜索时不能把 body 换成转圈，否则搜索框会被一起销毁并丢失焦点
      _load(silent: true);
    });
  }

  void _toggleSelected(int wordId) {
    setState(() {
      _selected.contains(wordId)
          ? _selected.remove(wordId)
          : _selected.add(wordId);
    });
  }

  void _selectAll() {
    setState(() {
      _selected.addAll(_favorites.map((f) => f.word.id).whereType<int>());
    });
  }

  void _exitSelecting() {
    setState(() {
      _isSelecting = false;
      _selected.clear();
    });
  }

  /// 顶栏「更多」：居中弹窗。
  ///
  /// 筛选 / 排序 / 设置弹窗都**叠在本菜单上层**打开（不先出栈本菜单）：
  /// 取消时回到菜单、选中后自动收起菜单，返回键逐级回退而不是直接退回最外层。
  /// 「选择」已移到顶栏独立按钮，不再收进菜单。
  Future<void> _showMoreSheet() async {
    await showFluidDialog<void>(
      context: context,
      title: context.tr.moreOptions,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dialogAction(
            icon: Icons.filter_alt_outlined,
            label: context.tr.filterBySource,
            value: _sourceLabel,
            highlight: _sourceFilter != null,
            onTap: () async {
              if (await _pickSourceFilter() && mounted) Navigator.pop(context);
            },
          ),
          if (_bookSummaries.length > 1 || _bookFilter != null)
            _dialogAction(
              icon: Icons.library_books_outlined,
              label: context.tr.filterByWordBook,
              value: _bookFilterLabel,
              highlight: _bookFilter != null,
              onTap: () async {
                if (await _pickBookFilter() && mounted) Navigator.pop(context);
              },
            ),
          _dialogAction(
            icon: Icons.schedule,
            label: context.tr.filterByTime,
            value: _timeRangeLabel,
            highlight: _timeRange != FavoriteTimeRange.all,
            onTap: () async {
              if (await _pickTimeRange() && mounted) Navigator.pop(context);
            },
          ),
          _dialogAction(
            icon: Icons.sort,
            label: context.tr.sortBy,
            value: _sortAscending
                ? context.tr.sortOldestFirst
                : context.tr.sortNewestFirst,
            onTap: () async {
              if (await _pickSortOrder() && mounted) Navigator.pop(context);
            },
          ),
          if (_hasFilter)
            _dialogAction(
              icon: Icons.filter_alt_off_outlined,
              label: context.tr.clearFilters,
              onTap: () {
                _clearFilters();
                if (mounted) Navigator.pop(context);
              },
            ),
          _dialogAction(
            icon: Icons.tune,
            label: context.tr.collectionSettings,
            onTap: () => showFavoritesSettings(context),
          ),
        ],
      ),
    );
  }

  /// 弹窗里的一行：图标 + 名称 + 当前值 + 箭头
  Widget _dialogAction({
    required IconData icon,
    required String label,
    String? value,
    bool highlight = false,
    required VoidCallback onTap,
  }) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: highlight
                  ? FluidTheme.primaryAccessible(isDark)
                  : FluidTheme.getTextSecondaryColor(isDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: FluidTheme.getTextPrimaryColor(isDark),
                ),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: highlight
                        ? FluidTheme.primaryAccessible(isDark)
                        : FluidTheme.getTextSecondaryColor(isDark),
                  ),
                ),
              ),
            ],
            Icon(
              Icons.chevron_right,
              size: 18,
              color: FluidTheme.getTextTertiaryColor(isDark),
            ),
          ],
        ),
      ),
    );
  }

  /// 单选弹窗里的一行
  Widget _optionTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? FluidTheme.primaryAccessible(isDark)
                      : FluidTheme.getTextPrimaryColor(isDark),
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check,
                size: 18,
                color: FluidTheme.primaryFluidGradient[0],
              ),
          ],
        ),
      ),
    );
  }

  String get _sourceLabel => switch (_sourceFilter) {
    FavoriteSource.study => context.tr.favoriteFromStudy,
    FavoriteSource.reader => context.tr.favoriteFromReader,
    FavoriteSource.homeSearch => context.tr.favoriteFromHomeSearch,
    null => context.tr.allSources,
  };

  String get _bookFilterLabel {
    final id = _bookFilter;
    if (id == null) return context.tr.allWordBooks;
    for (final book in _bookSummaries) {
      if (book.wordBookId == id) {
        return book.name.isEmpty ? '#$id' : context.wordBookName(book.name);
      }
    }
    return '#$id';
  }

  String get _timeRangeLabel => switch (_timeRange) {
    FavoriteTimeRange.today => context.tr.timeRangeToday,
    FavoriteTimeRange.last7Days => context.tr.timeRange7Days,
    FavoriteTimeRange.last30Days => context.tr.timeRange30Days,
    FavoriteTimeRange.all => context.tr.timeRangeAll,
  };

  /// 返回 true 表示用户做了选择（外层菜单应随之收起）
  Future<bool> _pickSourceFilter() async {
    final picked = await showFluidDialog<int>(
      context: context,
      title: context.tr.filterBySource,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _optionTile(
            label: context.tr.allSources,
            selected: _sourceFilter == null,
            onTap: () => Navigator.pop(context, 0),
          ),
          _optionTile(
            label: context.tr.favoriteFromStudy,
            selected: _sourceFilter == FavoriteSource.study,
            onTap: () => Navigator.pop(context, 1),
          ),
          _optionTile(
            label: context.tr.favoriteFromReader,
            selected: _sourceFilter == FavoriteSource.reader,
            onTap: () => Navigator.pop(context, 2),
          ),
          _optionTile(
            label: context.tr.favoriteFromHomeSearch,
            selected: _sourceFilter == FavoriteSource.homeSearch,
            onTap: () => Navigator.pop(context, 3),
          ),
        ],
      ),
    );
    if (!mounted || picked == null) return false;
    _setSourceFilter(switch (picked) {
      1 => FavoriteSource.study,
      2 => FavoriteSource.reader,
      3 => FavoriteSource.homeSearch,
      _ => null,
    });
    return true;
  }

  Future<bool> _pickBookFilter() async {
    final picked = await showFluidDialog<int>(
      context: context,
      title: context.tr.filterByWordBook,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _optionTile(
            label: context.tr.allWordBooks,
            selected: _bookFilter == null,
            onTap: () => Navigator.pop(context, 0),
          ),
          for (var i = 0; i < _bookSummaries.length; i++)
            _optionTile(
              label:
                  '${_bookSummaries[i].name.isEmpty ? '#${_bookSummaries[i].wordBookId}' : context.wordBookName(_bookSummaries[i].name)}'
                  ' (${_bookSummaries[i].count})',
              selected: _bookFilter == _bookSummaries[i].wordBookId,
              onTap: () => Navigator.pop(context, i + 1),
            ),
        ],
      ),
    );
    if (!mounted || picked == null) return false;
    _setBookFilter(picked == 0 ? null : _bookSummaries[picked - 1].wordBookId);
    return true;
  }

  /// 排序方式：单选弹窗（此前是点一下直接翻转方向，用户看不出发生了什么）
  Future<bool> _pickSortOrder() async {
    final picked = await showFluidDialog<int>(
      context: context,
      title: context.tr.sortBy,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _optionTile(
            label: context.tr.sortNewestFirst,
            selected: !_sortAscending,
            onTap: () => Navigator.pop(context, 0),
          ),
          _optionTile(
            label: context.tr.sortOldestFirst,
            selected: _sortAscending,
            onTap: () => Navigator.pop(context, 1),
          ),
        ],
      ),
    );
    if (!mounted || picked == null) return false;
    _setSortOrder(picked == 1);
    return true;
  }

  Future<bool> _pickTimeRange() async {
    final picked = await showFluidDialog<int>(
      context: context,
      title: context.tr.filterByTime,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _optionTile(
            label: context.tr.timeRangeAll,
            selected: _timeRange == FavoriteTimeRange.all,
            onTap: () => Navigator.pop(context, 0),
          ),
          _optionTile(
            label: context.tr.timeRangeToday,
            selected: _timeRange == FavoriteTimeRange.today,
            onTap: () => Navigator.pop(context, 1),
          ),
          _optionTile(
            label: context.tr.timeRange7Days,
            selected: _timeRange == FavoriteTimeRange.last7Days,
            onTap: () => Navigator.pop(context, 2),
          ),
          _optionTile(
            label: context.tr.timeRange30Days,
            selected: _timeRange == FavoriteTimeRange.last30Days,
            onTap: () => Navigator.pop(context, 3),
          ),
        ],
      ),
    );
    if (!mounted || picked == null) return false;
    _setTimeRange(switch (picked) {
      1 => FavoriteTimeRange.today,
      2 => FavoriteTimeRange.last7Days,
      3 => FavoriteTimeRange.last30Days,
      _ => FavoriteTimeRange.all,
    });
    return true;
  }

  /// 取消收藏（单个）。批量删除在 [_removeSelected]。
  Future<void> _removeOne(int wordId) async {
    try {
      await DIContainer.instance.favoriteService.removeWord(wordId);
      AppInitializationService.notifyDatabaseRefreshed();
      if (!mounted) return;
      setState(() {
        _favorites.removeWhere((f) => f.word.id == wordId);
        _selected.remove(wordId);
      });
      ErrorHandler.showSuccess(context, context.tr.favoriteRemoved);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: context.tr.operationFailed,
      );
    }
  }

  Future<void> _removeSelected() async {
    if (_selected.isEmpty) return;
    final confirmed = await showFluidDialog<bool>(
      context: context,
      title: context.tr.deleteConfirm,
      content: Text(context.tr.favoriteBatchRemoveConfirm(_selected.length)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            context.tr.confirm,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    final ids = _selected.toList();
    try {
      await DIContainer.instance.favoriteService.removeWords(ids);
      AppInitializationService.notifyDatabaseRefreshed();
      if (!mounted) return;
      setState(() {
        _favorites.removeWhere((f) => ids.contains(f.word.id));
        _selected.clear();
        _isSelecting = false;
      });
      ErrorHandler.showSuccess(context, context.tr.favoriteRemoved);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: context.tr.operationFailed,
      );
    }
  }

  Future<int?> _pickReviewMode() {
    return showFluidDialog<int>(
      context: context,
      title: context.tr.chooseWrongWordsReviewMode,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeTile(context, Icons.visibility, context.tr.recallMode, 1),
          _buildModeTile(context, Icons.edit, context.tr.spellingMode, 2),
          _buildModeTile(
            context,
            Icons.headphones,
            context.tr.listeningMode,
            3,
          ),
          _buildModeTile(context, Icons.quiz, context.tr.quizModeEnToCn, 4),
        ],
      ),
    );
  }

  Widget _buildModeTile(
    BuildContext sheetContext,
    IconData icon,
    String title,
    int mode,
  ) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return ListTile(
      leading: Icon(icon, color: FluidTheme.primaryFluidGradient[0]),
      title: Text(
        title,
        style: TextStyle(color: FluidTheme.getTextPrimaryColor(isDark)),
      ),
      onTap: () => Navigator.pop(sheetContext, mode),
    );
  }

  /// 收藏词专项复习：选中了就是选中部分，否则复习当前筛选出的全部
  Future<void> _studyFavorites() async {
    final hasSelection = _isSelecting && _selected.isNotEmpty;
    //筛选状态也算"部分"：否则"按词库筛出 20 个词复习"会和"全部收藏词复习"
    //共用同一份进度，中断后互相覆盖
    final isSubset = hasSelection || _hasFilter;
    //选中了就只复习选中的；否则复习当前可见的（全部，或筛选后的结果）
    final ids = hasSelection
        ? _selected.toList()
        : _favorites.map((f) => f.word.id).whereType<int>().toList();
    if (ids.isEmpty) {
      ErrorHandler.showError(context, context.tr.favoritesEmptyHint);
      return;
    }

    final mode = await _pickReviewMode();
    if (mode == null || !mounted) return;

    final di = DIContainer.instance;
    final request = await di.specializedStudyService.buildFavoritesRequest(
      wordIds: ids,
      studyMode: mode,
      isSubset: isSubset,
      title: context.tr.favoriteReviewTitle,
    );
    if (!mounted) return;
    if (request == null) {
      ErrorHandler.showError(context, context.tr.favoritesEmptyHint);
      return;
    }

    final words = await di.wordRepository.getWordsByIds(request.wordIds);
    if (!mounted) return;
    if (words.isEmpty) {
      ErrorHandler.showError(context, context.tr.favoritesEmptyHint);
      return;
    }

    Navigator.of(context)
        .push(
          PageTransitions.slideFromRight(
            page: PreStudyScreen.specialized(request: request, words: words),
          ),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    return FluidPage(
      child: Scaffold(
        // 背景交给 FluidPage 的流体渐变/液态玻璃底：
        // 此前这里自绘纯色底（玻璃模式为透明），收藏夹与错词集观感不一致
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textPrimary),
          title: Text(
            context.tr.favorites,
            style: FluidTheme.headingMedium(
              isDark,
            ).copyWith(color: textPrimary),
          ),
          // 顶栏与错词集保持同一套结构：选择态只留「全选 / 退出」，
          // 其余情况是「专项复习 + 更多」，筛选/排序/设置/多选全部收进「更多」。
          // 早先把来源/词库/时间三行筛选胶囊和排序、设置、多选按钮全铺在页面上，
          // 一进收藏夹就是大片控件（用户反馈"太杂乱"）。
          actions: [
            if (_isSelecting) ...[
              IconButton(
                icon: Icon(Icons.select_all, color: textPrimary),
                onPressed: _selectAll,
                tooltip: context.tr.selectAll,
              ),
              IconButton(
                icon: Icon(Icons.close, color: textPrimary),
                onPressed: _exitSelecting,
                tooltip: context.tr.cancelSelect,
              ),
            ] else if (!_hasAnyFavorite) ...[
              IconButton(
                icon: Icon(Icons.refresh, color: textPrimary),
                onPressed: _load,
                tooltip: context.tr.refresh,
              ),
            ] else ...[
              IconButton(
                key: guideFavoritesStudyKey,
                icon: Icon(Icons.school, color: textPrimary),
                onPressed: _studyFavorites,
                tooltip: context.tr.specialReview,
              ),
              //「选择」是高频批量入口，独立成按钮而不是藏在「更多」里
              IconButton(
                icon: Icon(Icons.checklist, color: textPrimary),
                onPressed: () {
                  setState(() {
                    _isSelecting = true;
                    _selected.clear();
                  });
                },
                tooltip: context.tr.select,
              ),
              IconButton(
                icon: Icon(Icons.more_vert, color: textPrimary),
                onPressed: _showMoreSheet,
                tooltip: context.tr.moreOptions,
              ),
            ],
          ],
        ),
        // 底部手势条/三键导航会压住最后一行，列表底部内边距只有 24dp；
        // 顶部由 AppBar 处理，这里只需避让底部
        body: SafeArea(
          top: false,
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: FluidTheme.primaryFluidGradient[0],
                  ),
                )
              : _buildBody(isDark),
        ),
        floatingActionButton: _isSelecting && _selected.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _removeSelected,
                icon: Icon(
                  Icons.star_border,
                  color: FluidTheme.onGradientForeground,
                ),
                label: Text(
                  '${_selected.length}',
                  style: TextStyle(color: FluidTheme.onGradientForeground),
                ),
                backgroundColor: FluidTheme.primaryFluidGradient[0],
              )
            : null,
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    //真正空收藏夹：直接给引导页，不显示搜索/筛选栏
    if (_favorites.isEmpty && !_hasFilter) {
      return _buildEmptyState(isDark);
    }
    //跨词库浏览时才在条目上标出所属词库，单本词库没必要重复同一行字
    final bookNames = {
      for (final book in _bookSummaries)
        book.wordBookId: context.wordBookName(book.name),
    };
    final showBookTag = _bookSummaries.length > 1;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _favorites.isEmpty ? 2 : _favorites.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeader(isDark);
        //筛选无结果：筛选栏必须保留（否则用户没有任何出口取消筛选）
        if (_favorites.isEmpty) {
          //不要用固定屏高比例：横屏（高约 360dp）时 52% 装不下空态内容会溢出
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: _buildEmptyState(isDark),
          );
        }
        final favorite = _favorites[index - 1];
        final wordId = favorite.word.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _FavoriteItem(
            favorite: favorite,
            bookName: showBookTag ? bookNames[favorite.word.wordBookId] : null,
            isSelecting: _isSelecting,
            isSelected: wordId != null && _selected.contains(wordId),
            onToggleSelected: wordId == null
                ? null
                : () => _toggleSelected(wordId),
            onOpenDictionary: () => showDictionaryLookupDialog(
              context: context,
              word: favorite.word.word,
            ),
            onRemove: wordId == null ? null : () => _removeOne(wordId),
          ),
        );
      },
    );
  }

  /// 列表头部：只保留搜索框 + 已生效筛选的提示条
  ///
  /// 三组筛选胶囊（来源 / 词库 / 时间）已收进顶栏「更多」弹窗，
  /// 页面本身不再常驻一排控件；筛选生效时用一条可点的小提示告知，
  /// 点一下就清空，避免"看不到筛选状态，也不知道怎么退出"。
  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //上下文引导高亮目标
        KeyedSubtree(
          key: guideFavoritesSearchKey,
          child: _buildSearchField(isDark),
        ),
        if (_hasFilter) _buildFilterSummary(isDark),
      ],
    );
  }

  /// 已生效筛选的汇总条：来源 / 词库 / 时间 + 一键清除
  Widget _buildFilterSummary(bool isDark) {
    final labels = <String>[
      if (_sourceFilter != null) _sourceLabel,
      if (_bookFilter != null) _bookFilterLabel,
      if (_timeRange != FavoriteTimeRange.all) _timeRangeLabel,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _clearFilters,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: FluidTheme.getMutedOverlayColor(isDark),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: FluidTheme.getBorderColor(isDark)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt,
                size: 14,
                color: FluidTheme.primaryAccessible(isDark),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  labels.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FluidTheme.bodySmall(isDark).copyWith(
                    color: FluidTheme.getTextSecondaryColor(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.close,
                size: 14,
                color: FluidTheme.getTextTertiaryColor(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    final isGlass = context.isLiquidGlass;
    final field = TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: FluidTheme.getTextPrimaryColor(isDark)),
      decoration: InputDecoration(
        hintText: context.tr.favoriteSearchHint,
        prefixIcon: Icon(
          Icons.search,
          color: FluidTheme.getTextTertiaryColor(isDark),
        ),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(
                  Icons.clear,
                  color: FluidTheme.getTextTertiaryColor(isDark),
                ),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
        filled: true,
        //玻璃模式下填充改由外层 GlassSurface 承担，否则不透明填充会把
        //玻璃底盖成一块实色，与其他玻璃控件不是同一材质
        fillColor: isGlass
            ? Colors.transparent
            : FluidTheme.getInputFillColor(isDark),
        border: isGlass
            ? InputBorder.none
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
        isDense: true,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: isGlass
          ? GlassSurface(
              borderRadius: 14,
              //Android 真机验证：移动端保留无折射降级，桌面实时模糊
              forceFlat: PlatformAdapt.isMobile,
              child: field,
            )
          : field,
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    //有收藏但当前搜索/筛选无结果 → 说的是"没匹配"，不是"收藏夹是空的"
    final isMiss = _hasAnyFavorite && (_keyword.isNotEmpty || _hasFilter);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMiss ? Icons.search_off : Icons.star_border,
              size: 64,
              color: isMiss
                  ? FluidTheme.getTextTertiaryColor(isDark)
                  : FluidTheme.favorite.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              isMiss ? context.tr.noMatchFound : context.tr.favoritesEmpty,
              style: FluidTheme.headingSmall(
                isDark,
              ).copyWith(color: textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              isMiss
                  ? context.tr.tryOtherKeywords
                  : context.tr.favoritesEmptyHint,
              textAlign: TextAlign.center,
              style: FluidTheme.bodyMedium(
                isDark,
              ).copyWith(color: textSecondary),
            ),
            //筛选无结果时给一个明确出口：能一键回到"全部"比只提示"换关键词"更有用
            if (isMiss && _hasFilter) ...[
              const SizedBox(height: 20),
              FluidButton(
                text: context.tr.clearFilters,
                icon: Icons.filter_alt_off_outlined,
                onPressed: _clearFilters,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 收藏条目：单词 + 音标 + 释义 + 来源/词库/时间标签
class _FavoriteItem extends StatelessWidget {
  final WordFavorite favorite;

  /// 所属词库名；跨词库浏览时才知道这个词来自哪本书，单本时为 null
  final String? bookName;

  final bool isSelecting;
  final bool isSelected;
  final VoidCallback? onToggleSelected;
  final VoidCallback onOpenDictionary;
  final VoidCallback? onRemove;

  const _FavoriteItem({
    required this.favorite,
    required this.isSelecting,
    required this.isSelected,
    required this.onToggleSelected,
    required this.onOpenDictionary,
    required this.onRemove,
    this.bookName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final word = favorite.word;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final textTertiary = FluidTheme.getTextTertiaryColor(isDark);

    return FluidCard(
      enableShimmer: isSelected,
      enableBorderGradient: isSelected,
      borderColors: isSelected ? FluidTheme.primaryFluidGradient : null,
      padding: const EdgeInsets.all(16),
      onTap: isSelecting ? onToggleSelected : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSelecting)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 2),
              child: context.isLiquidGlass
                  ? LiquidCheckbox(
                      value: isSelected,
                      onChanged: onToggleSelected == null
                          ? null
                          : (_) => onToggleSelected!(),
                    )
                  : Icon(
                      isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: isSelected
                          ? FluidTheme.primaryFluidGradient[0]
                          : textTertiary,
                    ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        word.word,
                        style: FluidTheme.headingSmall(isDark).copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (word.phonetic.isNotEmpty)
                      Text(
                        '/${word.phonetic}/',
                        style: FluidTheme.bodySmall(isDark).copyWith(
                          color: textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                if (word.definition.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    word.definition,
                    style: FluidTheme.bodyMedium(
                      isDark,
                    ).copyWith(color: textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _tag(
                      context,
                      isDark,
                      // 旧数据可能没有来源（null），按"学习"显示
                      icon: switch (favorite.source) {
                        FavoriteSource.reader => Icons.menu_book_outlined,
                        FavoriteSource.homeSearch => Icons.search,
                        _ => Icons.school_outlined,
                      },
                      label: switch (favorite.source) {
                        FavoriteSource.reader => context.tr.favoriteFromReader,
                        FavoriteSource.homeSearch =>
                          context.tr.favoriteFromHomeSearch,
                        _ => context.tr.favoriteFromStudy,
                      },
                    ),
                    //所属词库：收藏是跨词库的，不标出来就分不清这个词来自哪本书
                    if (bookName != null && bookName!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: _tag(
                          context,
                          isDark,
                          icon: Icons.library_books_outlined,
                          label: bookName!,
                          accent: FluidTheme.info,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    //日期也可收缩：与来源/词库标签同行时，窄屏 + 大字体下
                    //整体会超出卡片被裁，这里让它先让位（而非整行溢出）
                    Flexible(
                      child: Text(
                        _formatDate(favorite.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FluidTheme.bodySmall(
                          isDark,
                        ).copyWith(color: textTertiary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isSelecting) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.book_outlined, color: textSecondary),
              onPressed: onOpenDictionary,
              tooltip: context.tr.lookUpDict,
            ),
            IconButton(
              icon: Icon(Icons.star, color: FluidTheme.favorite),
              onPressed: onRemove,
              tooltip: context.tr.removeFromFavorites,
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String label,
    Color? accent,
  }) {
    final color = accent ?? FluidTheme.favorite;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.28 : 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          //词库名可能很长（放在 Flexible 里），压缩成单行省略号
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
