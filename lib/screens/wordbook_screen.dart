import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/providers/providers.dart';
import '../services/import_service.dart';
import '../services/asset_wordbook_service.dart';
import 'word_detail_screen.dart';

/// iOS 风格颜色常量
class _IOSColors {
  static const Color systemGreen = Color(0xFF34C759);
  static const Color systemRed = Color(0xFFFF3B30);
  static const Color systemBlue = Color(0xFF007AFF);
  static const Color systemPurple = Color(0xFFAF52DE);
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemGray2 = Color(0xFFAEAEB2);
  static const Color systemGray5 = Color(0xFFF2F2F7);
  static const Color systemGray6 = Color(0xFFF8F8FA);
}

/// 词库管理页 - 按图2风格重构
class WordBookScreen extends StatefulWidget {
  const WordBookScreen({super.key});

  @override
  State<WordBookScreen> createState() => _WordBookScreenState();
}

class _WordBookScreenState extends State<WordBookScreen> {
  bool _isImporting = false;
  int _importProgress = 0;
  int _importTotal = 0;

  // 多选模式状态
  bool _isMultiSelectMode = false;
  Set<int> _selectedBookIds = {};

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WordBookProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _isMultiSelectMode
            ? Text('已选择 ${_selectedBookIds.length} 个词库')
            : const Text('词库'),
        leading: _isMultiSelectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitMultiSelectMode,
              )
            : null,
        actions: [
          if (_isMultiSelectMode)
            IconButton(
              icon: Icon(
                _selectedBookIds.length == provider.wordBooks.length
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
              ),
              onPressed: () {
                if (_selectedBookIds.length == provider.wordBooks.length) {
                  setState(() => _selectedBookIds.clear());
                } else {
                  setState(() {
                    _selectedBookIds = provider.wordBooks.map((b) => b.id!).toSet();
                  });
                }
              },
            ),
          if (!_isMultiSelectMode)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _showBuiltInBooksDialog,
              tooltip: '内置词库',
            ),
          if (!_isMultiSelectMode)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateDialog,
              tooltip: '创建词库',
            ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_isImporting)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _importTotal > 0 ? _importProgress / _importTotal : 0,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 6,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '正在导入... ($_importProgress/$_importTotal)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                // 多选模式底部操作栏
                if (_isMultiSelectMode && _selectedBookIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _confirmBatchDelete,
                          icon: const Icon(Icons.delete_outline, size: 22),
                          label: const Text(
                            '删除所选词库',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _IOSColors.systemRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: provider.wordBooks.isEmpty
                      ? _buildEmptyState(colorScheme)
                      : ListView.builder(
                          padding: EdgeInsets.only(top: 8, bottom: _isMultiSelectMode ? 100.0 : 80.0),
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
                                if (_isMultiSelectMode) {
                                  setState(() {
                                    if (isChecked) {
                                      _selectedBookIds.remove(book.id);
                                    } else {
                                      _selectedBookIds.add(book.id!);
                                    }
                                  });
                                } else {
                                  provider.selectWordBook(book);
                                }
                              },
                              onLongPress: () {
                                setState(() {
                                  _isMultiSelectMode = true;
                                  _selectedBookIds = {book.id!};
                                });
                              },
                              onBrowse: () => _browseWords(book),
                              onImport: () => _importToBook(book),
                              onDelete: () => _confirmDelete(book),
                            );
                          },
                        ),
                ),
              ],
            ),
      // 非多选模式下显示浮动操作按钮
      floatingActionButton: !_isMultiSelectMode
          ? FloatingActionButton.extended(
              onPressed: () {
                setState(() => _isMultiSelectMode = true);
              },
              icon: const Icon(Icons.checklist),
              label: const Text('批量管理'),
              backgroundColor: _IOSColors.systemBlue,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedBookIds.clear();
    });
  }

  void _confirmBatchDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedBookIds.length} 个词库吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeBatchDelete();
            },
            style: TextButton.styleFrom(foregroundColor: _IOSColors.systemRed),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeBatchDelete() async {
    final ids = _selectedBookIds.toList();
    _exitMultiSelectMode();
    await context.read<WordBookProvider>().deleteWordBooksBatch(ids);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除 ${ids.length} 个词库，内置词库已重新导入'),
          backgroundColor: _IOSColors.systemGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text('还没有词库', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _showBuiltInBooksDialog,
                icon: const Icon(Icons.download),
                label: const Text('添加内置词库'),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: _showCreateDialog,
                child: const Text('创建词库'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建词库'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '词库名称',
                hintText: '例如：GRE核心词',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: '描述（可选）'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                context.read<WordBookProvider>().createWordBook(
                      nameController.text.trim(),
                      descController.text.trim(),
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _browseWords(WordBook book) async {
    final words =
        await context.read<DIContainer>().wordRepository.getWordsByBook(book.id!);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WordListSheet(
        book: book,
        words: words,
        onRefresh: () {
          context.read<WordBookProvider>().loadWordBooks();
        },
      ),
    );
  }

  Future<void> _importToBook(WordBook book) async {
    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = 0;
    });

    final result = await ImportService.importFromFile(book.id!,
        onProgress: (completed, total) {
      if (mounted) {
        setState(() {
          _importProgress = completed;
          _importTotal = total;
        });
      }
    });

    if (mounted) {
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      if (result.success) context.read<WordBookProvider>().loadWordBooks();
    }
  }

  void _confirmDelete(WordBook book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除词库"${book.name}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              context.read<WordBookProvider>().deleteWordBook(book.id!);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: _IOSColors.systemRed),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBuiltInBooksDialog() async {
    final books = await AssetWordBookService.getAllBuiltInBooks();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.library_books, color: _IOSColors.systemBlue, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    '内置词库',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  return _buildBuiltInBookItem(
                    ctx,
                    book['name']!,
                    book['description']!,
                    book['wordCount'] as int,
                    book['words'] as List<Map<String, String>>,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuiltInBookItem(
    BuildContext ctx,
    String name,
    String desc,
    int count,
    List<Map<String, String>> words,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _IOSColors.systemGray6,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_IOSColors.systemBlue, _IOSColors.systemPurple],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.library_books, color: Colors.white, size: 24),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$desc · $count 词',
            style: TextStyle(color: _IOSColors.systemGray, fontSize: 13),
          ),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_IOSColors.systemBlue, _IOSColors.systemPurple],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _importBuiltInBook(ctx, name, desc, words),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Text(
                  '添加',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _importBuiltInBook(
    BuildContext ctx,
    String name,
    String desc,
    List<Map<String, String>> words,
  ) async {
    // 检查词库是否已存在
    final provider = context.read<WordBookProvider>();
    if (provider.isBookNameExists(name)) {
      Navigator.pop(ctx);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('词库"$name"已存在，请勿重复导入'),
          backgroundColor: _IOSColors.systemRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    Navigator.pop(ctx);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在导入 $name...'),
        duration: const Duration(seconds: 1),
        backgroundColor: _IOSColors.systemBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    try {
      // 创建词库（不刷新列表，标记为内置词库）
      final bookId = await provider.createWordBookSilent(name, desc, isBuiltIn: true);

      // 导入单词
      final result = await ImportService.importFromBuiltIn(bookId, words);

      // 更新词库总词数
      await DIContainer.instance.wordBookRepository.updateWordBookTotalWords(bookId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: _IOSColors.systemGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      // 导入完成后刷新词库列表
      provider.loadWordBooks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入失败: $e'),
          backgroundColor: _IOSColors.systemRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

/// 词库卡片 - 按图2风格：渐变图标 + 简洁列表 + 添加按钮
class _WordBookCard extends StatelessWidget {
  final WordBook book;
  final bool isSelected;
  final bool isChecked;
  final bool isMultiSelectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onBrowse;
  final VoidCallback onImport;
  final VoidCallback? onDelete;

  const _WordBookCard({
    required this.book,
    required this.isSelected,
    required this.isChecked,
    required this.isMultiSelectMode,
    required this.onTap,
    required this.onLongPress,
    required this.onBrowse,
    required this.onImport,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _IOSColors.systemGray6 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isMultiSelectMode && isChecked
              ? Border.all(color: _IOSColors.systemBlue, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 多选模式下的复选框
                  if (isMultiSelectMode) ...[
                    Icon(
                      isChecked
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isChecked
                          ? _IOSColors.systemBlue
                          : _IOSColors.systemGray2,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                  ],
                  // 左侧渐变图标
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_IOSColors.systemBlue, _IOSColors.systemPurple],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.menu_book, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  // 中间文字信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.description,
                          style: TextStyle(
                            color: _IOSColors.systemGray,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _IOSColors.systemGray5,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${book.totalWords} 词',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _IOSColors.systemGray,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 右侧操作按钮
                  if (!isMultiSelectMode) ...[
                    TextButton.icon(
                      onPressed: onBrowse,
                      icon: const Icon(Icons.list_alt, size: 16),
                      label: const Text('浏览'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: _IOSColors.systemBlue,
                      ),
                    ),
                    if (!book.isBuiltIn)
                      TextButton.icon(
                        onPressed: onImport,
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('导入'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: _IOSColors.systemGreen,
                        ),
                      ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('删除'),
                        style: TextButton.styleFrom(
                          foregroundColor: _IOSColors.systemRed,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 单词列表底部弹出页 - iOS 风格（含批量删除和批量导入）
class _WordListSheet extends StatefulWidget {
  final WordBook book;
  final List<Word> words;
  final VoidCallback onRefresh;

  const _WordListSheet({
    required this.book,
    required this.words,
    required this.onRefresh,
  });

  @override
  State<_WordListSheet> createState() => _WordListSheetState();
}

class _WordListSheetState extends State<_WordListSheet> {
  bool _isMultiSelectMode = false;
  Set<int> _selectedWordIds = {};
  late List<Word> _words;

  @override
  void initState() {
    super.initState();
    _words = List.from(widget.words);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_isMultiSelectMode)
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed: _exitMultiSelectMode,
                  ),
                Expanded(
                  child: Text(
                    _isMultiSelectMode
                        ? '已选择 ${_selectedWordIds.length} 个单词'
                        : '${widget.book.name} (${_words.length}词)',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!_isMultiSelectMode) ...[
                  IconButton(
                    icon: const Icon(Icons.file_upload_outlined, size: 22),
                    onPressed: _showBatchImportDialog,
                    tooltip: '批量导入',
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 22),
                    onPressed: () => _showAddWordDialog(context, widget.book.id!),
                  ),
                  IconButton(
                    icon: const Icon(Icons.checklist, size: 22),
                    onPressed: () {
                      setState(() => _isMultiSelectMode = true);
                    },
                    tooltip: '批量管理',
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          if (_isMultiSelectMode && _selectedWordIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _confirmBatchDeleteWords,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text(
                          '删除所选',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _IOSColors.systemRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: _words.isEmpty
                ? const Center(child: Text('暂无词汇'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _words.length,
                    itemBuilder: (ctx, i) {
                      final w = _words[i];
                      final isChecked = _selectedWordIds.contains(w.id);
                      return GestureDetector(
                        onLongPress: () {
                          if (w.id != null) {
                            setState(() {
                              _isMultiSelectMode = true;
                              _selectedWordIds = {w.id!};
                            });
                          }
                        },
                        child: ListTile(
                          leading: _isMultiSelectMode
                              ? Icon(
                                  isChecked
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isChecked
                                      ? _IOSColors.systemBlue
                                      : _IOSColors.systemGray2,
                                )
                              : null,
                          title: Text(
                            w.word,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: w.phonetic.isNotEmpty
                              ? Text(w.phonetic)
                              : null,
                          trailing: SizedBox(
                            width: 160,
                            child: Text(
                              w.definition,
                              style: Theme.of(ctx).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.end,
                            ),
                          ),
                          onTap: () {
                            if (_isMultiSelectMode) {
                              if (w.id != null) {
                                setState(() {
                                  if (isChecked) {
                                    _selectedWordIds.remove(w.id);
                                  } else {
                                    _selectedWordIds.add(w.id!);
                                  }
                                });
                              }
                            } else {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WordDetailScreen(word: w),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedWordIds.clear();
    });
  }

  void _confirmBatchDeleteWords() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
            '确定要删除选中的 ${_selectedWordIds.length} 个单词吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeBatchDeleteWords();
            },
            style: TextButton.styleFrom(foregroundColor: _IOSColors.systemRed),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeBatchDeleteWords() async {
    final ids = _selectedWordIds.toList();
    _exitMultiSelectMode();
    await context.read<WordBookProvider>().deleteWordsBatch(ids);
    setState(() {
      _words.removeWhere((w) => ids.contains(w.id));
    });
    widget.onRefresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除 ${ids.length} 个单词'),
          backgroundColor: _IOSColors.systemGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showBatchImportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.file_upload_outlined, color: _IOSColors.systemBlue),
            const SizedBox(width: 8),
            const Text('批量导入单词'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '每行输入一个单词，支持从剪贴板粘贴',
              style: TextStyle(fontSize: 13, color: _IOSColors.systemGray),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: _IOSColors.systemGray6,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _IOSColors.systemGray2),
              ),
              child: TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'apple\nbanana\ncherry\n...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;

              final lines = text
                  .split('\n')
                  .map((l) => l.trim())
                  .where((l) => l.isNotEmpty)
                  .toList();

              if (lines.isEmpty) return;

              Navigator.pop(ctx);
              await _doBatchImport(lines);
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  Future<void> _doBatchImport(List<String> words) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在导入...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final wordList = words
          .map((w) => Word(word: w, wordBookId: widget.book.id!))
          .toList();

      await context
          .read<DIContainer>()
          .wordRepository
          .insertWordsBatchFast(wordList);

      if (!mounted) return;
      Navigator.pop(context);

      final messenger = ScaffoldMessenger.of(context);
      final newWords = await context
          .read<DIContainer>()
          .wordRepository
          .getWordsByBook(widget.book.id!);
      setState(() {
        _words = newWords;
      });
      widget.onRefresh();

      messenger.showSnackBar(
        SnackBar(
          content: Text('成功导入 ${words.length} 个单词'),
          backgroundColor: _IOSColors.systemGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入失败: $e'),
          backgroundColor: _IOSColors.systemRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showAddWordDialog(BuildContext ctx, int bookId) {
    final wordController = TextEditingController();
    final phoneticController = TextEditingController();
    final definitionController = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('添加单词'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: wordController,
                decoration: const InputDecoration(labelText: '单词'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneticController,
                decoration: const InputDecoration(labelText: '音标（可选）'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: definitionController,
                decoration: const InputDecoration(labelText: '释义'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final word = wordController.text.trim();
              final definition = definitionController.text.trim();
              if (word.isEmpty || definition.isEmpty) return;
              final dialogNavigator = Navigator.of(dialogCtx);
              await DIContainer.instance.wordRepository.insertWord(Word(
                    word: word,
                    phonetic: phoneticController.text.trim(),
                    definition: definition,
                    wordBookId: bookId,
                  ));
              dialogNavigator.pop();
              if (!mounted) return;
              final newWords = await DIContainer.instance.wordRepository.getWordsByBook(bookId);
              setState(() {
                _words = newWords;
              });
              widget.onRefresh();
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}