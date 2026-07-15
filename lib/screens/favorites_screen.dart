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
import '../widgets/favorite_sheet.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/study_mode_picker.dart';
import 'pre_study_screen.dart';
import 'word_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Word> _words = [];
  List<MapEntry<String, int>> _groups = [];
  String? _selectedGroup;
  bool _isLoading = true;
  int _loadGeneration = 0;

  // 阶段三：排序与批量
  FavoriteSortMode _sortMode = FavoriteSortMode.createdDesc;
  bool _batchMode = false;
  final Set<int> _selectedIds = {};
  // 收藏元数据缓存（wordId -> FavoriteWord），用于列表展示
  Map<int, FavoriteWord> _favoriteMeta = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final group = _selectedGroup;
    final sort = _sortMode;
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final di = DIContainer.instance;
      final groups = await di.favoriteRepository.getGroups();
      if (!mounted || generation != _loadGeneration) return;
      final words = await di.favoriteRepository.getFavoriteWords(
        groupName: group,
        orderBy: sort,
      );
      if (!mounted || generation != _loadGeneration) return;
      // 预取所有收藏元数据，避免列表项 N+1 查询
      final allFavs = await di.favoriteRepository.getAllFavorites(
        groupName: group,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _groups = groups;
        _words = words;
        _favoriteMeta = {for (final f in allFavs) f.wordId: f};
        _isLoading = false;
        // 清理已不在结果中的选中项
        final visibleIds = words.map((w) => w.id).whereType<int>().toSet();
        _selectedIds.removeWhere((id) => !visibleIds.contains(id));
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _isLoading = false);
      ErrorHandler.showError(context, context.tr.loadFavoritesFailed);
    }
  }

  Future<void> _startStudy() async {
    if (_words.isEmpty) return;
    final mode = await showStudyModePicker(context);
    if (mode == null || !mounted) return;
    final di = DIContainer.instance;
    final request = await di.specializedStudyService.buildFavoritesRequest(
      wordBookId: null,
      groupName: _selectedGroup,
      studyMode: mode,
    );
    if (!mounted) return;
    if (request == null) {
      ErrorHandler.showError(context, context.tr.noFavoritesToStudy);
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

  Future<void> _remove(Word word) async {
    final wordId = word.id;
    if (wordId == null) return;
    try {
      await DIContainer.instance.favoriteRepository.removeFavorite(wordId);
      if (!mounted) return;
      ErrorHandler.showSuccess(context, context.tr.removedFromFavorites);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: context.tr.removeFavoriteFailed,
      );
    }
    await _load();
  }

  // === 阶段三：排序 ===
  void _onSortChanged(FavoriteSortMode mode) {
    setState(() => _sortMode = mode);
    _load();
  }

  // === 阶段三：批量模式 ===
  void _enterBatchMode() {
    setState(() {
      _batchMode = true;
      _selectedIds.clear();
    });
  }

  void _exitBatchMode() {
    setState(() {
      _batchMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(int wordId) {
    setState(() {
      if (_selectedIds.contains(wordId)) {
        _selectedIds.remove(wordId);
      } else {
        _selectedIds.add(wordId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _words.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_words.map((w) => w.id!).whereType<int>());
      }
    });
  }

  Future<void> _batchRemove() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr.removeSelected),
        content: Text(context.tr.batchRemoveConfirm(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              context.tr.confirm,
              style: TextStyle(color: FluidTheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await DIContainer.instance.favoriteRepository.removeFavorites(
        _selectedIds.toList(),
      );
      if (!mounted) return;
      ErrorHandler.showSuccess(context, context.tr.removedFromFavorites);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: context.tr.batchRemoveFavoritesFailed,
      );
    }
    _exitBatchMode();
    await _load();
  }

  Future<void> _batchMove({Set<int>? specificIds}) async {
    final ids = (specificIds ?? _selectedIds).toList();
    if (ids.isEmpty) return;
    final newGroup = await _pickGroup();
    if (newGroup == null || newGroup.isEmpty || !mounted) return;
    try {
      await DIContainer.instance.favoriteRepository.updateGroupBatch(
        ids,
        newGroup,
      );
      if (!mounted) return;
      ErrorHandler.showSuccess(context, context.tr.favoriteUpdated);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: context.tr.moveFavoriteFailed,
      );
    }
    if (specificIds == null) _exitBatchMode();
    await _load();
  }

  Future<String?> _pickGroup() async {
    // 弹出居中对话框：显示已有分组 + 新建输入框
    final key = GlobalKey<_GroupPickerSheetState>();
    return showFluidDialog<String>(
      context: context,
      title: context.tr.moveToGroup,
      content: _GroupPickerSheet(
        key: key,
        existingGroups: _groups.map((e) => e.key).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr.cancel),
        ),
        TextButton(
          onPressed: () => key.currentState?._confirm(),
          child: Text(context.tr.confirm),
        ),
      ],
    );
  }

  // === 阶段三：单项编辑 ===
  Future<void> _editItem(Word word) async {
    final wordId = word.id;
    if (wordId == null) return;
    final result = await showFavoriteSheet(context, wordId: wordId, edit: true);
    if (result == null || !mounted) return;
    try {
      await DIContainer.instance.favoriteRepository.updateGroup(
        wordId,
        result.groupName,
      );
      await DIContainer.instance.favoriteRepository.updateNote(
        wordId,
        result.note,
      );
      if (!mounted) return;
      ErrorHandler.showSuccess(context, context.tr.favoriteUpdated);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: context.tr.updateFavoriteFailed,
      );
    }
    await _load();
  }

  Future<void> _showItemActions(Word word) async {
    final wordId = word.id;
    if (wordId == null) return;
    final action = await showFluidDialog<_ItemAction>(
      context: context,
      title: context.tr.favoriteActionTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(context.tr.editFavorite),
            onTap: () => Navigator.pop(context, _ItemAction.edit),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move),
            title: Text(context.tr.moveToGroup),
            onTap: () => Navigator.pop(context, _ItemAction.move),
          ),
          ListTile(
            leading: Icon(Icons.bookmark_remove, color: FluidTheme.error),
            title: Text(context.tr.removeFromFavorites),
            onTap: () => Navigator.pop(context, _ItemAction.remove),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _ItemAction.edit:
        await _editItem(word);
        break;
      case _ItemAction.move:
        await _batchMove(specificIds: {wordId});
        break;
      case _ItemAction.remove:
        await _remove(word);
        break;
    }
  }

  // === 时间格式化 ===
  String _formatLastStudied(FavoriteWord? fav) {
    if (fav?.lastStudiedAt == null) {
      return '${context.tr.lastStudiedAt}：${context.tr.neverStudied}';
    }
    final when = fav!.lastStudiedAt!;
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 5) {
      return '${context.tr.lastStudiedAt}：${context.tr.justNow}';
    }
    if (diff.inHours < 24) {
      return '${context.tr.lastStudiedAt}：${context.tr.hoursAgo(diff.inHours)}';
    }
    if (diff.inDays < 30) {
      return '${context.tr.lastStudiedAt}：${context.tr.daysAgo(diff.inDays)}';
    }
    final dateStr = when.toLocal().toIso8601String().split('T').first;
    return '${context.tr.lastStudiedAt}：$dateStr';
  }

  // === UI：AppBar ===
  PreferredSizeWidget _buildAppBar(bool isDark, Color textPrimary) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: textPrimary),
      leading: _batchMode
          ? IconButton(icon: const Icon(Icons.close), onPressed: _exitBatchMode)
          : null,
      title: Text(
        _batchMode
            ? '${_selectedIds.length}/${_words.length}'
            : context.tr.favoritesTitle,
        style: FluidTheme.headingMedium(isDark).copyWith(color: textPrimary),
      ),
      actions: _batchMode
          ? _buildBatchActions()
          : _buildNormalActions(textPrimary),
    );
  }

  List<Widget> _buildNormalActions(Color textPrimary) {
    return [
      // 排序菜单
      PopupMenuButton<FavoriteSortMode>(
        tooltip: context.tr.sortBy,
        icon: Icon(Icons.sort, color: textPrimary),
        onSelected: _onSortChanged,
        itemBuilder: (ctx) => [
          _buildSortMenuItem(
            FavoriteSortMode.createdDesc,
            context.tr.sortCreatedDesc,
          ),
          _buildSortMenuItem(FavoriteSortMode.wordAsc, context.tr.sortWordAsc),
          _buildSortMenuItem(
            FavoriteSortMode.lastStudiedDesc,
            context.tr.sortLastStudiedDesc,
          ),
        ],
      ),
      // 批量模式入口
      IconButton(
        tooltip: context.tr.batchMode,
        icon: Icon(Icons.checklist, color: textPrimary),
        onPressed: _words.isEmpty ? null : _enterBatchMode,
      ),
      // 学习入口
      IconButton(
        icon: Icon(Icons.play_circle_outline, color: textPrimary),
        onPressed: _words.isEmpty ? null : _startStudy,
      ),
    ];
  }

  PopupMenuItem<FavoriteSortMode> _buildSortMenuItem(
    FavoriteSortMode mode,
    String label,
  ) {
    final selected = _sortMode == mode;
    return PopupMenuItem<FavoriteSortMode>(
      value: mode,
      child: Row(
        children: [
          if (selected)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  List<Widget> _buildBatchActions() {
    final allSelected =
        _selectedIds.length == _words.length && _words.isNotEmpty;
    return [
      IconButton(
        tooltip: allSelected ? context.tr.deselectAll : context.tr.selectAll,
        icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
        onPressed: _selectAll,
      ),
      IconButton(
        tooltip: context.tr.moveToGroup,
        icon: const Icon(Icons.drive_file_move),
        onPressed: _selectedIds.isEmpty ? null : _batchMove,
      ),
      IconButton(
        tooltip: context.tr.removeSelected,
        icon: Icon(Icons.delete_outline, color: FluidTheme.error),
        onPressed: _selectedIds.isEmpty ? null : _batchRemove,
      ),
    ];
  }

  // === UI：列表项 ===
  Widget _buildListItem(
    Word word,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color textTertiary,
  ) {
    final wordId = word.id;
    final fav = wordId != null ? _favoriteMeta[wordId] : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onLongPress: _batchMode ? null : () => _showItemActions(word),
        child: FluidCard(
          enableShimmer: false,
          padding: const EdgeInsets.all(14),
          onTap: () {
            if (_batchMode && wordId != null) {
              _toggleSelect(wordId);
            } else {
              Navigator.of(context)
                  .push(
                    PageTransitions.slideFromRight(
                      page: WordDetailScreen(word: word),
                    ),
                  )
                  .then((_) => _load());
            }
          },
          child: Row(
            children: [
              if (_batchMode && wordId != null)
                Checkbox(
                  value: _selectedIds.contains(wordId),
                  onChanged: (_) => _toggleSelect(wordId),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.word,
                      style: FluidTheme.labelLarge(
                        isDark,
                      ).copyWith(color: textPrimary),
                    ),
                    if (word.definition.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        word.definition,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FluidTheme.bodySmall(
                          isDark,
                        ).copyWith(color: textSecondary),
                      ),
                    ],
                    if (fav != null &&
                        (fav.groupName.isNotEmpty || fav.note != null)) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (fav.groupName.isNotEmpty) ...[
                            Icon(
                              Icons.folder_outlined,
                              size: 12,
                              color: textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              fav.groupName,
                              style: FluidTheme.bodySmall(
                                isDark,
                              ).copyWith(color: textTertiary, fontSize: 12),
                            ),
                          ],
                          if (fav.groupName.isNotEmpty && fav.note != null)
                            Text(
                              ' · ',
                              style: FluidTheme.bodySmall(
                                isDark,
                              ).copyWith(color: textTertiary, fontSize: 12),
                            ),
                          if (fav.note != null)
                            Flexible(
                              child: Text(
                                fav.note!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: FluidTheme.bodySmall(
                                  isDark,
                                ).copyWith(color: textTertiary, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      _formatLastStudied(fav),
                      style: FluidTheme.bodySmall(
                        isDark,
                      ).copyWith(color: textTertiary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (!_batchMode)
                IconButton(
                  icon: Icon(Icons.bookmark_remove, color: FluidTheme.error),
                  onPressed: () => _remove(word),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final textTertiary = FluidTheme.getTextTertiaryColor(isDark);

    return FluidPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(isDark, textPrimary),
        //筛选Chip在刷新时保留，避免旧请求返回前无法切换最新筛选
        body: Column(
          children: [
            if (_groups.isNotEmpty)
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ChoiceChip(
                      label: Text(
                        context.tr.allGroupsWithCount(
                          _groups.fold<int>(0, (sum, g) => sum + g.value),
                        ),
                      ),
                      selected: _selectedGroup == null,
                      onSelected: (_) {
                        setState(() => _selectedGroup = null);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                    ..._groups.map(
                      (group) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${group.key} (${group.value})'),
                          selected: _selectedGroup == group.key,
                          onSelected: (_) {
                            setState(() => _selectedGroup = group.key);
                            _load();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: FluidTheme.primaryFluidGradient[0],
                      ),
                    )
                  : _words.isEmpty
                  ? Center(
                      child: Text(
                        context.tr.noFavoritesYet,
                        style: FluidTheme.bodyMedium(
                          isDark,
                        ).copyWith(color: textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _words.length,
                      itemBuilder: (context, index) => _buildListItem(
                        _words[index],
                        isDark,
                        textPrimary,
                        textSecondary,
                        textTertiary,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FluidButton(
                text: context.tr.startFavoritesSpecialStudy,
                icon: Icons.play_arrow,
                expanded: true,
                isEnabled: !_isLoading && _words.isNotEmpty,
                onPressed: _isLoading || _words.isEmpty ? null : _startStudy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表项操作菜单
enum _ItemAction { edit, move, remove }

/// 分组选择器弹层（带新建分组输入）
class _GroupPickerSheet extends StatefulWidget {
  final List<String> existingGroups;

  const _GroupPickerSheet({super.key, required this.existingGroups});

  @override
  State<_GroupPickerSheet> createState() => _GroupPickerSheetState();
}

class _GroupPickerSheetState extends State<_GroupPickerSheet> {
  final TextEditingController _newGroupController = TextEditingController();
  String? _pendingNew;

  @override
  void dispose() {
    _newGroupController.dispose();
    super.dispose();
  }

  void _confirm() {
    final group = _pendingNew?.trim().isNotEmpty == true
        ? _pendingNew!.trim()
        : null;
    Navigator.of(context).pop(group);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr.newGroupNameHint,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newGroupController,
          onChanged: (v) => setState(() => _pendingNew = v.trim()),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (widget.existingGroups.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            context.tr.groupHint,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.existingGroups
                .map(
                  (name) => ChoiceChip(
                    label: Text(name),
                    selected: _pendingNew == null || _pendingNew!.isEmpty,
                    onSelected: (_) {
                      setState(() {
                        _newGroupController.clear();
                        _pendingNew = '';
                      });
                      Navigator.of(context).pop(name);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
