import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/providers/providers.dart';
import '../services/wrong_word_ranking_service.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/page_transitions.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../widgets/dictionary_dialog.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_dialog.dart';
import 'pre_study_screen.dart';
import 'weak_vocabulary_screen.dart';

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

  /// 排序模式：默认按错误次数 desc
  _WrongWordSortMode _sortMode = _WrongWordSortMode.wrongCountDesc;

  @override
  void initState() {
    super.initState();
    _loadWrongWords();
  }

  Future<void> _loadWrongWords() async {
    setState(() => _isLoading = true);

    try {
      final service = DIContainer.instance.wrongWordService;

      final words = await service.getWrongWords();
      final counts = <int, int>{};
      for (final word in words) {
        counts[word.id!] = await service.getWrongCount(word.id!);
      }

      // 按当前排序模式排序
      _applySort(words, counts);

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

  Future<void> _markAsMastered(int wordId) async {
    try {
      final service = DIContainer.instance.wrongWordService;
      await service.removeWrongWord(wordId);
      if (mounted) {
        setState(() {
          _wrongWords.removeWhere((w) => w.id == wordId);
          _wrongCounts.remove(wordId);
          _selectedWords.remove(wordId);
        });
        ErrorHandler.showSuccess(context, context.tr.removedFromWrongWords);
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
        '${context.tr.confirmMarkMastered} ${_selectedWords.length}${context.tr.wrongWordsCount}',
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
      await service.removeWrongWords(_selectedWords.toList());
      if (mounted) {
        setState(() {
          _wrongWords.removeWhere((w) => _selectedWords.contains(w.id));
          _wrongCounts.removeWhere((key, _) => _selectedWords.contains(key));
          _selectedWords.clear();
          _isSelecting = false;
        });
        ErrorHandler.showSuccess(
          context,
          '${context.tr.markedMasteredCount} $selectedCount${context.tr.wrongWordsCount}',
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

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
              IconButton(
                icon: Icon(Icons.school, color: textPrimary),
                onPressed: _wrongWords.isEmpty ? null : _studyWrongWords,
                tooltip: context.tr.specialReview,
              ),
              PopupMenuButton<_WrongWordSortMode>(
                icon: Icon(Icons.sort, color: textPrimary),
                tooltip: context.tr.sortBy,
                onSelected: (mode) async {
                  setState(() => _sortMode = mode);
                  await _loadWrongWords();
                },
                itemBuilder: (ctx) => [
                  CheckedPopupMenuItem(
                    value: _WrongWordSortMode.wrongCountDesc,
                    checked: _sortMode == _WrongWordSortMode.wrongCountDesc,
                    child: Text(context.tr.wrongCount),
                  ),
                  CheckedPopupMenuItem(
                    value: _WrongWordSortMode.hotness,
                    checked: _sortMode == _WrongWordSortMode.hotness,
                    child: Text(context.tr.sortByHotness),
                  ),
                ],
              ),
              if (_isSelecting) ...[
                IconButton(
                  icon: Icon(Icons.select_all, color: textPrimary),
                  onPressed: () {
                    setState(() {
                      _selectedWords.addAll(
                        _wrongWords.map((w) => w.id!).where((id) => id > 0),
                      );
                    });
                  },
                  tooltip: context.tr.selectAll,
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textPrimary),
                  onPressed: () {
                    setState(() {
                      _isSelecting = false;
                      _selectedWords.clear();
                    });
                  },
                  tooltip: context.tr.cancelSelect,
                ),
              ] else
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

  Widget _buildWeakVocabularyEntry(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FluidCard(
        enableShimmer: true,
        enableBorderGradient: true,
        borderColors: FluidTheme.warningFluidGradient,
        padding: const EdgeInsets.all(16),
        onTap: () {
          Navigator.push(
            context,
            PageTransitions.slideFromRight(page: const WeakVocabularyScreen()),
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FluidTheme.warning.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.psychology_alt,
                color: FluidTheme.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr.weakVocabulary,
                    style: FluidTheme.labelLarge(
                      isDark,
                    ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr.weakVocabularyEntryHint,
                    style: FluidTheme.bodyMedium(
                      isDark,
                    ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: FluidTheme.getTextTertiaryColor(isDark),
            ),
          ],
        ),
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
        itemCount: _wrongWords.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildWeakVocabularyEntry(isDark);
          final word = _wrongWords[index - 1];
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
                showDictionaryDialog(context: context, word: word.word);
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

  Color _wrongCountColor(int count) {
    if (count >= 5) return FluidTheme.error;
    if (count >= 3) return FluidTheme.warning;
    if (count >= 2) return Colors.amber;
    return FluidTheme.primaryFluidGradient[0];
  }
}

/// 错词页排序模式
enum _WrongWordSortMode {
  /// 按错误次数 desc（默认，DAO 直出）
  wrongCountDesc,

  /// 按热度（综合评分）排序
  hotness,
}
