import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../services/providers/providers.dart';
import '../services/wrong_word_service.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../widgets/dictionary_dialog.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_dialog.dart';

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
        ErrorHandler.handleException(context, e, fallbackMessage: '加载错词本失败');
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
        ErrorHandler.showSuccess(context, '已从错词本移除');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(context, e, fallbackMessage: '操作失败');
      }
    }
  }

  Future<void> _markSelectedAsMastered() async {
    if (_selectedWords.isEmpty) return;

    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    final confirmed = await showFluidDialog<bool>(
      context: context,
      title: '确认掌握',
      content: Text(
        '确定将 ${_selectedWords.length} 个错词标记为已掌握吗？',
        style: FluidTheme.bodyMedium.copyWith(color: textPrimary),
      ),
      actions: [
        FluidTextButton(
          text: '取消',
          onPressed: () => Navigator.pop(context, false),
        ),
        FluidButton(text: '确认', onPressed: () => Navigator.pop(context, true)),
      ],
    );

    if (confirmed != true) return;

    try {
      final service = WrongWordService();
      await service.init();
      final selectedCount = _selectedWords.length;
      await service.removeWrongWords(_selectedWords.toList());
      if (mounted) {
        setState(() {
          _wrongWords.removeWhere((w) => _selectedWords.contains(w.id));
          _wrongCounts.removeWhere((key, _) => _selectedWords.contains(key));
          _selectedWords.clear();
          _isSelecting = false;
        });
        ErrorHandler.showSuccess(context, '已标记 $selectedCount 个错词为掌握');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(context, e, fallbackMessage: '操作失败');
      }
    }
  }

  Future<void> _studyWrongWords() async {
    if (_wrongWords.isEmpty) return;

    if (mounted) {
      ErrorHandler.showSuccess(context, '专项复习功能开发中...');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    return FluidBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textPrimary),
          title: Text(
            '错词本',
            style: FluidTheme.headingMedium.copyWith(color: textPrimary),
          ),
          actions: [
            if (_wrongWords.isEmpty) ...[
              IconButton(
                icon: Icon(Icons.refresh, color: textPrimary),
                onPressed: _loadWrongWords,
                tooltip: '刷新',
              ),
            ] else ...[
              IconButton(
                icon: Icon(Icons.school, color: textPrimary),
                onPressed: _wrongWords.isEmpty ? null : _studyWrongWords,
                tooltip: '专项复习',
              ),
              IconButton(
                icon: Icon(
                  _isSelecting ? Icons.check_box : Icons.select_all,
                  color: textPrimary,
                ),
                onPressed: () {
                  setState(() {
                    _isSelecting = !_isSelecting;
                    if (!_isSelecting) _selectedWords.clear();
                  });
                },
                tooltip: _isSelecting ? '取消选择' : '全选',
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
            : _wrongWords.isEmpty
            ? _buildEmptyState(isDark)
            : _buildWrongWordsList(isDark),
        floatingActionButton: _isSelecting && _selectedWords.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _markSelectedAsMastered,
                icon: const Icon(Icons.check, color: Colors.white),
                label: Text(
                  '${_selectedWords.length}',
                  style: const TextStyle(color: Colors.white),
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
            '太棒了！',
            style: FluidTheme.headingSmall.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '目前没有错词，继续保持！',
            style: FluidTheme.bodyMedium.copyWith(color: textSecondary),
          ),
          const SizedBox(height: 32),
          FluidButton(
            text: '返回',
            icon: Icons.arrow_back,
            onPressed: () => Navigator.pop(context),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWrongWordsList(bool isDark) {
    return RefreshIndicator(
      color: FluidTheme.primaryFluidGradient[0],
      backgroundColor: FluidTheme.getDialogSurfaceColor(isDark),
      onRefresh: _loadWrongWords,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _wrongWords.length,
        itemBuilder: (context, index) {
          final word = _wrongWords[index];
          final wrongCount = _wrongCounts[word.id] ?? 1;
          final isSelected = _selectedWords.contains(word.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WrongWordItem(
              word: word,
              wrongCount: wrongCount,
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
                showDialog(
                  context: context,
                  builder: (ctx) => DictionaryDialog(word: word.word),
                );
              },
              onMarkAsMastered: word.id != null
                  ? () => _markAsMastered(word.id!)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _WrongWordItem extends StatelessWidget {
  final Word word;
  final int wrongCount;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback? onToggleSelected;
  final VoidCallback onOpenDictionary;
  final VoidCallback? onMarkAsMastered;

  const _WrongWordItem({
    required this.word,
    required this.wrongCount,
    required this.isSelecting,
    required this.isSelected,
    required this.onToggleSelected,
    required this.onOpenDictionary,
    required this.onMarkAsMastered,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final textTertiary = FluidTheme.getTextTertiaryColor(isDark);
    final wrongColor = _wrongCountColor(wrongCount);

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
              child: Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                color: isSelected
                    ? FluidTheme.primaryFluidGradient[0]
                    : textTertiary,
              ),
            ),
          if (!isSelecting)
            Container(
              margin: const EdgeInsets.only(right: 12, top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: wrongColor.withValues(alpha: isDark ? 0.16 : 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: wrongColor.withValues(alpha: isDark ? 0.28 : 0.20),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        word.word,
                        style: FluidTheme.headingSmall.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (word.phonetic.isNotEmpty)
                      Text(
                        '/${word.phonetic}/',
                        style: FluidTheme.bodySmall.copyWith(
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
                    style: FluidTheme.bodyMedium.copyWith(color: textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (!isSelecting) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.book_outlined, color: textSecondary),
              onPressed: onOpenDictionary,
              tooltip: '查词典',
            ),
            IconButton(
              icon: Icon(Icons.check_circle_outline, color: textSecondary),
              onPressed: onMarkAsMastered,
              tooltip: '标记为已掌握',
            ),
          ],
        ],
      ),
    );
  }

  Color _wrongCountColor(int count) {
    if (count >= 5) return FluidTheme.error;
    if (count >= 3) return FluidTheme.warning;
    if (count >= 2) return Colors.amber;
    return FluidTheme.primaryFluidGradient[0];
  }
}
