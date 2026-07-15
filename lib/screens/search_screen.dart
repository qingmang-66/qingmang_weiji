import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/providers/providers.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../utils/page_transitions.dart';
import '../widgets/fluid_card.dart';
import '../widgets/study_mode_picker.dart';
import '../widgets/word_set_picker_sheet.dart';
import 'pre_study_screen.dart';
import 'word_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final int? wordBookId;

  const SearchScreen({super.key, this.wordBookId});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Word> _results = [];
  List<SearchHistoryItem> _history = [];
  int? _activeWordBookId;
  bool _isSearching = false;
  String _lastQuery = '';
  Timer? _debounceTimer;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await DIContainer.instance.searchHistoryRepository.recent();
    if (!mounted) return;
    setState(() => _history = history);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String query) {
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      _search('');
      return;
    }
    if (query.length < 2) {
      setState(() {});
      return;
    }
    _debounceTimer = Timer(
      const Duration(milliseconds: 300),
      () => _search(query),
    );
    setState(() {});
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      _searchGeneration++;
      _lastQuery = '';
      if (!mounted) return;
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    if (query == _lastQuery) return;
    _lastQuery = query;
    final generation = ++_searchGeneration;
    final bookId = widget.wordBookId ?? _activeWordBookId;

    if (!mounted) return;
    setState(() => _isSearching = true);

    try {
      final di = context.read<DIContainer>();
      final wordRepository = di.wordRepository;
      final searchHistoryRepository = di.searchHistoryRepository;
      // 阶段三：搜索仅在 word 字段匹配，排序简化为 3 档。
      final results = bookId != null
          ? await wordRepository.searchWords(
              query,
              bookId: bookId,
              inWordFieldOnly: true,
            )
          : await wordRepository.searchAllWords(query, inWordFieldOnly: true);
      if (!mounted || generation != _searchGeneration) return;

      await searchHistoryRepository.record(query);
      if (!mounted || generation != _searchGeneration) return;
      await _loadHistory();
      if (!mounted || generation != _searchGeneration) return;

      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = [];
        _isSearching = false;
      });
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: context.tr.loadingError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final inputFillColor = FluidTheme.getInputFillColor(isDark);
    final borderColor = FluidTheme.getBorderColor(isDark);

    return FluidPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textPrimary),
          titleSpacing: 0,
          title: Container(
            height: 44,
            decoration: BoxDecoration(
              color: inputFillColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: FluidTheme.bodyMedium(isDark).copyWith(color: textPrimary),
              cursorColor: FluidTheme.primaryFluidGradient[0],
              decoration: InputDecoration(
                hintText: context.tr.searchHint,
                hintStyle: FluidTheme.bodyMedium(
                  isDark,
                ).copyWith(color: textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      )
                    : null,
              ),
              onChanged: _scheduleSearch,
              onSubmitted: _search,
            ),
          ),
          actions: [
            // 阶段三：临时学习入口，仅在有结果时显示
            if (_results.isNotEmpty)
              IconButton(
                tooltip: context.tr.temporaryStudy,
                icon: Icon(Icons.play_circle_outline, color: textPrimary),
                onPressed: _startTemporaryStudy,
              ),
            IconButton(
              icon: Icon(Icons.search, color: textPrimary),
              onPressed: () => _search(_searchController.text),
            ),
          ],
        ),
        body: Column(
          children: [
            if (widget.wordBookId == null) _buildBookFilter(isDark),
            Expanded(child: _buildBody(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildBookFilter(bool isDark) {
    final wordBooks = context.watch<WordBookProvider>().wordBooks;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          ChoiceChip(
            label: Text(context.tr.allWordBooks),
            selected: _activeWordBookId == null,
            onSelected: (_) {
              setState(() => _activeWordBookId = null);
              _lastQuery = '';
              _search(_searchController.text);
            },
          ),
          const SizedBox(width: 8),
          ...wordBooks.map(
            (book) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(book.name),
                selected: _activeWordBookId == book.id,
                onSelected: (_) {
                  setState(() => _activeWordBookId = book.id);
                  _lastQuery = '';
                  _search(_searchController.text);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_searchController.text.isEmpty) {
      return _buildEmptyHint(isDark);
    }

    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(
          color: FluidTheme.primaryFluidGradient[0],
        ),
      );
    }

    if (_results.isEmpty) {
      return _buildNoResult(isDark);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final word = _results[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SearchResultItem(
            word: word,
            query: _searchController.text,
            onTap: () => _openWordDetail(word),
            onAddToSet: () => _addToCustomSet(word),
            onToggleFavorite: () => _toggleFavorite(word),
          ),
        );
      },
    );
  }

  Widget _buildEmptyHint(bool isDark) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final iconColor = FluidTheme.getTextTertiaryColor(isDark);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: iconColor),
            const SizedBox(height: 16),
            Text(
              context.tr.searchEmptyHint,
              style: FluidTheme.bodyMedium(
                isDark,
              ).copyWith(color: textSecondary),
            ),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.tr.recentSearch,
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: textPrimary),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _history.map((item) {
                  return ActionChip(
                    label: Text(item.query),
                    onPressed: () {
                      _searchController.text = item.query;
                      _search(item.query);
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoResult(bool isDark) {
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final textTertiary = FluidTheme.getTextTertiaryColor(isDark);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: textTertiary),
          const SizedBox(height: 16),
          Text(
            context.tr.noMatchFound,
            style: FluidTheme.bodyMedium(isDark).copyWith(color: textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr.tryOtherKeywords,
            style: FluidTheme.bodySmall(isDark).copyWith(color: textTertiary),
          ),
        ],
      ),
    );
  }

  void _openWordDetail(Word word) {
    Navigator.push(
      context,
      PageTransitions.slideFromRight(page: WordDetailScreen(word: word)),
    );
  }

  Future<void> _toggleFavorite(Word word) async {
    final wordId = word.id;
    if (wordId == null) return;
    final repo = context.read<DIContainer>().favoriteRepository;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final isFavorite = await repo.isFavorite(wordId);
      if (isFavorite) {
        await repo.removeFavorite(wordId);
      } else {
        await repo.addFavorite(wordId: wordId);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isFavorite
                ? context.tr.removedFromFavorites
                : context.tr.addedToFavorites,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: context.tr.favoriteActionFailed,
      );
    }
  }

  Future<void> _addToCustomSet(Word word) async {
    final wordId = word.id;
    if (wordId == null) return;
    // 阶段三：抽出通用组件，统一错误处理
    await showWordSetPickerSheet(context, wordId: wordId);
  }

  /// 阶段三：开始搜索结果临时学习
  Future<void> _startTemporaryStudy() async {
    if (_results.isEmpty) return;
    final mode = await showStudyModePicker(context);
    if (mode == null || !mounted) return;
    final wordIds = _results.map((w) => w.id).whereType<int>().toList();
    if (wordIds.isEmpty) {
      ErrorHandler.showError(context, context.tr.noSearchWords);
      return;
    }
    final di = context.read<DIContainer>();
    final request = await di.specializedStudyService.buildSearchResultsRequest(
      wordIds: wordIds,
      query: _searchController.text.trim(),
      wordBookId: _activeWordBookId,
      studyMode: mode,
    );
    if (!mounted || request == null) return;
    await Navigator.of(context).push(
      PageTransitions.slideFromRight(
        page: PreStudyScreen.specialized(request: request, words: _results),
      ),
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final Word word;
  final String query;
  final VoidCallback onTap;
  final VoidCallback onAddToSet;
  final VoidCallback onToggleFavorite;

  const _SearchResultItem({
    required this.word,
    required this.query,
    required this.onTap,
    required this.onAddToSet,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final textTertiary = FluidTheme.getTextTertiaryColor(isDark);
    final highlightBackground = FluidTheme.primaryFluidGradient[0].withValues(
      alpha: isDark ? 0.22 : 0.14,
    );

    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HighlightText(
                  text: word.word,
                  highlight: query,
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: textPrimary, fontWeight: FontWeight.w600),
                  highlightStyle: FluidTheme.labelLarge(isDark).copyWith(
                    backgroundColor: highlightBackground,
                    color: FluidTheme.primaryFluidGradient[0],
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (word.phonetic.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    word.phonetic,
                    style: FluidTheme.bodySmall(
                      isDark,
                    ).copyWith(color: textSecondary, fontSize: 13),
                  ),
                ],
                if (word.definition.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _HighlightText(
                    text: word.definition,
                    highlight: query,
                    style: FluidTheme.bodySmall(
                      isDark,
                    ).copyWith(color: textSecondary, fontSize: 13),
                    maxLines: 1,
                    highlightStyle: FluidTheme.bodySmall(isDark).copyWith(
                      backgroundColor: highlightBackground,
                      color: FluidTheme.primaryFluidGradient[0],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          // 阶段三：紧凑的双图标按钮，使用 i18n 文案。
          IconButton(
            tooltip: context.tr.toggleFavorite,
            icon: Icon(Icons.bookmark_add_outlined, color: textTertiary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: onToggleFavorite,
          ),
          IconButton(
            tooltip: context.tr.addToSet,
            icon: Icon(Icons.playlist_add, color: textTertiary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: onAddToSet,
          ),
        ],
      ),
    );
  }
}

class _HighlightText extends StatelessWidget {
  final String text;
  final String highlight;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;

  const _HighlightText({
    required this.text,
    required this.highlight,
    this.style,
    this.highlightStyle,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (highlight.isEmpty ||
        !text.toLowerCase().contains(highlight.toLowerCase())) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerHighlight = highlight.toLowerCase();

    var start = 0;
    var index = lowerText.indexOf(lowerHighlight);

    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + highlight.length),
          style: highlightStyle,
        ),
      );
      start = index + highlight.length;
      index = lowerText.indexOf(lowerHighlight, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }

    return RichText(
      text: TextSpan(children: spans, style: style),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
