import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../services/asset_wordbook_service.dart';
import '../utils/translations.dart';
import 'word_detail_screen.dart';

/// 词库管理页
class WordBookScreen extends StatefulWidget {
  const WordBookScreen({super.key});

  @override
  State<WordBookScreen> createState() => _WordBookScreenState();
}

class _WordBookScreenState extends State<WordBookScreen> {
  bool _isImporting = false;
  int _importProgress = 0;
  int _importTotal = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.t('词库', 'Word Books')),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _showBuiltInBooksDialog,
            tooltip: Translations.t('内置词库', 'Built-in Word Books'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
            tooltip: Translations.t('创建词库', 'Create Word Book'),
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
                Expanded(
                  child: provider.wordBooks.isEmpty
                      ? _buildEmptyState(colorScheme)
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: provider.wordBooks.length,
                          itemBuilder: (context, index) {
                            final book = provider.wordBooks[index];
                            final isSelected = provider.currentBook?.id == book.id;
                            return _WordBookCard(
                              book: book,
                              isSelected: isSelected,
                              onTap: () => provider.selectWordBook(book),
                              onBrowse: () => _browseWords(book),
                              onImport: () => _importToBook(book),
                              onDelete: book.isBuiltIn ? null : () => _confirmDelete(book),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(Translations.t('还没有词库', 'No word books yet'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _showBuiltInBooksDialog, 
                icon: const Icon(Icons.download), 
                label: Text(Translations.t('添加内置词库', 'Add Built-in'))
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: _showCreateDialog, 
                child: Text(Translations.t('创建词库', 'Create'))
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
        title: Text(Translations.t('创建词库', 'Create Word Book')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController, 
              decoration: InputDecoration(
                labelText: Translations.t('词库名称', 'Book Name'), 
                hintText: Translations.t('例如：GRE核心词', 'e.g., GRE Core Words')
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController, 
              decoration: InputDecoration(labelText: Translations.t('描述（可选）', 'Description (Optional)')), 
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(Translations.t('取消', 'Cancel'))),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                context.read<AppProvider>().createWordBook(nameController.text.trim(), descController.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: Text(Translations.t('创建', 'Create')),
          ),
        ],
      ),
    );
  }

  Future<void> _showBuiltInBooksDialog() async {
    // 加载词库数据
    final books = await AssetWordBookService.getAllBuiltInBooks();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.library_books, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(Translations.t('内置词库', 'Built-in Word Books')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 450,
          child: ListView.builder(
            shrinkWrap: true,
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(Translations.t('关闭', 'Close'))),
        ],
      ),
    );
  }

  Widget _buildBuiltInBookItem(BuildContext ctx, String name, String desc, int count, List<Map<String, String>> words) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.secondaryContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.library_books, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$desc · $count 词'),
        trailing: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _importBuiltInBook(ctx, name, desc, words),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  Translations.t('添加', 'Add'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _importBuiltInBook(BuildContext ctx, String name, String desc, List<Map<String, String>> words) async {
    Navigator.pop(ctx);
    
    // 显示导入中
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Translations.t('正在导入 $name...', 'Importing $name...')), duration: const Duration(seconds: 1)),
    );

    try {
      // 创建词库
      final bookId = await context.read<AppProvider>().createWordBook(name, desc);
      
      // 导入单词
      final result = await ImportService.importFromBuiltIn(bookId, words);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      
      // 刷新
      context.read<AppProvider>().loadWordBooks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Translations.t('导入失败: $e', 'Import failed: $e'))),
      );
    }
  }

  void _browseWords(WordBook book) async {
    final words = await DatabaseService.getWordsByBook(book.id!);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text('${book.name} (${words.length}${Translations.t('词', 'words')})', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                  IconButton(onPressed: () => _showAddWordDialog(ctx, book.id!), icon: const Icon(Icons.add)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: words.isEmpty ? Center(child: Text(Translations.t('暂无词汇', 'No words yet'))) : ListView.builder(controller: scrollController, itemCount: words.length, itemBuilder: (ctx, i) {
              final w = words[i];
              return ListTile(
                title: Text(w.word, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: w.phonetic.isNotEmpty ? Text(w.phonetic) : null,
                trailing: SizedBox(width: 160, child: Text(w.definition, style: Theme.of(ctx).textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1, textAlign: TextAlign.end)),
                onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => WordDetailScreen(word: w))); },
              );
            })),
          ],
        ),
      ),
    );
  }

  Future<void> _importToBook(WordBook book) async {
    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = 0;
    });

    final result = await ImportService.importFromFile(book.id!, onProgress: (completed, total) {
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
        SnackBar(content: Text(result.message), behavior: SnackBarBehavior.floating),
      );
      if (result.success) context.read<AppProvider>().loadWordBooks();
    }
  }

  void _confirmDelete(WordBook book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.t('确认删除', 'Confirm Delete')),
        content: Text(Translations.t('确定要删除词库"${book.name}"吗？', 'Delete "${book.name}"?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(Translations.t('取消', 'Cancel'))),
          FilledButton(onPressed: () { context.read<AppProvider>().deleteWordBook(book.id!); Navigator.pop(ctx); }, style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text(Translations.t('删除', 'Delete'))),
        ],
      ),
    );
  }

  void _showAddWordDialog(BuildContext ctx, int bookId) {
    final wordController = TextEditingController();
    final phoneticController = TextEditingController();
    final definitionController = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(Translations.t('添加单词', 'Add Word')),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: wordController, decoration: InputDecoration(labelText: Translations.t('单词', 'Word')), autofocus: true),
          const SizedBox(height: 12),
          TextField(controller: phoneticController, decoration: InputDecoration(labelText: Translations.t('音标（可选）', 'Phonetic'))),
          const SizedBox(height: 12),
          TextField(controller: definitionController, decoration: InputDecoration(labelText: Translations.t('释义', 'Definition')), maxLines: 2),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(Translations.t('取消', 'Cancel'))),
          FilledButton(
            onPressed: () async {
              final word = wordController.text.trim();
              final definition = definitionController.text.trim();
              if (word.isEmpty || definition.isEmpty) return;
              await DatabaseService.insertWord(Word(word: word, phonetic: phoneticController.text.trim(), definition: definition, wordBookId: bookId));
              if (!mounted) return;
              Navigator.pop(dialogCtx); 
              if (!mounted) return;
              final appProvider = context.read<AppProvider>();
              Navigator.pop(ctx); 
              if (!mounted) return;
              appProvider.loadWordBooks();
            },
            child: Text(Translations.t('添加', 'Add')),
          ),
        ],
      ),
    );
  }
}

class _WordBookCard extends StatelessWidget {
  final WordBook book;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onBrowse;
  final VoidCallback onImport;
  final VoidCallback? onDelete;

  const _WordBookCard({
    required this.book, 
    required this.isSelected, 
    required this.onTap, 
    required this.onBrowse, 
    required this.onImport, 
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: isSelected ? colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(book.isBuiltIn ? Icons.school : Icons.folder_outlined, color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(book.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: isSelected ? colorScheme.onPrimaryContainer : null))),
              if (isSelected) Icon(Icons.check_circle, color: colorScheme.primary, size: 20),
            ]),
            const SizedBox(height: 8),
            Text(book.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isSelected ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7) : colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(children: [
              Text('${book.totalWords} ${Translations.t('词', 'words')}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
              const Spacer(),
              TextButton.icon(onPressed: onBrowse, icon: const Icon(Icons.list_alt, size: 16), label: Text(Translations.t('浏览', 'Browse')), style: TextButton.styleFrom(visualDensity: VisualDensity.compact)),
              if (!book.isBuiltIn) TextButton.icon(onPressed: onImport, icon: const Icon(Icons.upload_file, size: 16), label: Text(Translations.t('导入', 'Import')), style: TextButton.styleFrom(visualDensity: VisualDensity.compact)),
              if (onDelete != null) TextButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 16), label: Text(Translations.t('删除', 'Delete')), style: TextButton.styleFrom(foregroundColor: Colors.red, visualDensity: VisualDensity.compact)),
            ]),
          ]),
        ),
      ),
    );
  }
}