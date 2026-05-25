import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/providers/providers.dart';
import '../theme/fluid_theme.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_card.dart';
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
  bool _isSearching = false;
  String _lastQuery = '';
  Timer? _debounceTimer;

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
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    if (query == _lastQuery) return;
    _lastQuery = query;

    if (mounted) setState(() => _isSearching = true);

    try {
      final wordRepository = context.read<DIContainer>().wordRepository;
      final results = widget.wordBookId != null
          ? await wordRepository.searchWords(query, bookId: widget.wordBookId)
          : await wordRepository.searchAllWords(query);

      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final inputFillColor = FluidTheme.getInputFillColor(isDark);
    final borderColor = FluidTheme.getBorderColor(isDark);

    return FluidBackground(
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
              style: FluidTheme.bodyMedium.copyWith(color: textPrimary),
              cursorColor: FluidTheme.primaryFluidGradient[0],
              decoration: InputDecoration(
                hintText: '搜索单词...',
                hintStyle: FluidTheme.bodyMedium.copyWith(color: textSecondary),
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
            IconButton(
              icon: Icon(Icons.search, color: textPrimary),
              onPressed: () => _search(_searchController.text),
            ),
          ],
        ),
        body: _buildBody(isDark),
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
          ),
        );
      },
    );
  }

  Widget _buildEmptyHint(bool isDark) {
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final iconColor = FluidTheme.getTextTertiaryColor(isDark);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: iconColor),
          const SizedBox(height: 16),
          Text(
            '输入单词或释义进行搜索',
            style: FluidTheme.bodyMedium.copyWith(color: textSecondary),
          ),
        ],
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
            '未找到匹配的单词',
            style: FluidTheme.bodyMedium.copyWith(color: textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试其他关键词',
            style: FluidTheme.bodySmall.copyWith(color: textTertiary),
          ),
        ],
      ),
    );
  }

  void _openWordDetail(Word word) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WordDetailScreen(word: word)),
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final Word word;
  final String query;
  final VoidCallback onTap;

  const _SearchResultItem({
    required this.word,
    required this.query,
    required this.onTap,
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
                  style: FluidTheme.labelLarge.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  highlightStyle: FluidTheme.labelLarge.copyWith(
                    backgroundColor: highlightBackground,
                    color: FluidTheme.primaryFluidGradient[0],
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (word.phonetic.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    word.phonetic,
                    style: FluidTheme.bodySmall.copyWith(
                      color: textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (word.definition.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _HighlightText(
                    text: word.definition,
                    highlight: query,
                    style: FluidTheme.bodySmall.copyWith(
                      color: textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    highlightStyle: FluidTheme.bodySmall.copyWith(
                      backgroundColor: highlightBackground,
                      color: FluidTheme.primaryFluidGradient[0],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.chevron_right, color: textTertiary),
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
