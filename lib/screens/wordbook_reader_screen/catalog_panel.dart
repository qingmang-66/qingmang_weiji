part of '../wordbook_reader_screen.dart';

/// 目录面板：本词书词条列表 + 搜索跳转。
///
/// 由 [_WordbookReaderScreenState._showWordList] 打开；标题栏右侧的搜索按钮
/// 通过 [FluidDialog.titleTrailing] 注入，点击后在本面板顶部展开搜索框，
/// 按单词或释义过滤词条，点中结果直接跳转到对应页。
class _CatalogPanel extends StatefulWidget {
  final List<Word> words;
  final int currentIndex;
  final ValueChanged<int> onJump;

  const _CatalogPanel({
    super.key,
    required this.words,
    required this.currentIndex,
    required this.onJump,
  });

  @override
  State<_CatalogPanel> createState() => _CatalogPanelState();
}

class _CatalogPanelState extends State<_CatalogPanel> {
  bool _searching = false;

  /// 输入框里的原始文本（只用于控制清空按钮的显隐）
  String _query = '';

  /// 真正参与过滤的查询词：比输入滞后 [_searchDebounce]，
  /// 连续敲字时不会每个键都跑一次全量扫描
  String _activeQuery = '';
  static const Duration _searchDebounce = Duration(milliseconds: 140);
  Timer? _debounce;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  /// 整本书词/释义的小写副本。
  ///
  /// 目录搜索此前在 build 里直接对全部词条做 `toLowerCase()`：一本 3000+ 词的
  /// 词库，每敲一个字符就要新建几千个临时字符串，滚动时也会随重建重复计算，
  /// 表现就是"目录里一搜索就掉帧"。小写表只建一次，之后每次过滤只做 contains。
  List<String>? _lowerWords;
  List<String>? _lowerDefs;

  /// 未搜索时的全量下标（避免每次 build 都重新生成一个大列表）
  List<int>? _allIndexes;

  /// 上一次过滤结果缓存
  List<int>? _cache;
  String _cacheQuery = '';

  /// 命中当前搜索词的词条下标（对 [widget.words] 的索引）。
  List<int> get _visibleIndexes {
    final q = _activeQuery.trim().toLowerCase();
    if (q.isEmpty) {
      return _allIndexes ??= List<int>.generate(
        widget.words.length,
        (i) => i,
      );
    }
    if (_cache != null && _cacheQuery == q) return _cache!;
    _buildLowerIndex();
    final words = _lowerWords!;
    final defs = _lowerDefs!;
    final hits = <int>[];
    for (var i = 0; i < words.length; i++) {
      if (words[i].contains(q) || defs[i].contains(q)) hits.add(i);
    }
    _cache = hits;
    _cacheQuery = q;
    return hits;
  }

  void _buildLowerIndex() {
    if (_lowerWords != null) return;
    final n = widget.words.length;
    final words = List<String>.filled(n, '');
    final defs = List<String>.filled(n, '');
    for (var i = 0; i < n; i++) {
      final w = widget.words[i];
      words[i] = w.word.toLowerCase();
      defs[i] = w.definition.toLowerCase();
    }
    _lowerWords = words;
    _lowerDefs = defs;
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      setState(() => _activeQuery = value);
    });
  }

  void toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _activeQuery = '';
        _cache = null;
        _controller.clear();
        _searchFocus.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final indexes = _visibleIndexes;
    final accent = FluidTheme.primaryFluidGradient[0];

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.5,
      child: Column(
        children: [
          if (_searching) ...[
            TextField(
              controller: _controller,
              focusNode: _searchFocus,
              style: TextStyle(
                color: FluidTheme.getTextPrimaryColor(isDark),
                fontSize: 15,
              ),
              cursorColor: accent,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20, color: accent),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _controller.clear();
                          _debounce?.cancel();
                          setState(() {
                            _query = '';
                            _activeQuery = '';
                          });
                        },
                      ),
                hintText: context.tr.searchHint,
                filled: true,
                fillColor: FluidTheme.getInputFillColor(isDark),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: FluidTheme.getBorderColor(isDark),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent),
                ),
              ),
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: indexes.isEmpty
                ? Center(
                    child: Text(
                      context.tr.noDefinitionFound,
                      style: FluidTheme.bodyMedium(isDark).copyWith(
                        color: FluidTheme.getTextSecondaryColor(isDark),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: indexes.length,
                    itemBuilder: (ctx, i) {
                      final index = indexes[i];
                      final w = widget.words[index];
                      final isCurrent = index == widget.currentIndex;
                      return ListTile(
                        dense: true,
                        title: Text(
                          w.word,
                          style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isCurrent ? accent : null,
                          ),
                        ),
                        subtitle: w.definition.isEmpty
                            ? null
                            : Text(
                                w.definition,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: () {
                          Navigator.pop(ctx);
                          widget.onJump(index);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
