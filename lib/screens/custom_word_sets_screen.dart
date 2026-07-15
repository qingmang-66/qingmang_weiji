import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/providers/providers.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/page_transitions.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../widgets/edit_set_dialog.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/study_mode_picker.dart';
import 'pre_study_screen.dart';
import 'word_detail_screen.dart';

class CustomWordSetsScreen extends StatefulWidget {
  const CustomWordSetsScreen({super.key});

  @override
  State<CustomWordSetsScreen> createState() => _CustomWordSetsScreenState();
}

class _CustomWordSetsScreenState extends State<CustomWordSetsScreen> {
  List<CustomWordSet> _sets = [];
  Map<int, int> _counts = {};
  bool _isLoading = true;

  /// 搜索关键字
  String _query = '';

  /// 列表排序方式
  CustomWordSetSortMode _sortMode = CustomWordSetSortMode.updatedDesc;

  /// 是否处于搜索模式（搜索框展开）
  bool _isSearching = false;

  /// 搜索框控制器
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final repo = DIContainer.instance.customWordSetRepository;
    final sets = await repo.getAllSets(query: _query, orderBy: _sortMode);
    final ids = sets.map((set) => set.id).whereType<int>().toList();
    final counts = await repo.getWordCounts(ids);
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _counts = counts;
      _isLoading = false;
    });
  }

  void _enterSearch() {
    setState(() => _isSearching = true);
  }

  void _exitSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _query = '';
    });
    _load();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
    _load();
  }

  Future<void> _createSet() async {
    final tr = context.tr;
    final result = await showEditSetDialog(
      context,
      title: tr.createWordSet,
      confirmText: tr.create,
    );
    if (result == null) return;
    await DIContainer.instance.customWordSetRepository.createSet(
      name: result.name,
      description: result.description,
    );
    await _load();
  }

  Future<void> _renameSet(CustomWordSet set) async {
    final tr = context.tr;
    final result = await showEditSetDialog(
      context,
      title: tr.renameSet,
      confirmText: tr.save,
      initialName: set.name,
      initialDescription: set.description,
    );
    if (result == null) return;
    // 名称和描述都未变时静默 return
    if (result.name == set.name && result.description == set.description) {
      return;
    }
    await DIContainer.instance.customWordSetRepository.renameSet(
      set,
      result.name,
      description: result.description,
    );
    await _load();
  }

  Future<void> _deleteSet(CustomWordSet set) async {
    final setId = set.id;
    if (setId == null) return;
    final tr = context.tr;
    final confirmed = await showFluidDialog<bool>(
      context: context,
      title: tr.deleteSet,
      content: Text(tr.deleteSetConfirm(set.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(tr.delete),
        ),
      ],
    );
    if (confirmed != true) return;
    await DIContainer.instance.customWordSetRepository.deleteSet(setId);
    await _load();
  }

  void _showSetActions(CustomWordSet set) {
    final tr = context.tr;
    showFluidDialog<void>(
      context: context,
      title: tr.setActionTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(tr.rename),
            onTap: () {
              Navigator.pop(context);
              _renameSet(set);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: FluidTheme.error),
            title: Text(tr.delete, style: TextStyle(color: FluidTheme.error)),
            onTap: () {
              Navigator.pop(context);
              _deleteSet(set);
            },
          ),
        ],
      ),
    );
  }

  /// 拼接列表项的元信息："120 个单词 · 2 天前"
  String _formatSetMeta(CustomWordSet set, int count) {
    final tr = context.tr;
    final countPart = tr.wordCountUnit(count);
    final lastPart = set.lastStudiedAt == null
        ? tr.neverStudied
        : _formatRelativeTime(set.lastStudiedAt!);
    return '$countPart · $lastPart';
  }

  /// 相对时间（刚刚 / N 小时前 / N 天前）
  String _formatRelativeTime(DateTime when) {
    final tr = context.tr;
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 5) return tr.justNow;
    if (diff.inHours < 24) return tr.hoursAgo(diff.inHours);
    if (diff.inDays < 30) return tr.daysAgo(diff.inDays);
    return tr.daysAgo(diff.inDays);
  }

  PopupMenuItem<CustomWordSetSortMode> _buildSortMenuItem(
    CustomWordSetSortMode value,
    String text,
  ) {
    return PopupMenuItem<CustomWordSetSortMode>(
      value: value,
      child: Row(
        children: [
          Icon(
            _sortMode == value
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 18,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final textTertiary = FluidTheme.getTextTertiaryColor(isDark);
    final tr = context.tr;

    return FluidPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textPrimary),
          leading: _isSearching
              ? IconButton(
                  icon: Icon(Icons.arrow_back, color: textPrimary),
                  onPressed: _exitSearch,
                )
              : null,
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: tr.searchSetsHint,
                    hintStyle: TextStyle(color: textTertiary),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    _query = value;
                    _load();
                  },
                )
              : Text(
                  tr.customWordSets,
                  style: FluidTheme.headingMedium(
                    isDark,
                  ).copyWith(color: textPrimary),
                ),
          actions: [
            if (_isSearching)
              IconButton(
                tooltip: tr.cancel,
                icon: Icon(Icons.clear, color: textPrimary),
                onPressed: _clearSearch,
              )
            else ...[
              IconButton(
                tooltip: tr.search,
                icon: Icon(Icons.search, color: textPrimary),
                onPressed: _enterSearch,
              ),
              PopupMenuButton<CustomWordSetSortMode>(
                tooltip: tr.sortBy,
                icon: Icon(Icons.sort, color: textPrimary),
                onSelected: (mode) {
                  setState(() => _sortMode = mode);
                  _load();
                },
                itemBuilder: (ctx) => [
                  _buildSortMenuItem(
                    CustomWordSetSortMode.updatedDesc,
                    tr.sortUpdatedDesc,
                  ),
                  _buildSortMenuItem(
                    CustomWordSetSortMode.nameAsc,
                    tr.sortNameAsc,
                  ),
                  _buildSortMenuItem(
                    CustomWordSetSortMode.wordCountDesc,
                    tr.sortWordCountDesc,
                  ),
                ],
              ),
              IconButton(
                tooltip: tr.create,
                icon: Icon(Icons.add, color: textPrimary),
                onPressed: _createSet,
              ),
            ],
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: FluidTheme.primaryFluidGradient[0],
                ),
              )
            : _sets.isEmpty
            ? Center(
                child: Text(
                  tr.noCustomSets,
                  style: FluidTheme.bodyMedium(
                    isDark,
                  ).copyWith(color: textSecondary),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _sets.length,
                itemBuilder: (context, index) {
                  final set = _sets[index];
                  final count = _counts[set.id] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FluidCard(
                      enableShimmer: false,
                      padding: const EdgeInsets.all(16),
                      onTap: () => Navigator.of(context)
                          .push(
                            PageTransitions.slideFromRight(
                              page: CustomWordSetDetailScreen(set: set),
                            ),
                          )
                          .then((_) => _load()),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_special,
                            color: FluidTheme.primaryFluidGradient[0],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  set.name,
                                  style: FluidTheme.labelLarge(
                                    isDark,
                                  ).copyWith(color: textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (set.description != null &&
                                    set.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    set.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: FluidTheme.bodySmall(
                                      isDark,
                                    ).copyWith(color: textSecondary),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  _formatSetMeta(set, count),
                                  style: FluidTheme.bodySmall(
                                    isDark,
                                  ).copyWith(color: textTertiary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.more_vert, color: textSecondary),
                            onPressed: () => _showSetActions(set),
                          ),
                          Icon(Icons.chevron_right, color: textSecondary),
                        ],
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: _isSearching
            ? null
            : FloatingActionButton(
                onPressed: _createSet,
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}

class CustomWordSetDetailScreen extends StatefulWidget {
  final CustomWordSet set;

  const CustomWordSetDetailScreen({super.key, required this.set});

  @override
  State<CustomWordSetDetailScreen> createState() =>
      _CustomWordSetDetailScreenState();
}

class _CustomWordSetDetailScreenState extends State<CustomWordSetDetailScreen> {
  List<Word> _words = [];

  /// 词集内排序方式
  CustomWordSetItemSortMode _itemSortMode = CustomWordSetItemSortMode.addedAsc;

  /// 词集元数据（用于展示描述 + 上次学习时间）
  CustomWordSet? _setMeta;

  final Set<int> _selectedWordIds = {};
  bool _isLoading = true;
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final setId = widget.set.id;
    if (setId == null) return;
    setState(() => _isLoading = true);
    final repo = DIContainer.instance.customWordSetRepository;
    final words = await repo.getWordsInSet(setId, orderBy: _itemSortMode);
    final setMeta = await repo.getSet(setId);
    if (!mounted) return;
    setState(() {
      _words = words;
      _setMeta = setMeta ?? widget.set;
      _selectedWordIds.removeWhere(
        (id) => !_words.any((word) => word.id == id),
      );
      _isLoading = false;
    });
  }

  Future<void> _startStudy() async {
    final setId = widget.set.id;
    if (setId == null || _words.isEmpty) return;
    final mode = await showStudyModePicker(context);
    if (mode == null || !mounted) return;
    final request = await DIContainer.instance.specializedStudyService
        .buildCustomWordSetRequest(setId: setId, studyMode: mode);
    if (!mounted) return;
    if (request == null) {
      ErrorHandler.showError(context, context.tr.noLearnableWordsInSet);
      return;
    }
    Navigator.of(context)
        .push(
          PageTransitions.slideFromRight(
            page: PreStudyScreen.specialized(request: request, words: _words),
          ),
        )
        .then((_) => _load());
  }

  Future<void> _removeWord(Word word) async {
    final setId = widget.set.id;
    final wordId = word.id;
    if (setId == null || wordId == null) return;
    await DIContainer.instance.customWordSetRepository.removeWords(setId, [
      wordId,
    ]);
    await _load();
  }

  void _toggleSelecting() {
    setState(() {
      _isSelecting = !_isSelecting;
      _selectedWordIds.clear();
    });
  }

  void _toggleWordSelected(Word word) {
    final wordId = word.id;
    if (wordId == null) return;
    setState(() {
      if (_selectedWordIds.contains(wordId)) {
        _selectedWordIds.remove(wordId);
      } else {
        _selectedWordIds.add(wordId);
      }
    });
  }

  void _toggleSelectAll() {
    final allIds = _words.map((word) => word.id).whereType<int>().toSet();
    setState(() {
      if (_selectedWordIds.length == allIds.length) {
        _selectedWordIds.clear();
      } else {
        _selectedWordIds
          ..clear()
          ..addAll(allIds);
      }
    });
  }

  Future<void> _removeSelectedWords() async {
    final setId = widget.set.id;
    if (setId == null || _selectedWordIds.isEmpty) return;
    final tr = context.tr;
    final count = _selectedWordIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr.batchRemoveWords),
        content: Text(tr.batchRemoveWordsConfirm(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr.remove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DIContainer.instance.customWordSetRepository.removeWords(
      setId,
      _selectedWordIds.toList(),
    );
    if (!mounted) return;
    setState(() {
      _selectedWordIds.clear();
      _isSelecting = false;
    });
    await _load();
  }

  /// 阶段三：自定义词集增强 - 批量移动到其他词集
  Future<void> _moveSelectedTo() async {
    final tr = context.tr;
    final currentSetId = widget.set.id;
    if (currentSetId == null || _selectedWordIds.isEmpty) return;
    final repo = DIContainer.instance.customWordSetRepository;
    final allSets = await repo.getAllSets();
    if (!mounted) return;
    final candidates = allSets
        .where((s) => s.id != currentSetId)
        .toList(growable: false);
    if (candidates.isEmpty) {
      ErrorHandler.showError(context, tr.noOtherSets);
      return;
    }

    final target = await showFluidDialog<int>(
      context: context,
      title: tr.moveToSetTitle,
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: candidates.length,
          itemBuilder: (_, i) {
            final s = candidates[i];
            return ListTile(
              leading: const Icon(Icons.folder_special),
              title: Text(s.name),
              subtitle: s.description != null && s.description!.isNotEmpty
                  ? Text(s.description!)
                  : null,
              onTap: () => Navigator.pop(context, s.id),
            );
          },
        ),
      ),
    );
    if (target == null || !mounted) return;

    try {
      // 原子移动单词，避免添加成功但移除失败导致数据不一致
      await repo.moveWords(currentSetId, target, _selectedWordIds.toList());
      if (!mounted) return;
      ErrorHandler.showSuccess(context, tr.movedToSet);
      setState(() {
        _selectedWordIds.clear();
        _isSelecting = false;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: tr.moveToSetFailed,
      );
    }
  }

  /// 词集内排序菜单项构造
  PopupMenuItem<CustomWordSetItemSortMode> _buildItemSortMenuItem(
    CustomWordSetItemSortMode value,
    String text,
  ) {
    return PopupMenuItem<CustomWordSetItemSortMode>(
      value: value,
      child: Row(
        children: [
          Icon(
            _itemSortMode == value
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 18,
            color: FluidTheme.primaryFluidGradient[0],
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  /// 相对时间（刚刚 / N 小时前 / N 天前）
  String _formatRelativeTime(DateTime when) {
    final tr = context.tr;
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 5) return tr.justNow;
    if (diff.inHours < 24) return tr.hoursAgo(diff.inHours);
    if (diff.inDays < 30) return tr.daysAgo(diff.inDays);
    return tr.daysAgo(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final textTertiary = FluidTheme.getTextTertiaryColor(isDark);
    final tr = context.tr;

    final hasSetStudied = _setMeta?.lastStudiedAt != null;

    return FluidPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textPrimary),
          leading: _isSelecting
              ? IconButton(
                  icon: Icon(Icons.close, color: textPrimary),
                  onPressed: _toggleSelecting,
                )
              : null,
          title: Text(
            _isSelecting
                ? tr.selectedWordCount(_selectedWordIds.length)
                : widget.set.name,
            style: FluidTheme.headingMedium(
              isDark,
            ).copyWith(color: textPrimary),
          ),
          actions: [
            if (_isSelecting) ...[
              IconButton(
                tooltip: tr.selectAll,
                icon: Icon(Icons.select_all, color: textPrimary),
                onPressed: _words.isEmpty ? null : _toggleSelectAll,
              ),
              // 阶段三：自定义词集增强 - 批量移动到其他词集
              IconButton(
                tooltip: tr.moveToSet,
                icon: Icon(Icons.drive_file_move, color: textPrimary),
                onPressed: _selectedWordIds.isEmpty ? null : _moveSelectedTo,
              ),
              IconButton(
                tooltip: tr.removeSelected,
                icon: Icon(Icons.delete_outline, color: FluidTheme.error),
                onPressed: _selectedWordIds.isEmpty
                    ? null
                    : _removeSelectedWords,
              ),
            ] else ...[
              // 阶段三：自定义词集增强 - 词集内排序
              PopupMenuButton<CustomWordSetItemSortMode>(
                tooltip: tr.sortBy,
                icon: Icon(Icons.sort, color: textPrimary),
                onSelected: (mode) {
                  setState(() => _itemSortMode = mode);
                  _load();
                },
                itemBuilder: (ctx) => [
                  _buildItemSortMenuItem(
                    CustomWordSetItemSortMode.addedAsc,
                    tr.sortAddedAsc,
                  ),
                  _buildItemSortMenuItem(
                    CustomWordSetItemSortMode.wordAsc,
                    tr.sortWordAsc,
                  ),
                ],
              ),
              IconButton(
                tooltip: tr.select,
                icon: Icon(Icons.checklist, color: textPrimary),
                onPressed: _words.isEmpty ? null : _toggleSelecting,
              ),
              IconButton(
                icon: Icon(Icons.play_circle_outline, color: textPrimary),
                onPressed: _words.isEmpty ? null : _startStudy,
              ),
            ],
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: FluidTheme.primaryFluidGradient[0],
                ),
              )
            : Column(
                children: [
                  // 阶段三：自定义词集增强 - 详情页头部信息卡
                  _buildHeaderCard(
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    textTertiary: textTertiary,
                  ),
                  Expanded(
                    child: _words.isEmpty
                        ? Center(
                            child: Text(
                              tr.emptySetHint,
                              style: FluidTheme.bodyMedium(
                                isDark,
                              ).copyWith(color: textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _words.length,
                            itemBuilder: (context, index) {
                              final word = _words[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: FluidCard(
                                  enableShimmer: false,
                                  padding: const EdgeInsets.all(14),
                                  onTap: _isSelecting
                                      ? () => _toggleWordSelected(word)
                                      : () => Navigator.of(context)
                                            .push(
                                              PageTransitions.slideFromRight(
                                                page: WordDetailScreen(
                                                  word: word,
                                                ),
                                              ),
                                            )
                                            .then((_) => _load()),
                                  child: Row(
                                    children: [
                                      if (_isSelecting) ...[
                                        Checkbox(
                                          value:
                                              word.id != null &&
                                              _selectedWordIds.contains(
                                                word.id,
                                              ),
                                          onChanged: (_) =>
                                              _toggleWordSelected(word),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    word.word,
                                                    style:
                                                        FluidTheme.labelLarge(
                                                          isDark,
                                                        ).copyWith(
                                                          color: textPrimary,
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                // 阶段三：自定义词集增强 - 整集已学标识
                                                if (hasSetStudied) ...[
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                    Icons.check_circle,
                                                    size: 14,
                                                    color: FluidTheme
                                                        .primaryFluidGradient[0],
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (word.definition.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                word.definition,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    FluidTheme.bodySmall(
                                                      isDark,
                                                    ).copyWith(
                                                      color: textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (!_isSelecting)
                                        IconButton(
                                          icon: Icon(
                                            Icons.remove_circle_outline,
                                            color: FluidTheme.error,
                                          ),
                                          onPressed: () => _removeWord(word),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _isSelecting
                        ? Row(
                            children: [
                              Expanded(
                                child: FluidButton(
                                  text: _selectedWordIds.length == _words.length
                                      ? tr.deselectAll
                                      : tr.selectAll,
                                  icon: Icons.select_all,
                                  onPressed: _toggleSelectAll,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FluidButton(
                                  text: tr.removeSelected,
                                  icon: Icons.delete_outline,
                                  isEnabled: _selectedWordIds.isNotEmpty,
                                  onPressed: _selectedWordIds.isEmpty
                                      ? null
                                      : _removeSelectedWords,
                                ),
                              ),
                            ],
                          )
                        : FluidButton(
                            text: tr.startSetStudy,
                            icon: Icons.play_arrow,
                            expanded: true,
                            isEnabled: _words.isNotEmpty,
                            onPressed: _words.isEmpty ? null : _startStudy,
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 阶段三：自定义词集增强 - 详情页头部信息（描述 + 单词数 + 上次学习时间）
  Widget _buildHeaderCard({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
  }) {
    final tr = context.tr;
    final hasDescription =
        _setMeta?.description != null && _setMeta!.description!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasDescription) ...[
            Text(
              _setMeta!.description!,
              style: FluidTheme.bodyMedium(
                isDark,
              ).copyWith(color: textSecondary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Icon(Icons.text_fields, size: 14, color: textTertiary),
              const SizedBox(width: 4),
              Text(
                tr.wordCountUnit(_words.length),
                style: FluidTheme.bodySmall(
                  isDark,
                ).copyWith(color: textTertiary, fontSize: 12),
              ),
              const SizedBox(width: 12),
              Icon(Icons.history, size: 14, color: textTertiary),
              const SizedBox(width: 4),
              Text(
                _setMeta?.lastStudiedAt == null
                    ? tr.neverStudied
                    : _formatRelativeTime(_setMeta!.lastStudiedAt!),
                style: FluidTheme.bodySmall(
                  isDark,
                ).copyWith(color: textTertiary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
