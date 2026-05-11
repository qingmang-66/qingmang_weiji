import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/translations.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    setState(() => _isSearching = true);

    try {
      final results = widget.wordBookId != null
          ? await DatabaseService.searchWords(query, bookId: widget.wordBookId)
          : await DatabaseService.searchAllWords(query);

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: Translations.t('搜索单词...', 'Search words...'),
            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _search('');
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            if (value.length >= 2) {
              _search(value);
            } else if (value.isEmpty) {
              _search('');
            }
            setState(() {});
          },
          onSubmitted: _search,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_searchController.text),
          ),
        ],
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_searchController.text.isEmpty) {
      return _buildEmptyHint(colorScheme);
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return _buildNoResult(colorScheme);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final word = _results[index];
        return _SearchResultItem(
          word: word,
          query: _searchController.text,
          onTap: () => _openWordDetail(word),
        );
      },
    );
  }

  Widget _buildEmptyHint(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '输入单词或释义进行搜索',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResult(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '未找到匹配的单词',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试其他关键词',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _openWordDetail(Word word) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordDetailScreen(word: word),
      ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: _HighlightText(
        text: word.word,
        highlight: query,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        highlightStyle: TextStyle(
          backgroundColor: colorScheme.primaryContainer,
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (word.phonetic.isNotEmpty)
            Text(
              word.phonetic,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          if (word.definition.isNotEmpty)
            _HighlightText(
              text: word.definition,
              highlight: query,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
              maxLines: 1,
              highlightStyle: TextStyle(
                backgroundColor: colorScheme.tertiaryContainer,
                color: colorScheme.tertiary,
              ),
            ),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
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
    if (highlight.isEmpty || !text.toLowerCase().contains(highlight.toLowerCase())) {
      return Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerHighlight = highlight.toLowerCase();

    int start = 0;
    int index = lowerText.indexOf(lowerHighlight);

    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + highlight.length),
        style: highlightStyle,
      ));
      start = index + highlight.length;
      index = lowerText.indexOf(lowerHighlight, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}