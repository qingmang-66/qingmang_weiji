import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/providers/providers.dart';
import '../services/asset_wordbook_service.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import '../utils/page_transitions.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/fluid_loading.dart';
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

  // 多选模式状态
  bool _isMultiSelectMode = false;
  Set<int> _selectedBookIds = {};

  // 批量导入模式状态
  bool _isBatchImportMode = false;
  final Set<String> _selectedBuiltInBooks = {};

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WordBookProvider>();

    return FluidBackground(
      child: SafeArea(
        child: Column(
          children: [
            // 顶部标题栏
            _buildAppBar(provider),

            // 导入进度条
            if (_isImporting) _buildImportProgress(),

            // 多选模式底部操作栏
            if (_isMultiSelectMode) _buildBatchDeleteBar(),

            // 词库列表
            Expanded(child: _buildWordBookList(provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(WordBookProvider provider) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
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
          Text(
            _isMultiSelectMode
                ? '${context.tr.selectedCount} ${_selectedBookIds.length}${context.tr.wordBooksCount}'
                : context.tr.wordBooksTitle,
            style: FluidTheme.headingMedium.copyWith(color: textPrimary),
          ),
          const Spacer(),
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
                        .map((b) => b.id!)
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
              icon: Icon(Icons.download, color: iconColor),
              onPressed: _showBuiltInBooksDialog,
              tooltip: context.tr.builtInBooks,
            ),
            IconButton(
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: FluidCard(
        enableShimmer: false,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _importTotal > 0 ? _importProgress / _importTotal : 0,
              backgroundColor: FluidTheme.getBorderColor(isDark),
              valueColor: AlwaysStoppedAnimation<Color>(
                FluidTheme.primaryFluidGradient[0],
              ),
              borderRadius: BorderRadius.circular(4),
              minHeight: 4,
            ),
            const SizedBox(height: 8),
            Text(
              '${context.tr.importing} ($_importProgress/$_importTotal)',
              style: FluidTheme.bodyMedium.copyWith(
                color: FluidTheme.getTextSecondaryColor(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchDeleteBar() {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FluidTheme.getElevatedSurfaceColor(isDark),
        border: Border(
          top: BorderSide(color: FluidTheme.getBorderColor(isDark)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: FluidButton(
                text: _selectedBookIds.isEmpty
                    ? context.tr.pleaseSelect
                    : '${context.tr.deleteCount} ${_selectedBookIds.length}${context.tr.wordBooksCount}',
                icon: Icons.delete_outline,
                fontSize: 14,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                isEnabled: _selectedBookIds.isNotEmpty,
                onPressed: _selectedBookIds.isEmpty
                    ? null
                    : _confirmBatchDelete,
                colors: FluidTheme.errorFluidGradient,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _exitMultiSelectMode,
              child: Text(
                context.tr.cancel,
                style: TextStyle(color: textSecondary),
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

    return RefreshIndicator(
      onRefresh: () => provider.loadWordBooks(),
      color: FluidTheme.primaryFluidGradient[0],
      child: _isMultiSelectMode
          ? ListView.builder(
              padding: EdgeInsets.only(top: 8, bottom: 100.0),
              itemCount: provider.wordBooks.length,
              itemBuilder: (context, index) {
                final book = provider.wordBooks[index];
                if (book.id == null) return const SizedBox.shrink();
                final isSelected = provider.currentBook?.id == book.id;
                final isChecked = _selectedBookIds.contains(book.id);
                return _WordBookCard(
                  index: index,
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
                  onLongPress: () {
                    setState(() {
                      _isMultiSelectMode = true;
                      _selectedBookIds = {book.id!};
                    });
                  },
                  onBrowse: () => _browseWords(book),
                  onDelete: () => _confirmDelete(book),
                );
              },
            )
          : ReorderableListView.builder(
              buildDefaultDragHandles: false, // 隐藏默认左侧拖拽手柄，使用右侧自定义手柄
              padding: EdgeInsets.only(top: 8, bottom: 80.0),
              itemCount: provider.wordBooks.length,
              onReorder: (oldIndex, newIndex) {
                provider.reorderWordBooks(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final book = provider.wordBooks[index];
                if (book.id == null) return const SizedBox.shrink();
                final isSelected = provider.currentBook?.id == book.id;
                final isChecked = _selectedBookIds.contains(book.id);
                return _WordBookCard(
                  key: ValueKey(book.id),
                  index: index,
                  book: book,
                  isSelected: isSelected,
                  isChecked: isChecked,
                  isMultiSelectMode: _isMultiSelectMode,
                  onTap: () {
                    provider.selectWordBook(book);
                  },
                  onLongPress: () {
                    setState(() {
                      _isMultiSelectMode = true;
                      _selectedBookIds = {book.id!};
                    });
                  },
                  onBrowse: () => _browseWords(book),
                  onDelete: () => _confirmDelete(book),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

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
              style: FluidTheme.headingMedium.copyWith(
                color: FluidTheme.getTextPrimaryColor(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr.noWordBooksDesc,
              style: FluidTheme.bodyMedium.copyWith(
                color: FluidTheme.getTextSecondaryColor(isDark),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FluidButton(
                  text: context.tr.addBuiltIn,
                  icon: Icons.download,
                  onPressed: _showBuiltInBooksDialog,
                ),
                const SizedBox(width: 12),
                FluidButton(
                  text: context.tr.createWordBook,
                  icon: Icons.add,
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
        style: FluidTheme.bodyMedium.copyWith(color: textPrimary),
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
    await context.read<WordBookProvider>().deleteWordBooksBatch(ids);
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

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final borderColor = FluidTheme.getBorderColor(isDark);
    final inputFillColor = isDark
        ? const Color(0xFFEDEDF7).withValues(alpha: 0.96)
        : FluidTheme.getInputFillColor(isDark);
    final inputTextColor = const Color(0xFF1A1A2E);

    showFluidDialog(
      context: context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            style: TextStyle(color: inputTextColor),
            cursorColor: FluidTheme.primaryFluidGradient[0],
            decoration: InputDecoration(
              filled: true,
              fillColor: inputFillColor,
              labelText: context.tr.bookNameLabel,
              hintText: context.tr.bookNameExample,
              labelStyle: TextStyle(
                color: inputTextColor.withValues(alpha: 0.72),
              ),
              hintStyle: TextStyle(
                color: inputTextColor.withValues(alpha: 0.45),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: FluidTheme.primaryFluidGradient[0],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descController,
            style: TextStyle(color: inputTextColor),
            cursorColor: FluidTheme.primaryFluidGradient[0],
            decoration: InputDecoration(
              filled: true,
              fillColor: inputFillColor,
              labelText: context.tr.descriptionLabel,
              labelStyle: TextStyle(
                color: inputTextColor.withValues(alpha: 0.72),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: FluidTheme.primaryFluidGradient[0],
                ),
              ),
            ),
            maxLines: 2,
          ),
        ],
      ),
      title: context.tr.createWordBook,
      actions: [
        FluidTextButton(
          text: context.tr.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        FluidButton(
          text: context.tr.create,
          onPressed: () {
            if (nameController.text.trim().isNotEmpty) {
              context.read<WordBookProvider>().createWordBook(
                nameController.text.trim(),
                descController.text.trim(),
              );
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }

  void _browseWords(WordBook book) async {
    final words = await context
        .read<DIContainer>()
        .wordRepository
        .getWordsByBook(book.id!);
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

  void _confirmDelete(WordBook book) {
    showFluidDialog(
      context: context,
      content: Text(
        '${context.tr.confirmDeleteBook} "${book.name}"?',
        style: FluidTheme.bodyMedium,
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
            context.read<WordBookProvider>().deleteWordBook(book.id!);
            Navigator.pop(context);
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: FluidTheme.getDialogSurfaceColor(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: FluidTheme.getBorderColor(isDark)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: FluidTheme.getMutedOverlayColor(isDark),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.file_upload,
                      color: FluidTheme.primaryFluidGradient[0],
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isBatchImportMode
                          ? '${context.tr.selectedCount} ${_selectedBuiltInBooks.length}${context.tr.wordBooksCount}'
                          : context.tr.builtInBooks,
                      style: FluidTheme.headingSmall.copyWith(
                        color: textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (_isBatchImportMode) ...[
                      FluidTextButton(
                        text: context.tr.cancel,
                        onPressed: () {
                          setModalState(() {
                            _isBatchImportMode = false;
                            _selectedBuiltInBooks.clear();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FluidButton(
                        text: context.tr.importSelected,
                        onPressed: () => _executeBatchImport(ctx),
                        colors: FluidTheme.successFluidGradient,
                      ),
                    ] else ...[
                      FluidButton(
                        text: context.tr.selectAll,
                        onPressed: () {
                          setModalState(() {
                            _isBatchImportMode = true;
                            final provider = context.read<WordBookProvider>();
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
                        text: context.tr.close,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    _selectedBuiltInBooks.isNotEmpty ? 20 : 16,
                  ),
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return _buildBuiltInBookItemForBatchImport(
                      ctx,
                      book['name']!,
                      book['description']!,
                      book['wordCount'] as int,
                      book['words'] as List<Map<String, String>>,
                      setModalState,
                    );
                  },
                ),
              ),
              if (_selectedBuiltInBooks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: FluidTheme.getElevatedSurfaceColor(isDark),
                    border: Border(
                      top: BorderSide(color: FluidTheme.getBorderColor(isDark)),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 8),
                    child: FluidButton(
                      text:
                          '${context.tr.importSelected} (${_selectedBuiltInBooks.length})',
                      icon: Icons.download,
                      expanded: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      onPressed: () => _executeBatchImport(ctx),
                      colors: FluidTheme.successFluidGradient,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuiltInBookItemForBatchImport(
    BuildContext ctx,
    String name,
    String desc,
    int count,
    List<Map<String, String>> words,
    StateSetter setModalState,
  ) {
    final isSelected = _selectedBuiltInBooks.contains(name);
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          setModalState(() {
            if (isSelected) {
              _selectedBuiltInBooks.remove(name);
            } else {
              _selectedBuiltInBooks.add(name);
            }
          });
        },
        child: FluidCard(
          enableShimmer: isSelected,
          enableBorderGradient: isSelected,
          borderColors: isSelected ? FluidTheme.primaryFluidGradient : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              FluidGradientContainer(
                colors: isSelected
                    ? FluidTheme.primaryFluidGradient
                    : FluidTheme.getSurfaceGradientColors(isDark),
                borderRadius: FluidTheme.smallBorderRadius,
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.library_books,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: FluidTheme.labelLarge.copyWith(color: textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count${context.tr.wordsSuffix}',
                      style: FluidTheme.bodyMedium.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: FluidTheme.primaryFluidGradient[0],
                  size: 22,
                ),
            ],
          ),
        ),
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

    try {
      final books = await AssetWordBookService.getAllBuiltInBooks();

      for (final bookName in selectedBooks) {
        final bookData = books.firstWhere((b) => b['name'] == bookName);
        await provider.importBuiltInBook(
          bookName,
          bookData['description']!,
          bookData['words'] as List<Map<String, String>>,
        );
        importedCount += 1;

        if (!mounted) return;
        setState(() => _importProgress = importedCount);
      }

      if (!mounted) return;
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
class _WordBookCard extends StatelessWidget {
  final int index;
  final WordBook book;
  final bool isSelected;
  final bool isChecked;
  final bool isMultiSelectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onBrowse;
  final VoidCallback onDelete;

  const _WordBookCard({
    super.key,
    required this.index,
    required this.book,
    required this.isSelected,
    required this.isChecked,
    required this.isMultiSelectMode,
    required this.onTap,
    required this.onLongPress,
    required this.onBrowse,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final iconColor = FluidTheme.getTextSecondaryColor(isDark);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: FluidCard(
          enableShimmer: isSelected,
          enableBorderGradient: isSelected,
          borderColors: isSelected ? FluidTheme.primaryFluidGradient : null,
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
              FluidGradientContainer(
                colors: isSelected
                    ? FluidTheme.primaryFluidGradient
                    : FluidTheme.getSurfaceGradientColors(isDark),
                borderRadius: FluidTheme.smallBorderRadius,
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.menu_book,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.name,
                      style: FluidTheme.labelLarge.copyWith(color: textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.description,
                      style: FluidTheme.bodySmall.copyWith(
                        color: textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 拖拽排序手柄（仅在非多选模式下显示）
                  if (!isMultiSelectMode) ...[
                    ReorderableDragStartListener(
                      index: index,
                      child: Icon(Icons.reorder, color: iconColor, size: 24),
                    ),
                  ],
                  IconButton(
                    icon: Icon(Icons.visibility, color: iconColor, size: 20),
                    onPressed: onBrowse,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: FluidTheme.error,
                      size: 20,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单词列表底部弹窗 - 流体渐变风格
class _WordListSheet extends StatelessWidget {
  final WordBook book;
  final List<Word> words;
  final VoidCallback onRefresh;

  const _WordListSheet({
    required this.book,
    required this.words,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: FluidTheme.getDialogSurfaceColor(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: FluidTheme.getBorderColor(isDark)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: FluidTheme.getMutedOverlayColor(isDark),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                FluidGradientContainer(
                  colors: FluidTheme.primaryFluidGradient,
                  borderRadius: FluidTheme.smallBorderRadius,
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.menu_book,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.name,
                        style: FluidTheme.headingSmall.copyWith(
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '${words.length}${context.tr.wordList}',
                        style: FluidTheme.bodySmall.copyWith(
                          color: textSecondary,
                        ),
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
          ),
          // 添加单词按钮
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
                      targetBookId: book.id!,
                      onAdded: onRefresh,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: words.length,
              itemBuilder: (context, index) {
                final word = words[index];
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
                          style: FluidTheme.labelLarge.copyWith(
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          word.definition,
                          style: FluidTheme.bodySmall.copyWith(
                            color: textSecondary,
                          ),
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
  final Set<String> _selectedWords = {};
  bool _isLoading = true;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _loadBuiltInBooks();
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

  void _loadWords(int index) {
    setState(() {
      _isLoading = true;
      _selectedBookIndex = index;
      _words = [];
      _selectedWords.clear();
    });

    if (index >= 0 && index < _builtInBooks.length) {
      final book = _builtInBooks[index];
      final wordList = (book['words'] as List<dynamic>?) ?? [];
      setState(() {
        _words = wordList.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    }
  }

  Future<void> _addSelectedWords() async {
    if (_selectedWords.isEmpty) return;

    setState(() => _isAdding = true);

    final wordRepository = context.read<DIContainer>().wordRepository;
    int added = 0;

    for (final wordData in _words) {
      final wordText = wordData['word'] as String? ?? '';
      if (!_selectedWords.contains(wordText)) continue;

      final word = Word(
        word: wordText,
        phonetic: wordData['phonetic'] as String? ?? '',
        definition: wordData['definition'] as String? ?? '',
        example: wordData['example'] as String?,
        exampleTranslation: wordData['exampleTranslation'] as String?,
        wordBookId: widget.targetBookId,
      );

      try {
        await wordRepository.insertWord(word);
        added++;
      } catch (e) {
        debugPrint('添加单词失败: $wordText, 错误: $e');
      }
    }

    if (mounted) {
      setState(() => _isAdding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.tr.added} $added ${context.tr.wordsCountSuffix}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onAdded();
      Navigator.pop(context);
    }
  }

  List<Map<String, dynamic>> get _filteredWords {
    if (_searchQuery.isEmpty) return _words;
    return _words.where((w) {
      final word = (w['word'] as String? ?? '').toLowerCase();
      final def = (w['definition'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return word.contains(query) || def.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Scaffold(
      backgroundColor: FluidTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        title: Text(
          context.tr.addFromBuiltIn,
          style: FluidTheme.headingSmall.copyWith(color: textPrimary),
        ),
        actions: [
          if (_selectedWords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_selectedWords.length} ${context.tr.selected}',
                  style: FluidTheme.labelLarge.copyWith(
                    color: FluidTheme.primaryFluidGradient[0],
                  ),
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
                  return ChoiceChip(
                    label: Text(book['name'] as String? ?? ''),
                    selected: isSelected,
                    onSelected: (_) => _loadWords(index),
                    selectedColor: FluidTheme.primaryFluidGradient[0],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : textPrimary,
                    ),
                  );
                },
              ),
            ),

          // 搜索框
          if (_selectedBookIndex != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: context.tr.searchWordHint,
                  hintStyle: TextStyle(color: textSecondary),
                  prefixIcon: Icon(Icons.search, color: textSecondary),
                  filled: true,
                  fillColor: FluidTheme.getSurfaceColor(isDark),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
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
                      style: FluidTheme.bodyLarge.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredWords.length,
                    itemBuilder: (context, index) {
                      final wordData = _filteredWords[index];
                      final wordText = wordData['word'] as String? ?? '';
                      final isSelected = _selectedWords.contains(wordText);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: FluidCard(
                          enableShimmer: false,
                          padding: const EdgeInsets.all(12),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedWords.remove(wordText);
                              } else {
                                _selectedWords.add(wordText);
                              }
                            });
                          },
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: isSelected
                                    ? FluidTheme.primaryFluidGradient[0]
                                    : textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      wordText,
                                      style: FluidTheme.labelLarge.copyWith(
                                        color: textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      wordData['definition'] as String? ?? '',
                                      style: FluidTheme.bodySmall.copyWith(
                                        color: textSecondary,
                                      ),
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
