import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/providers/providers.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/page_transitions.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_card.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final repo = DIContainer.instance.customWordSetRepository;
    final sets = await repo.getAllSets();
    final ids = sets.map((set) => set.id).whereType<int>().toList();
    final counts = await repo.getWordCounts(ids);
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _counts = counts;
      _isLoading = false;
    });
  }

  Future<void> _createSet() async {
    final name = await _showNameDialog(title: '创建单词集', confirmText: '创建');
    if (name == null || name.trim().isEmpty) return;
    await DIContainer.instance.customWordSetRepository.createSet(
      name: name.trim(),
    );
    await _load();
  }

  Future<String?> _showNameDialog({
    required String title,
    required String confirmText,
    String initialValue = '',
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入名称'),
          onSubmitted: (_) => Navigator.pop(ctx, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Future<void> _renameSet(CustomWordSet set) async {
    final name = await _showNameDialog(
      title: '重命名单词集',
      confirmText: '保存',
      initialValue: set.name,
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == set.name) return;
    await DIContainer.instance.customWordSetRepository.renameSet(set, trimmed);
    await _load();
  }

  Future<void> _deleteSet(CustomWordSet set) async {
    final setId = set.id;
    if (setId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除单词集'),
        content: Text('确定删除“${set.name}”吗？词集内的单词条目也会被移除，但不会删除词库中的原始单词。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DIContainer.instance.customWordSetRepository.deleteSet(setId);
    await _load();
  }

  void _showSetActions(CustomWordSet set) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(ctx);
                _renameSet(set);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: FluidTheme.error),
              title: Text('删除', style: TextStyle(color: FluidTheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteSet(set);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return FluidBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textPrimary),
          title: Text(
            '自定义单词集',
            style: FluidTheme.headingMedium(
              isDark,
            ).copyWith(color: textPrimary),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.add, color: textPrimary),
              onPressed: _createSet,
            ),
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
                  '还没有自定义单词集',
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
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$count 个单词',
                                  style: FluidTheme.bodySmall(
                                    isDark,
                                  ).copyWith(color: textSecondary),
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
        floatingActionButton: FloatingActionButton(
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
    final words = await DIContainer.instance.customWordSetRepository
        .getWordsInSet(setId);
    if (!mounted) return;
    setState(() {
      _words = words;
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
      ErrorHandler.showError(context, '当前词集没有可学习单词');
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
    final count = _selectedWordIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量移除单词'),
        content: Text('确定从词集中移除选中的 $count 个单词吗？原始词库中的单词不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移除'),
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

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return FluidBackground(
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
            _isSelecting ? '已选 ${_selectedWordIds.length} 个' : widget.set.name,
            style: FluidTheme.headingMedium(
              isDark,
            ).copyWith(color: textPrimary),
          ),
          actions: [
            if (_isSelecting) ...[
              IconButton(
                tooltip: '全选/取消全选',
                icon: Icon(Icons.select_all, color: textPrimary),
                onPressed: _words.isEmpty ? null : _toggleSelectAll,
              ),
              IconButton(
                tooltip: '批量移除',
                icon: Icon(Icons.delete_outline, color: FluidTheme.error),
                onPressed: _selectedWordIds.isEmpty
                    ? null
                    : _removeSelectedWords,
              ),
            ] else ...[
              IconButton(
                tooltip: '选择',
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
                  Expanded(
                    child: _words.isEmpty
                        ? Center(
                            child: Text(
                              '词集中还没有单词，可从单词详情页加入',
                              style: FluidTheme.bodyMedium(
                                isDark,
                              ).copyWith(color: textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                                      ? '取消全选'
                                      : '全选',
                                  icon: Icons.select_all,
                                  onPressed: _toggleSelectAll,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FluidButton(
                                  text: '移除选中',
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
                            text: '开始词集专项学习',
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
}
