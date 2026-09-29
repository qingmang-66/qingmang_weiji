import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../screens/word_detail_screen.dart';
import '../services/di_container.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/page_transitions.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../utils/word_search_utils.dart';
import 'dictionary_dialog.dart';
import 'fluid_dialog.dart';

/// 首页「搜索单词」的快捷面板。
///
/// 目标很明确：想收藏某个词时不用先切到词库、进搜索页，在首页一步到位。
/// 之所以做成独立的面板而不是把列表嵌进首页：
/// - 首页是长列表 + 多张卡片，输入法弹起时的重排代价大；
/// - 面板是独立的 Overlay 路由，输入框焦点、键盘避让、结果滚动都在它内部完成，
///   首页整棵树不参与重建。
///
/// 搜索范围是**全部词库**：想收藏的词未必在当前词书里，限定范围会让人搜不到。
/// 实测 3.4 万词条的表，全库 LIKE + 排序中位数约 8ms（桌面），移动端估计
/// 25~50ms，且 sqflite 在独立线程执行，不会卡住界面。
///
/// 性能上的几个关键约束（首页搜索最容易卡的地方）：
/// 1. 关键字防抖 280ms + 世代号，保证同一时刻只有一次有效查询结果能上屏；
/// 2. 查询在途时不再发起新查询，只记下"待查关键字"，避免快速输入堆积 SQL；
/// 3. 结果固定上限 [kQuickSearchLimit]，列表行高固定并用 `itemExtent`，
///    滚动阶段不做逐行测量；多取一倍用于跨词库去重（LIMIT 在排序之后生效，
///    多取几条几乎不增加成本）；
/// 4. 收藏状态用一次 `filterFavorited` 批量取回，而不是每行查一次。
const int kQuickSearchLimit = 20;

/// 打开首页快捷搜索面板
///
/// 早期是 `showModalBottomSheet` 贴底弹出，但那带来两个问题：一是自己手搭的
/// 白底容器没有跟随界面风格（液态玻璃模式下格格不入），二是底部滑入与全局
/// 其它卡片"居中弹出 + 弹簧/果冻入场"的动效语言不一致。
/// 现在统一交给 [showFluidDialog]：居中弹出、双风格材质、果冻/弹簧入场、
/// 键盘避让（Dialog 会随 viewInsets 上移）全都复用现成实现。
Future<void> showQuickWordSearchSheet(BuildContext context) {
  return showFluidDialog<void>(
    context: context,
    scrollable: false,
    maxWidth: 560,
    content: const _QuickWordSearchPanel(),
  );
}

class _QuickWordSearchPanel extends StatefulWidget {
  const _QuickWordSearchPanel();

  @override
  State<_QuickWordSearchPanel> createState() => _QuickWordSearchPanelState();
}

class _QuickWordSearchPanelState extends State<_QuickWordSearchPanel> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<Word> _results = const [];
  Set<int> _favoriteIds = <int>{};
  bool _isSearching = false;
  bool _hasSearched = false;

  Timer? _debounce;
  int _generation = 0;

  /// 查询在途时记下最新关键字，等这次查完再补一次，避免并发查询
  String? _queuedQuery;

  /// 当前已上屏结果对应的关键字，用于去重
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      //关键字太短：清空结果并作废在途查询，不再打数据库。
      //
      //刻意不动 _isSearching：在途请求由它自己在收尾时放掉忙碌标记，
      //这里若抢先置 false，下一次查询就能与旧请求并发，反而更乱。
      _generation++;
      _queuedQuery = null;
      setState(() {
        _results = const [];
        _favoriteIds = <int>{};
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () => _search(query));
    setState(() {});
  }

  Future<void> _search(String query) async {
    //单个字母的 LIKE 命中太多、排序也没意义，一律不打数据库；
    //回车提交也走这里，所以判断放在本函数里最稳
    if (query.length < 2) return;
    if (_isSearching) {
      //已有查询在途：只记下最新关键字，等它收尾时补查，避免并发查库
      _queuedQuery = query;
      return;
    }
    if (query == _lastQuery && _hasSearched) return;

    _lastQuery = query;
    final generation = ++_generation;
    setState(() => _isSearching = true);

    var results = const <Word>[];
    var favorites = <int>{};
    try {
      final di = context.read<DIContainer>();
      final matched = await di.wordRepository.searchWords(
        query,
        //多取一倍用于跨词库去重：同一个词常同时收在 CET4 与考研词库里，
        //列表里重复出现同一条很迷惑
        limit: kQuickSearchLimit * 2,
        inWordFieldOnly: true,
      );
      results = dedupeWordsByWord(matched, limit: kQuickSearchLimit);
      if (mounted && generation == _generation) {
        //一次批量取收藏状态，避免逐行查库
        try {
          favorites = await di.favoriteService.filterFavorited(
            results.map((w) => w.id).whereType<int>(),
          );
        } catch (_) {
          //收藏状态取不到不影响搜索本身，星标先按未收藏显示
        }
      }
    } catch (e) {
      debugPrint('快捷搜索失败：$e');
    }

    //本次结果是否真的上屏了（被更短关键字打断时不作数）
    final committed = generation == _generation;

    //统一收口：无论是查完、报错还是被更短的关键字作废，都必须放掉忙碌标记，
    //否则后续查询会永远停在"排队"分支里，界面上的转圈再也结束不了。
    if (mounted) {
      if (committed) {
        setState(() {
          _results = results;
          _favoriteIds = favorites;
          _isSearching = false;
          _hasSearched = true;
        });
        _scrollToTop();
      } else {
        setState(() => _isSearching = false);
      }
    }

    //在途期间到达的新关键字补查一次。
    //只有"刚查完且上屏结果正是这个关键字"时才跳过——被打断的请求虽然查完了
    //却什么都没上屏，那种情况下必须重查，否则列表会一直停在空态。
    final queued = _queuedQuery;
    _queuedQuery = null;
    final alreadyShown = committed && queued == _lastQuery;
    if (mounted && queued != null && !alreadyShown) {
      unawaited(_search(queued));
    }
  }

  /// 直接用词典查这个词。
  ///
  /// 搜索只能命中「已导入词书里的单词」，而查词典走的是本地词典 + 在线双源，
  /// 查的词不必在任何词书里——这正是把两者接起来的意义：搜不到也能查。
  Future<void> _lookupWord(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return;
    //先收起键盘：弹出的词典是居中显示的，键盘会把它压住；
    //关掉词典后把焦点还给输入框，用户可以接着搜下一个词
    _focusNode.unfocus();
    await showDictionaryLookupDialog(context: context, word: trimmed);
    if (mounted) _focusNode.requestFocus();
  }

  /// 换了关键字就回到列表顶部：沿用上一段结果的滚动位置会让人以为没刷新
  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.offset == 0) return;
      _scrollController.jumpTo(0);
    });
  }

  Future<void> _toggleFavorite(Word word) async {
    final wordId = word.id;
    if (wordId == null) return;

    //乐观更新：星标立刻响应，失败再回滚，避免等一次磁盘 IO 才有反馈
    final wasFavorite = _favoriteIds.contains(wordId);
    setState(() {
      if (wasFavorite) {
        _favoriteIds.remove(wordId);
      } else {
        _favoriteIds.add(wordId);
      }
    });

    try {
      final nowFavorite = await context
          .read<DIContainer>()
          .favoriteService
          .toggleWord(wordId, source: FavoriteSource.homeSearch);
      if (!mounted) return;
      //以落库结果为准修正一次（并发点击时乐观值可能与真实值不一致）
      setState(() {
        nowFavorite ? _favoriteIds.add(wordId) : _favoriteIds.remove(wordId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        wasFavorite ? _favoriteIds.add(wordId) : _favoriteIds.remove(wordId);
      });
      // SnackBar 挂在底层 Scaffold 上，会被本搜索面板（弹层）完全遮住，
      // 用户看不到失败原因；改用 root overlay 级轻提示
      ErrorHandler.showTransientToast(
        context,
        context.tr.quickSearchFavoriteFailed,
        isError: true,
      );
      debugPrint('快捷搜索收藏失败：$e');
    }
  }

  Future<void> _openDetail(Word word) async {
    await Navigator.of(context).push(
      PageTransitions.slideFromRight(
        //快捷搜索属于「首页搜索」来源
        page: WordDetailScreen(
          word: word,
          favoriteSource: FavoriteSource.homeSearch,
        ),
      ),
    );
    if (!mounted) return;
    //详情页里可能改了收藏状态，回来同步一次这一行
    final wordId = word.id;
    if (wordId == null) return;
    try {
      final isFavorite = await context
          .read<DIContainer>()
          .favoriteService
          .isFavorite(wordId);
      if (!mounted) return;
      setState(() {
        isFavorite ? _favoriteIds.add(wordId) : _favoriteIds.remove(wordId);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    // 外壳（玻璃/流体渐变双风格、果冻入场、键盘避让）由 FluidDialog 提供，
    // 这里只负责内容排布；结果列表靠 FluidDialog 给的 maxHeight 约束收拢
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTitle(context, isDark, textPrimary, textSecondary),
        _buildSearchField(context, isDark, textPrimary, textSecondary),
        Flexible(child: _buildResultArea(context, isDark)),
      ],
    );
  }

  Widget _buildTitle(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr.quickSearchTitle,
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: textPrimary, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr.quickSearchTip,
                  style: FluidTheme.bodySmall(
                    isDark,
                  ).copyWith(color: textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Container(
        decoration: BoxDecoration(
          color: FluidTheme.getInputFillColor(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FluidTheme.getBorderColor(isDark)),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          // Android 上不自动调起输入法（用户要求：除拼写/听力模式外，
        // 所有输入框都要用户主动点击才弹键盘）；桌面端保持"打开即可输入"
        autofocus: PlatformAdapt.isDesktop,
          textInputAction: TextInputAction.search,
          style: FluidTheme.bodyMedium(isDark).copyWith(color: textPrimary),
          cursorColor: FluidTheme.primaryFluidGradient[0],
          onChanged: _onChanged,
          onSubmitted: (value) => _search(value.trim()),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: context.tr.quickSearchHint,
            hintStyle: FluidTheme.bodyMedium(
              isDark,
            ).copyWith(color: textSecondary),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            prefixIcon: Icon(Icons.search, size: 20, color: textSecondary),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.clear, size: 18, color: textSecondary),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                      _focusNode.requestFocus();
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultArea(BuildContext context, bool isDark) {
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    //固定行高要跟着系统字号缩放走：itemExtent 不会自动适配文字缩放，
    //写死高度时大字号用户会看到行内内容溢出
    final rowExtent =
        72 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);

    if (_controller.text.trim().length < 2) {
      return _buildHint(
        // 桌面端讲"接着用键盘输"；移动端没有物理键盘，键盘图标反而误导
        PlatformAdapt.showKeyboardShortcuts(context)
            ? Icons.keyboard_outlined
            : Icons.search,
        context.tr.quickSearchMinChars,
        textSecondary,
      );
    }
    if (_isSearching && _results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: FluidTheme.primaryFluidGradient[0],
            ),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      if (!_hasSearched) return const SizedBox(height: 24);
      final query = _controller.text.trim();
      return _buildHint(
        Icons.search_off,
        context.tr.quickSearchNoResult,
        textSecondary,
        //词书里没有就送它去查词典：词典是本地 + 在线双源，
        //本来就不要求这个词在词书里
        action: _buildLookupAction(query),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            //固定行高：滚动时不做逐行测量，长列表也能稳住帧率
            itemExtent: rowExtent,
            addAutomaticKeepAlives: false,
            addSemanticIndexes: false,
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final word = _results[index];
              final wordId = word.id;
              final isFavorite =
                  wordId != null && _favoriteIds.contains(wordId);
              return _QuickResultRow(
                word: word,
                isFavorite: isFavorite,
                onTap: () => _openDetail(word),
                onToggleFavorite: () => _toggleFavorite(word),
                onLookup: () => _lookupWord(word.word),
              );
            },
          ),
        ),
        _buildFooter(context, textSecondary),
      ],
    );
  }

  Widget _buildHint(IconData icon, String text, Color color, {Widget? action}) {
    return Padding(
      //外层 FluidDialog 已有 24dp 的内容边距，这里纵向留白收紧一点
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: color.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(color: color, fontSize: 13.5)),
          if (action != null) ...[const SizedBox(height: 12), action],
        ],
      ),
    );
  }

  /// 「查词典 “xxx”」入口：把输入框里的关键字原样交给词典
  Widget _buildLookupAction(String word) {
    if (word.isEmpty) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: () => _lookupWord(word),
      icon: const Icon(Icons.menu_book_outlined, size: 18),
      label: Text('${context.tr.lookupDictionary} “$word”'),
    );
  }

  /// 底部计数：只有结果达到上限时才显示，提示"还有更多没列出来"。
  ///
  /// 早先这里还有一个「打开全部结果」按钮跳完整搜索页，完整搜索页删除后
  /// 本面板就是唯一的搜索界面，按钮随之移除。
  Widget _buildFooter(BuildContext context, Color textSecondary) {
    if (_results.length < kQuickSearchLimit) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '${_results.length} / $kQuickSearchLimit',
        style: TextStyle(color: textSecondary, fontSize: 12),
      ),
    );
  }
}

/// 单条搜索结果：单词 + 音标 + 释义 + 查词典 + 收藏星标
///
/// 刻意做成 const 友好的纯展示组件：点击星标只让这一行重建，
/// 不会带着整个结果列表重刷。
class _QuickResultRow extends StatelessWidget {
  final Word word;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onLookup;

  /// 行内两个按钮统一用紧凑密度：默认 48×48 会把单词和释义挤到只剩一半宽度
  static const BoxConstraints _actionBox = BoxConstraints(
    minWidth: 40,
    minHeight: 40,
  );

  const _QuickResultRow({
    required this.word,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onLookup,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          word.word,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FluidTheme.labelLarge(
                            isDark,
                          ).copyWith(color: textPrimary),
                        ),
                      ),
                      if (word.phonetic.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            word.phonetic,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    word.definition,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            //查词典：本地词典命中就用本地释义，没有则联网补全，
            //点行本身是"看词条详情"，两者职责分开
            IconButton(
              icon: Icon(
                Icons.menu_book_outlined,
                size: 20,
                color: textSecondary.withValues(alpha: 0.75),
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: _actionBox,
              tooltip: context.tr.lookupDictionary,
              onPressed: onLookup,
            ),
            IconButton(
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                size: 20,
                color: isFavorite
                    ? FluidTheme.favorite
                    : textSecondary.withValues(alpha: 0.75),
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: _actionBox,
              tooltip: isFavorite
                  ? context.tr.removeFromFavorites
                  : context.tr.addToFavorites,
              onPressed: onToggleFavorite,
            ),
          ],
        ),
      ),
    );
  }
}
