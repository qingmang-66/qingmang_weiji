import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/app_initialization_service.dart';
import '../services/daos/wrong_word_dao.dart';
import '../services/database_service.dart';
import '../services/di_container.dart';
import '../services/guide_service.dart';
import '../services/providers/providers.dart';
import '../services/wrong_word_ranking_service.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/guide_keys.dart';
import '../utils/page_transitions.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../widgets/coach_mark_overlay.dart';
import '../widgets/dictionary_dialog.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/liquid_controls.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/word_collection_settings_panel.dart';
import 'pre_study_screen.dart';

class WrongWordsScreen extends StatefulWidget {
  const WrongWordsScreen({super.key});

  @override
  State<WrongWordsScreen> createState() => _WrongWordsScreenState();
}

class _WrongWordsScreenState extends State<WrongWordsScreen> {
  List<Word> _wrongWords = [];
  Map<int, int> _wrongCounts = {};
  bool _isLoading = true;
  bool _isSelecting = false;
  final Set<int> _selectedWords = {};

  /// 连续答对次数（"连续答对 3 次移出错词本"的进度）
  final Map<int, int> _streaks = {};

  /// 主要错因（看答案 / 拼写错 / 听写错 / 选错 / 回忆不出）
  final Map<int, WrongWordCause> _causes = {};

  /// 按错因筛选；null 表示不筛选
  WrongWordCause? _causeFilter;

  /// 错词元数据快照（撤销"标记已掌握"时按原值回插，而不是当新错词计数）
  final Map<int, WrongWordMetaRow> _meta = {};

  /// 排序模式：默认按错误次数 desc
  _WrongWordSortMode _sortMode = _WrongWordSortMode.wrongCountDesc;

  /// 本页实例是否已调度过引导（列表数据到齐后只提示一次）
  bool _guideScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadWrongWords();
  }

  @override
  void dispose() {
    //兜底定时器刻意不在这里取消：提示挂在根 ScaffoldMessenger 上，页面 pop 后
    //它仍然贴在首页底部，而自动计时要等入场动画播完才启动、动画又靠 ticker
    //驱动。此时取消定时器就等于放任它永久停留。定时器闭包只持有
    //messengerState（不持有本页 context），跨页面执行也安全；正常流程下
    //SnackBar 4 秒已自行退场，5 秒的兜底 removeCurrentSnackBar 是空操作。
    super.dispose();
  }

  /// 首次进入错词集：介绍专项复习与错词的错因 / 攻克进度。
  ///
  /// 与学习、阅读的引导相互独立，各自只提示一次；错词为空时步骤为空，
  /// [CoachMarkOverlay] 会直接跳过并留待下次再引导。
  Future<void> _showGuide() async {
    if (!mounted) return;
    await CoachMarkOverlay.maybeShow(
      context,
      guideId: GuideService.tipWrongWords,
      steps: () => _wrongWords.isEmpty
          ? const <CoachMarkStep>[]
          : [
              CoachMarkStep(
                targetKey: guideWrongWordsStudyKey,
                title: context.tr.coachWrongWordsStudyTitle,
                message: context.tr.coachWrongWordsStudyMsg,
                icon: Icons.school_outlined,
              ),
              CoachMarkStep(
                targetKey: guideWrongWordsFirstKey,
                title: context.tr.coachWrongWordsItemTitle,
                message: context.tr.coachWrongWordsItemMsg,
                icon: Icons.error_outline,
              ),
            ],
    );
  }

  Future<void> _loadWrongWords() async {
    setState(() => _isLoading = true);

    try {
      //一次取回词条 + 元数据（错误次数 / 连续答对），替代原先逐个 getWrongCount
      //的 N+1 查询
      final rows = await DatabaseService.wrongWordDao.getAllWithMeta();
      final words = rows.map((row) => row.word).toList();
      final counts = <int, int>{};
      final streaks = <int, int>{};
      final meta = <int, WrongWordMetaRow>{};
      for (final row in rows) {
        final id = row.word.id;
        if (id == null) continue;
        counts[id] = row.wrongCount;
        streaks[id] = row.correctStreak;
        meta[id] = row;
      }

      //错因聚合：老库的 wrong_words_strength 可能没有数据，取不到就不显示标签
      final causes = <int, WrongWordCause>{};
      try {
        final aggregates = await DatabaseService.wrongWordDao
            .getCauseAggregates(counts.keys.toList());
        for (final entry in aggregates.entries) {
          causes[entry.key] = entry.value.dominant;
        }
      } catch (e) {
        debugPrint('加载错因聚合失败：$e');
      }

      // 按当前排序模式排序
      await _applySort(words, counts);

      if (mounted) {
        setState(() {
          _wrongWords = words;
          _wrongCounts = counts;
          _streaks
            ..clear()
            ..addAll(streaks);
          _meta
            ..clear()
            ..addAll(meta);
          _causes
            ..clear()
            ..addAll(causes);
          _isLoading = false;
        });
        //数据到齐、目标控件挂上之后再提示
        if (!_guideScheduled) {
          _guideScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showGuide();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.handleException(
          context,
          e,
          fallbackMessage: context.tr.loadWrongWordsFailed,
        );
      }
    }
  }

  /// 根据 _sortMode 对 _wrongWords / _wrongCounts 排序
  ///
  /// - 默认模式：按错误次数 desc（DAO 顺序即可）
  /// - 按热度：调用 WrongWordRankingService 计算综合评分后排序
  Future<void> _applySort(List<Word> words, Map<int, int> counts) async {
    if (words.isEmpty) return;
    switch (_sortMode) {
      case _WrongWordSortMode.wrongCountDesc:
        // 保持 DAO 默认顺序
        return;
      case _WrongWordSortMode.hotness:
        try {
          final rankingService = WrongWordRankingService();
          final ranked = await rankingService.getTopWrongWords(limit: null);
          final rankMap = <int, int>{};
          for (var i = 0; i < ranked.length; i++) {
            final id = ranked[i].word.id;
            if (id != null) rankMap[id] = i;
          }
          words.sort((a, b) {
            final ra = rankMap[a.id] ?? 1 << 20;
            final rb = rankMap[b.id] ?? 1 << 20;
            return ra.compareTo(rb);
          });
        } catch (e) {
          // 热度排序失败时退回到默认顺序，不影响用户
          if (mounted) {
            ErrorHandler.handleException(
              context,
              e,
              fallbackMessage: context.tr.hotnessSortFailed,
            );
          }
        }
    }
  }

  /// 取出某错词的原始快照，供撤销时原样回插
  WrongWordSnapshot? _snapshotOf(int wordId) {
    final row = _meta[wordId];
    if (row == null) return null;
    return WrongWordSnapshot(
      wordId: wordId,
      wrongCount: row.wrongCount,
      correctStreak: row.correctStreak,
      firstWrongTime: row.firstWrongTime ?? row.lastWrongTime,
      lastWrongTime: row.lastWrongTime,
    );
  }

  /// 撤销条自身的兜底移除定时器
  Timer? _undoDismissTimer;

  /// 删除后的可撤销提示
  ///
  /// "标记已掌握"原本是不可逆的物理删除，手滑一下就彻底没了；
  /// 这里给一条 4 秒的撤销入口，按快照原值回插（错误次数/时间/攻坚进度都不丢）。
  ///
  /// 除了让 SnackBar 自己超时，这里还挂一条兜底定时器：SnackBar 的自动消失是在
  /// **入场动画播完之后**才启动计时，而动画靠 Scaffold 的 Ticker 驱动 ——
  /// 页面切后台/路由切换导致 ticker 被静音时，计时永远不会开始，
  /// 这条提示就会一直贴在屏幕底部（用户反馈"一直不会消失"）。
  /// 兜底用 removeCurrentSnackBar 直接摘除，不依赖任何动画，也不受本页
  /// 是否已销毁影响（messenger 挂在根路由上，页面 pop 后提示仍在）。
  void _showUndoBar(List<WrongWordSnapshot> snapshots, String message) {
    if (snapshots.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    //先取消上一条的兜底定时器：否则连点标记时，旧定时器会把新提示提前摘掉
    _undoDismissTimer?.cancel();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: context.tr.undo,
            onPressed: () => _undoRemove(snapshots),
          ),
        ),
      );
    _undoDismissTimer = Timer(const Duration(seconds: 5), () {
      messenger.removeCurrentSnackBar();
    });
  }

  Future<void> _undoRemove(List<WrongWordSnapshot> snapshots) async {
    try {
      await DIContainer.instance.wrongWordService.restoreWrongWords(snapshots);
      AppInitializationService.notifyDatabaseRefreshed();
      if (!mounted) return;
      await _loadWrongWords();
      if (!mounted) return;
      ErrorHandler.showSuccess(context, context.tr.restoredToWrongWords);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: context.tr.operationFailed,
      );
    }
  }

  Future<void> _markAsMastered(int wordId) async {
    final snapshot = _snapshotOf(wordId);
    try {
      final service = DIContainer.instance.wrongWordService;
      await service.removeWrongWord(wordId);
      //通知仪表盘刷新错词计数
      AppInitializationService.notifyDatabaseRefreshed();
      if (mounted) {
        setState(() {
          _wrongWords.removeWhere((w) => w.id == wordId);
          _wrongCounts.remove(wordId);
          _selectedWords.remove(wordId);
        });
        _showUndoBar([?snapshot], context.tr.removedFromWrongWords);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(
          context,
          e,
          fallbackMessage: context.tr.operationFailed,
        );
      }
    }
  }

  Future<void> _markSelectedAsMastered() async {
    if (_selectedWords.isEmpty) return;

    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    final confirmed = await showFluidDialog<bool>(
      context: context,
      title: context.tr.confirmMastered,
      content: Text(
        '${context.tr.confirmMarkMastered} ${context.tr.wrongWordsCount(_selectedWords.length)}',
        style: FluidTheme.bodyMedium(isDark).copyWith(color: textPrimary),
      ),
      actions: [
        FluidTextButton(
          text: context.tr.cancel,
          onPressed: () => Navigator.pop(context, false),
        ),
        FluidButton(
          text: context.tr.confirm,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (confirmed != true) return;

    try {
      final service = DIContainer.instance.wrongWordService;
      final selectedCount = _selectedWords.length;
      final snapshots = [
        for (final id in _selectedWords) _snapshotOf(id),
      ].whereType<WrongWordSnapshot>().toList(growable: false);
      await service.removeWrongWords(_selectedWords.toList());
      //通知仪表盘刷新错词计数
      AppInitializationService.notifyDatabaseRefreshed();
      if (mounted) {
        setState(() {
          _wrongWords.removeWhere((w) => _selectedWords.contains(w.id));
          _wrongCounts.removeWhere((key, _) => _selectedWords.contains(key));
          _selectedWords.clear();
          _isSelecting = false;
        });
        _showUndoBar(
          snapshots,
          '${context.tr.markedMasteredCount} ${context.tr.wrongWordsCount(selectedCount)}',
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(
          context,
          e,
          fallbackMessage: context.tr.operationFailed,
        );
      }
    }
  }

  /// 多选：一键全选当前列表
  void _selectAllWrongWords() {
    setState(() {
      _selectedWords.addAll(
        _wrongWords.map((w) => w.id).whereType<int>().where((id) => id > 0),
      );
    });
  }

  void _exitSelecting() {
    setState(() {
      _isSelecting = false;
      _selectedWords.clear();
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
            label: context.tr.filterByCause,
            value: _causeFilter == null
                ? context.tr.allCauses
                : _wrongCauseLabel(context, _causeFilter!),
            highlight: _causeFilter != null,
            onTap: () async {
              if (await _pickCauseFilter() && mounted) Navigator.pop(context);
            },
          ),
          _dialogAction(
            icon: Icons.sort,
            label: context.tr.sortBy,
            value: _sortMode == _WrongWordSortMode.wrongCountDesc
                ? context.tr.wrongCount
                : context.tr.sortByHotness,
            onTap: () async {
              if (await _pickSortMode() && mounted) Navigator.pop(context);
            },
          ),
          _dialogAction(
            icon: Icons.tune,
            label: context.tr.collectionSettings,
            onTap: () => showWrongWordsSettings(context),
          ),
        ],
      ),
    );
  }

  /// 「更多」弹窗里的一行：复用 [_menuRow] 的排版，右侧补一个进入箭头
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
            Expanded(
              child: _menuRow(
                icon: icon,
                label: label,
                value: value,
                highlight: highlight,
              ),
            ),
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

  /// 「更多」菜单里的一行：图标 + 名称 + 当前值
  Widget _menuRow({
    required IconData icon,
    required String label,
    String? value,
    bool highlight = false,
  }) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return Row(
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
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              color: highlight
                  ? FluidTheme.primaryAccessible(isDark)
                  : FluidTheme.getTextSecondaryColor(isDark),
            ),
          ),
        ],
      ],
    );
  }

  /// 按错因筛选：弹窗单选（错因数据来自错词强度事件表）
  ///
  /// 返回 true 表示用户做了选择（外层菜单应随之收起）
  Future<bool> _pickCauseFilter() async {
    const causes = [
      WrongWordCause.revealed,
      WrongWordCause.spelling,
      WrongWordCause.listening,
      WrongWordCause.quiz,
      WrongWordCause.recall,
    ];
    final current = _causeFilter;
    final picked = await showFluidDialog<int>(
      context: context,
      title: context.tr.filterByCause,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _optionTile(
            label: context.tr.allCauses,
            selected: current == null,
            onTap: () => Navigator.pop(context, 0),
          ),
          for (var i = 0; i < causes.length; i++)
            _optionTile(
              label: _wrongCauseLabel(context, causes[i]),
              selected: current == causes[i],
              onTap: () => Navigator.pop(context, i + 1),
            ),
        ],
      ),
    );
    if (!mounted || picked == null) return false;
    setState(() {
      _causeFilter = picked == 0 ? null : causes[picked - 1];
    });
    return true;
  }

  /// 排序方式：弹窗单选，切换后按新顺序重新加载
  ///
  /// 返回 true 表示用户做了选择（外层菜单应随之收起）
  Future<bool> _pickSortMode() async {
    final picked = await showFluidDialog<int>(
      context: context,
      title: context.tr.sortBy,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _optionTile(
            label: context.tr.wrongCount,
            selected: _sortMode == _WrongWordSortMode.wrongCountDesc,
            onTap: () => Navigator.pop(context, 0),
          ),
          _optionTile(
            label: context.tr.sortByHotness,
            selected: _sortMode == _WrongWordSortMode.hotness,
            onTap: () => Navigator.pop(context, 1),
          ),
        ],
      ),
    );
    if (!mounted || picked == null) return false;
    final mode = picked == 0
        ? _WrongWordSortMode.wrongCountDesc
        : _WrongWordSortMode.hotness;
    if (mode != _sortMode) {
      setState(() => _sortMode = mode);
      await _loadWrongWords();
    }
    return true;
  }

  /// 弹窗里的单选项
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

  Future<int?> _pickReviewMode() async {
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

  Future<void> _studyWrongWords() async {
    if (_wrongWords.isEmpty) return;

    final mode = await _pickReviewMode();
    if (mode == null || !mounted) return;

    final di = DIContainer.instance;
    final selectedIds = _isSelecting ? _selectedWords.toList() : <int>[];
    final request = await di.specializedStudyService.buildWrongWordsRequest(
      wordBookId: null,
      selectedWordIds: selectedIds,
      studyMode: mode,
    );

    if (!mounted) return;
    if (request == null) {
      ErrorHandler.showError(context, context.tr.noWrongWordsToReview);
      return;
    }

    final words = await di.wrongWordService.getWrongWordsByIds(request.wordIds);
    if (!mounted) return;
    if (words.isEmpty) {
      ErrorHandler.showError(context, context.tr.noWrongWordsToReview);
      return;
    }

    Navigator.of(context)
        .push(
          PageTransitions.slideFromRight(
            page: PreStudyScreen.specialized(request: request, words: words),
          ),
        )
        .then((_) => _loadWrongWords());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    // 错因筛选后的列表在本次 build 里要用两次（判空 + 构建），
    // 而 _visibleWords 每次访问都会全量 where + toList，这里只算一次
    final visibleWords = _visibleWords;

    return FluidPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textPrimary),
          title: Text(
            context.tr.wrongWords,
            style: FluidTheme.headingMedium(
              isDark,
            ).copyWith(color: textPrimary),
          ),
          actions: [
            if (_wrongWords.isEmpty) ...[
              IconButton(
                icon: Icon(Icons.refresh, color: textPrimary),
                onPressed: _loadWrongWords,
                tooltip: context.tr.refresh,
              ),
            ] else ...[
              if (_isSelecting) ...[
                //多选进行中只留「全选 / 退出」，批量操作走右下角悬浮按钮
                IconButton(
                  icon: Icon(Icons.select_all, color: textPrimary),
                  onPressed: _selectAllWrongWords,
                  tooltip: context.tr.selectAll,
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textPrimary),
                  onPressed: _exitSelecting,
                  tooltip: context.tr.cancelSelect,
                ),
              ] else ...[
                //主操作：专项复习
                IconButton(
                  key: guideWrongWordsStudyKey,
                  icon: Icon(Icons.school, color: textPrimary),
                  onPressed: _studyWrongWords,
                  tooltip: context.tr.specialReview,
                ),
                //「选择」是高频批量入口，独立成按钮而不是藏在「更多」里
                IconButton(
                  icon: Icon(Icons.checklist, color: textPrimary),
                  onPressed: () {
                    setState(() {
                      _isSelecting = true;
                      _selectedWords.clear();
                    });
                  },
                  tooltip: context.tr.select,
                ),
                //筛选 / 排序 / 集合设置收进「更多」：
                //此前 5 个图标并排挤在标题右侧，标题被压成「错…」，
                //一排无文字说明的图标与整页卡片风格也格格不入
                IconButton(
                  icon: Icon(Icons.more_vert, color: textPrimary),
                  onPressed: _showMoreSheet,
                  tooltip: context.tr.moreOptions,
                ),
              ],
            ],
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: FluidTheme.primaryFluidGradient[0],
                ),
              )
            : _wrongWords.isEmpty
            ? _buildEmptyState(isDark)
            : visibleWords.isEmpty
            ? _buildFilteredEmptyState(isDark)
            : _buildWrongWordsList(isDark, visibleWords),
        floatingActionButton: _isSelecting && _selectedWords.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _markSelectedAsMastered,
                //底色是主色实底 #F093FB，白字/白图标仅 2.04:1，改用深色前景（8.34:1）
                icon: Icon(Icons.check, color: FluidTheme.onGradientForeground),
                label: Text(
                  '${_selectedWords.length}',
                  style: TextStyle(color: FluidTheme.onGradientForeground),
                ),
                backgroundColor: FluidTheme.primaryFluidGradient[0],
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: FluidTheme.success.withValues(alpha: isDark ? 0.18 : 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: FluidTheme.success.withValues(
                  alpha: isDark ? 0.35 : 0.25,
                ),
              ),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: FluidTheme.success,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr.great,
            style: FluidTheme.headingSmall(
              isDark,
            ).copyWith(color: textPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr.noWrongWordsHint,
            style: FluidTheme.bodyMedium(isDark).copyWith(color: textSecondary),
          ),
          const SizedBox(height: 32),
          FluidButton(
            text: context.tr.back,
            icon: Icons.arrow_back,
            onPressed: () => Navigator.pop(context),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ],
      ),
    );
  }

  /// 应用错因筛选后的可见列表
  List<Word> get _visibleWords => _causeFilter == null
      ? _wrongWords
      : _wrongWords.where((w) => _causes[w.id] == _causeFilter).toList();

  /// 当前错因下没有错词：给一个"清除筛选"的出口，避免看起来像列表坏了
  Widget _buildFilteredEmptyState(bool isDark) {
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 56,
              color: FluidTheme.getTextTertiaryColor(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              '${_wrongCauseLabel(context, _causeFilter!)} · '
              '${context.tr.noMatchFound}',
              textAlign: TextAlign.center,
              style: FluidTheme.bodyMedium(
                isDark,
              ).copyWith(color: textSecondary),
            ),
            const SizedBox(height: 16),
            FluidButton(
              text: context.tr.allCauses,
              onPressed: () => setState(() => _causeFilter = null),
            ),
          ],
        ),
      ),
    );
  }

  /// [words] 由 build 传入（错因筛选后的可见列表，见 build 中的 visibleWords），
  /// 避免这里再算一遍全量 where + toList
  Widget _buildWrongWordsList(bool isDark, List<Word> words) {
    final settings = context.watch<WordCollectionSettingsProvider>();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final word = words[index];
        final wrongCount = _wrongCounts[word.id] ?? 1;
        final isSelected = _selectedWords.contains(word.id);

        final item = Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _WrongWordItem(
            word: word,
            wrongCount: wrongCount,
            showCount: settings.showWrongCount,
            streak: _streaks[word.id] ?? 0,
            cause: _causes[word.id],
            showProgress: settings.showMasteryProgress,
            isSelecting: _isSelecting,
            isSelected: isSelected,
            onToggleSelected: word.id != null
                ? () {
                    setState(() {
                      if (isSelected) {
                        _selectedWords.remove(word.id);
                      } else {
                        _selectedWords.add(word.id!);
                      }
                    });
                  }
                : null,
            onOpenDictionary: () {
              showDictionaryDialog(context: context, word: word.word);
            },
            onMarkAsMastered: word.id != null
                ? () => _markAsMastered(word.id!)
                : null,
          ),
        );
        // 第一条错词挂引导锚点，让「错因 / 攻克进度」的说明有落点
        if (index == 0) {
          return KeyedSubtree(key: guideWrongWordsFirstKey, child: item);
        }
        return item;
      },
    );
  }
}

class _WrongWordItem extends StatelessWidget {
  final Word word;
  final int wrongCount;

  /// 是否显示"×N"答错次数徽标（错题集设置里可关）
  final bool showCount;

  /// 连续答对次数（攻克进度）
  final int streak;

  /// 主要错因；null 表示没有可用的事件数据
  final WrongWordCause? cause;

  /// 是否显示攻克进度（错题集设置里可关）
  final bool showProgress;

  final bool isSelecting;
  final bool isSelected;
  final VoidCallback? onToggleSelected;
  final VoidCallback onOpenDictionary;
  final VoidCallback? onMarkAsMastered;

  const _WrongWordItem({
    required this.word,
    required this.wrongCount,
    required this.showCount,
    required this.streak,
    required this.cause,
    required this.showProgress,
    required this.isSelecting,
    required this.isSelected,
    required this.onToggleSelected,
    required this.onOpenDictionary,
    required this.onMarkAsMastered,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final textTertiary = FluidTheme.getTextTertiaryColor(isDark);
    final wrongColor = _wrongCountColor(wrongCount);
    //攻克进度只在"还差几次"时显示；次数与进度都被关掉时整个左侧栏位不再占位
    final showProgressChip =
        showProgress && streak < WrongWordReviewResult.masteredStreakThreshold;

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
              //玻璃模式用水银勾选框，经典模式保留原生勾选图标
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
          if (!isSelecting && (showCount || showProgressChip))
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 2),
              child: Column(
                children: [
                  if (showCount)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: wrongColor.withValues(
                          alpha: isDark ? 0.16 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: wrongColor.withValues(
                            alpha: isDark ? 0.28 : 0.20,
                          ),
                        ),
                      ),
                      child: Text(
                        '×$wrongCount',
                        style: TextStyle(
                          color: wrongColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  //攻克进度：答对 3 次即移出错题集，让用户看得到还差几次。
                  //零进度（0/3）同样要显示：只显示 streak > 0 时，
                  //打开开关后大部分错词没有任何进度信息，像是设置没生效
                  if (showProgressChip) ...[
                    if (showCount) const SizedBox(height: 6),
                    _progressChip(context, isDark),
                  ],
                ],
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
                //错因标签：数据来自 wrong_words_strength 事件表，老库可能为空
                //（这就是有的词条有错因、有的没有的原因：聚合不到事件的词
                //没有错因可显示）；设置里可整包关闭
                if (context.select<WordCollectionSettingsProvider, bool>(
                      (p) => p.showWrongCause,
                    ) &&
                    cause != null &&
                    cause != WrongWordCause.unknown) ...[
                  const SizedBox(height: 8),
                  _causeTag(context, isDark, cause!),
                ],
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
              icon: Icon(Icons.check_circle_outline, color: textSecondary),
              onPressed: onMarkAsMastered,
              tooltip: context.tr.markAsMastered,
            ),
          ],
        ],
      ),
    );
  }

  /// 攻克进度胶囊：连续答对 x/3
  Widget _progressChip(BuildContext context, bool isDark) {
    final color = FluidTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            '$streak/${WrongWordReviewResult.masteredStreakThreshold}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// 错因标签：这个小标签告诉你"当初是怎么错的"，比错误次数更有指导意义
  Widget _causeTag(BuildContext context, bool isDark, WrongWordCause cause) {
    final color = switch (cause) {
      WrongWordCause.revealed => FluidTheme.info,
      WrongWordCause.spelling => FluidTheme.warning,
      WrongWordCause.listening => FluidTheme.primaryFluidGradient[0],
      WrongWordCause.quiz => FluidTheme.success,
      WrongWordCause.recall || WrongWordCause.unknown => FluidTheme.error,
    };
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.28 : 0.20),
            ),
          ),
          child: Text(
            '${context.tr.wrongCause} · ${_wrongCauseLabel(context, cause)}',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Color _wrongCountColor(int count) {
    if (count >= 5) return FluidTheme.error;
    if (count >= 3) return FluidTheme.warning;
    if (count >= 2) return Colors.amber;
    return FluidTheme.primaryFluidGradient[0];
  }
}

/// 错因的中文/英文名（列表标签与筛选菜单共用）
String _wrongCauseLabel(BuildContext context, WrongWordCause cause) =>
    switch (cause) {
      WrongWordCause.revealed => context.tr.causeRevealed,
      WrongWordCause.spelling => context.tr.causeSpelling,
      WrongWordCause.listening => context.tr.causeListening,
      WrongWordCause.quiz => context.tr.causeQuiz,
      WrongWordCause.recall => context.tr.causeRecall,
      WrongWordCause.unknown => context.tr.causeUnknown,
    };

/// 错词页排序模式
enum _WrongWordSortMode {
  /// 按错误次数 desc（默认，DAO 直出）
  wrongCountDesc,

  /// 按热度（综合评分）排序
  hotness,
}
