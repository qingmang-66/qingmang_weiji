import 'package:flutter/material.dart';
import '../models/word.dart';
import '../services/services.dart';
import '../widgets/dictionary_dialog.dart';
import '../utils/translations.dart';

/// 错词本页面
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

  @override
  void initState() {
    super.initState();
    _loadWrongWords();
  }

  Future<void> _loadWrongWords() async {
    setState(() => _isLoading = true);
    
    try {
      final service = WrongWordService();
      await service.init();
      
      final words = await service.getWrongWords();
      final counts = <int, int>{};
      for (final word in words) {
        counts[word.id!] = await service.getWrongCount(word.id!);
      }
      
      if (mounted) {
        setState(() {
          _wrongWords = words;
          _wrongCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载错词本失败：$e')),
        );
      }
    }
  }

  Future<void> _markAsMastered(int wordId) async {
    try {
      final service = WrongWordService();
      await service.init();
      await service.removeWrongWord(wordId);
      if (mounted) {
        setState(() {
          _wrongWords.removeWhere((w) => w.id == wordId);
          _wrongCounts.remove(wordId);
          _selectedWords.remove(wordId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已从错词本移除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')),
        );
      }
    }
  }

  Future<void> _markSelectedAsMastered() async {
    if (_selectedWords.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.t('确认掌握', 'Confirm Mastery')),
        content: Text(
          Translations.t('确定将 ${_selectedWords.length} 个错词标记为已掌握吗？', 
            'Mark ${_selectedWords.length} words as mastered?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Translations.t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Translations.t('确认', 'Confirm')),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final service = WrongWordService();
      await service.init();
      await service.removeWrongWords(_selectedWords.toList());
      if (mounted) {
        setState(() {
          _wrongWords.removeWhere((w) => _selectedWords.contains(w.id));
          _wrongCounts.removeWhere((key, _) => _selectedWords.contains(key));
          _selectedWords.clear();
          _isSelecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')),
        );
      }
    }
  }

  Future<void> _studyWrongWords() async {
    if (_wrongWords.isEmpty) return;
    
    // TODO: 实现错词专项复习模式
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('专项复习功能开发中...')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.t('错词本', 'Wrong Words')),
        actions: [
          if (_wrongWords.isEmpty) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadWrongWords,
              tooltip: Translations.t('刷新', 'Refresh'),
            ),
          ] else ...[
            // 专项复习按钮
            IconButton(
              icon: const Icon(Icons.school),
              onPressed: _wrongWords.isEmpty ? null : _studyWrongWords,
              tooltip: Translations.t('专项复习', 'Study Wrong Words'),
            ),
            // 选择模式
            IconButton(
              icon: Icon(_isSelecting ? Icons.check_box : Icons.select_all),
              onPressed: () {
                setState(() {
                  _isSelecting = !_isSelecting;
                  if (!_isSelecting) _selectedWords.clear();
                });
              },
              tooltip: _isSelecting 
                  ? Translations.t('取消选择', 'Cancel Selection')
                  : Translations.t('全选', 'Select All'),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wrongWords.isEmpty
              ? _buildEmptyState(colorScheme)
              : _buildWrongWordsList(colorScheme),
      floatingActionButton: _isSelecting && _selectedWords.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _markSelectedAsMastered,
              icon: const Icon(Icons.check),
              label: Text('${_selectedWords.length}'),
              backgroundColor: colorScheme.primary,
            )
          : null,
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 64,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            Translations.t('太棒了！', 'Great job!'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            Translations.t('目前没有错词，继续保持！', 'No wrong words yet!'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: Text(Translations.t('返回', 'Back')),
          ),
        ],
      ),
    );
  }

  Widget _buildWrongWordsList(ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _loadWrongWords,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _wrongWords.length,
        itemBuilder: (context, index) {
          final word = _wrongWords[index];
          final wrongCount = _wrongCounts[word.id] ?? 1;
          final isSelected = _selectedWords.contains(word.id);
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: _isSelecting && word.id != null
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 选择框
                    if (_isSelecting)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                          color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    
                    // 错误次数徽章
                    if (!_isSelecting)
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getWrongCountColor(wrongCount, colorScheme).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '×$wrongCount',
                          style: TextStyle(
                            color: _getWrongCountColor(wrongCount, colorScheme),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    
                    // 单词信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  word.word,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              if (word.phonetic.isNotEmpty)
                                Text(
                                  '/${word.phonetic}/',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                ),
                            ],
                          ),
                          if (word.definition.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              word.definition,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // 操作按钮
                    if (!_isSelecting) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.book_outlined),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => DictionaryDialog(word: word.word),
                          );
                        },
                        tooltip: Translations.t('查词典', 'Dictionary'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        onPressed: word.id != null ? () => _markAsMastered(word.id!) : null,
                        tooltip: Translations.t('标记为已掌握', 'Mark as Mastered'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getWrongCountColor(int count, ColorScheme colorScheme) {
    if (count >= 5) return Colors.red;
    if (count >= 3) return Colors.orange;
    if (count >= 2) return Colors.amber;
    return colorScheme.primary;
  }
}
