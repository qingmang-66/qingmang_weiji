import 'dart:async';
import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/di_container.dart';
import '../services/guide_service.dart';
import '../services/providers/reader_settings_provider.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/guide_keys.dart';
import '../utils/picked_file_helper.dart';
import '../utils/platform_adapt.dart';
import '../utils/platform_info.dart';
import '../utils/reader_bg_io.dart'
    if (dart.library.html) '../utils/reader_bg_web.dart'
    as reader_bg;
import '../utils/translations.dart';
import '../utils/wordbook_localization.dart';
import '../widgets/coach_mark_overlay.dart';
import '../widgets/color_wheel_picker.dart';
import '../widgets/dictionary_dialog.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/fluid_settings.dart';
import '../widgets/liquid_controls.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/reader_page_curl.dart';

part 'wordbook_reader_screen/settings_panel.dart';
part 'wordbook_reader_screen/bookmark_panel.dart';
part 'wordbook_reader_screen/catalog_panel.dart';

/// 词条段：一个词条可能按释义的行跨页拆分，每页放其中一段
class _ReaderSeg {
  const _ReaderSeg({
    required this.word,
    required this.withHead,
    required this.def,
    required this.tail,
    required this.height,
  });

  /// 词表索引
  final int word;

  /// 是否包含单词行 + 音标行（false = 纯续段，只接上一页的释义）
  final bool withHead;

  /// 本段渲染的释义文本（拆分后为其中若干行）
  final String def;

  /// 是否词条的最后一段（决定段尾是否加词条间距）
  final bool tail;

  /// 测量高度（含 tail 时的间距）
  final double height;
}

/// 阅读页：一页由若干词条段组成
class _ReaderPage {
  _ReaderPage(this.segs);
  final List<_ReaderSeg> segs;

  /// 当前页首个"完整词条"（单词行+音标+释义）的索引：
  /// 跨页拆分的续段不算完整，书签/进度需要落在单词本身上。
  /// 整页只有续段（一词跨三页的中间页）时退回该词本身
  int get firstWord =>
      segs.firstWhere((g) => g.withHead, orElse: () => segs.first).word;

  /// 当前页最后一个词条索引（续段也算，用于页范围判定）
  int get lastWord => segs.last.word;
}

/// 词书阅读器：像看小说一样翻页背单词
/// 每页词数由字体大小/粗细自动排版决定，支持勾记、书签、背景自定义
class WordbookReaderScreen extends StatefulWidget {
  final int bookId;

  const WordbookReaderScreen({super.key, required this.bookId});

  @override
  State<WordbookReaderScreen> createState() => _WordbookReaderScreenState();
}

class _WordbookReaderScreenState extends State<WordbookReaderScreen>
    with WidgetsBindingObserver {
  static const _hPad = 20.0;
  static const _vPad = 16.0;
  static const _entryGap = 14.0;

  /// 页首与状态栏避让之间的额外留白（小说式排版的顶边距）
  static const _pageTopGap = 12.0;

  /// 排版测量吸收 TextPainter 与真实渲染的高度误差，避免页尾被裁一行
  static const _measureSlack = 4.0;

  /// 「记住了 · 行底色」开启时给词条加的内边距：不预留会在分页测量与实际
  /// 渲染之间产生偏差，页尾会被裁
  static const _markRowPadding = 8.0;
  static const _markRowPadV = 6.0;

  static const _volumeChannel = MethodChannel('qingmang_weiji/reader_volume');

  List<Word> _words = [];
  Set<int> _markedIds = {};
  List<ReaderBookmark> _bookmarks = [];
  int _currentWordIndex = 0;
  int _currentPage = 0;
  String _bookName = '';
  bool _loading = true;

  final PageController _pageController = PageController();
  final FocusNode _focusNode = FocusNode();
  List<_ReaderPage> _pages = [];
  String? _pageKey; //分页缓存键：尺寸+字体设置+勾记版本
  int _markVersion = 0; //勾记变更计数，纳入缓存键后无需手动置空 _pageKey
  bool _dictGuideScheduled = false; //查词典引导每个页面实例只调度一次

  /// 本词书内已收藏的单词 id（跨词库全局收藏，这里只取本书的）
  Set<int> _favoriteIds = {};

  /// 本轮排版时生效的标记设置（行首图标 / 行底色 / 行尾星标）。
  /// 与勾记一样，它们会影响词条的可用宽度或高度，故一并纳入分页缓存键
  /// （见 [_paginate]），设置一变就自动重排，不需要额外的监听。
  bool _paginateMarkIcon = true;
  bool _paginateMarkRow = false;
  bool _paginateFavoriteStar = true;

  /// 移动端是否显示顶栏 / 底栏（小说式沉浸交互）。
  ///
  /// 进入阅读页默认干净阅读（只有单词和释义），点击屏幕中间才唤出
  /// 顶栏（返回 / 书签 / 设置）与底栏（目录 / 夜间 / 标记 / 设置），
  /// 再点一次或翻页就收起 —— 与番茄、七猫、起点等小说 App 一致。
  /// 桌面端与移动端同一套逻辑：点击中间区域唤出/收起，翻页自动收起。
  bool _controlsVisible = false;

  /// 查词典引导的高亮锚点：提示弹出前锁定一次，之后不再跟随翻页移动。
  ///
  /// 同一个 GlobalKey 在同一帧里从某个词条换到另一个词条会触发
  /// 「Multiple widgets used the same GlobalKey」，所以锚点只赋值一次，
  /// 且只有锚点对应的那个词条会挂 Key，同一时刻始终只有一个持有者。
  int? _dictGuideAnchorIndex;
  Timer? _saveTimer;

  // ========== 增量排版状态 ==========
  //大词书一次性测量上千词条会卡死首帧，改为按帧预算续排
  bool _paginating = false;
  bool _paginateFrameScheduled = false;
  int _paginateFrom = 0; //下一个待排版的词索引
  double _paginateH = 0; //当前页已累计高度
  List<_ReaderSeg> _paginateCur = []; //当前页已收集的词条段
  double _paginateWidth = 0;
  double _paginateHeight = 0;
  double _paginateFont = 16;
  double _paginateSpacing = 1.0; //行段间距倍率（本轮排版生效）
  double _paginateMargin = _hPad; //页面左右边距（本轮排版生效）
  TextStyle? _styleWord;
  TextStyle? _stylePhonetic;
  TextStyle? _styleDef;
  //每个 TextStyle 固定绑定一个 painter，切换文本不会触发度量模板重建
  final TextPainter _pWord = TextPainter(textDirection: TextDirection.ltr);
  final TextPainter _pPhonetic = TextPainter(textDirection: TextDirection.ltr);
  final TextPainter _pDef = TextPainter(textDirection: TextDirection.ltr);

  int? _pendingJump; //待跳回的词索引（排版未完成时会持续重试）
  bool _initialJumpDone = false;

  //背景图存在性是同步磁盘 IO，build 中会被多次调用，按路径缓存结果
  String? _bgExistsPath;
  bool _bgExistsValue = false;

  @override
  void initState() {
    super.initState();
    //监听生命周期：手机把应用切到后台后可能被系统直接回收，
    //那时 dispose 不保证执行，翻页防抖里没落盘的进度就丢了
    WidgetsBinding.instance.addObserver(this);
    _load();
    if (isAndroidPlatform) {
      _volumeChannel.setMethodCallHandler(_onVolumeCall);
      //恢复持久化的音量键开关，dispose 时原生侧会被重置为关
      _syncVolumeTurn(context.read<ReaderSettingsProvider>().volumeTurnEnabled);
    }
  }

  /// 退到后台时立刻把阅读进度落盘（Android 上应用可能不再回到前台）。
  ///
  /// 回到前台时把音量键拦截重新下发一次：原生侧在 onPause 里会主动解除
  /// （避免通道消息丢失后应用在全局吞掉音量键且无法自愈），
  /// 因此恢复前台后需要按当前设置重新打开。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveTimer?.cancel();
      _saveNow();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _syncVolumeTurn(context.read<ReaderSettingsProvider>().volumeTurnEnabled);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _saveNow();
    if (isAndroidPlatform) {
      _volumeChannel.setMethodCallHandler(null);
      unawaited(_volumeChannel.invokeMethod('setEnabled', {'enabled': false}));
    }
    _focusNode.dispose();
    _pageController.dispose();
    _pWord.dispose();
    _pPhonetic.dispose();
    _pDef.dispose();
    //释放大列表内存，加速词书页恢复
    _words = [];
    _markedIds = {};
    _bookmarks = [];
    _pages = [];
    super.dispose();
  }

  Future<void> _load() async {
    final di = context.read<DIContainer>();
    final dao = DatabaseService.readerDao;
    try {
      // 正文（词表 + 词库信息）是必需数据；勾记/书签/进度/收藏属辅助数据，
      // 任一失败只降级为空值——此前 6 个查询共用一个 Future.wait，收藏
      // 查询失败会连带吞掉整本书内容，整页退化成一个"空词书"
      // 非泛型版本：泛型 T 在 Future.wait 的上下文中会被向下推断成 Object，
      // 导致 Future<int?> 之类的实参不匹配
      Future<Object?> optional(Future<Object?> future) async {
        try {
          return await future;
        } catch (e) {
          debugPrint('阅读器辅助数据加载失败（降级为空）：$e');
          return null;
        }
      }

      //6 个查询互不依赖，串行 await 会把首屏时间累加，改为并行发起
      final res = await Future.wait<Object?>([
        di.wordRepository.getWordsByBook(widget.bookId),
        optional(dao.getMarkedWordIds(widget.bookId)),
        optional(dao.getBookmarks(widget.bookId)),
        optional(dao.getProgress(widget.bookId)),
        di.wordBookRepository.getWordBook(widget.bookId),
        //收藏沿用本文件既有风格：直接走静态 DAO，与勾记/书签/进度一致
        optional(
          DatabaseService.favoriteDao.getFavoriteWordIdsInBook(widget.bookId),
        ),
      ]);
      final words = (res[0] as List<Word>?) ?? const <Word>[];
      final marked = (res[1] as Set<int>?) ?? const <int>{};
      final bookmarks =
          (res[2] as List<ReaderBookmark>?) ?? const <ReaderBookmark>[];
      final progress = res[3] as int?;
      final book = res[4] as WordBook?;
      final favorites = (res[5] as Set<int>?) ?? const <int>{};
      if (!mounted) return;
      setState(() {
        _words = words;
        _markedIds = marked;
        _favoriteIds = favorites;
        _bookmarks = bookmarks;
        _currentWordIndex = (progress ?? 0).clamp(
          0,
          words.isEmpty ? 0 : words.length - 1,
        );
        // 旧书签没有 word_text 快照：后台回填，成功后刷新面板。
        // 不阻塞首帧；回填失败也不影响阅读。
        unawaited(_backfillBookmarkTextsIfNeeded());
        //英文界面下内置词库显示英文名（仅显示层翻译，不影响数据）。
        //这里用 read 而不是扩展里的 select：_load 由 initState 调用，
        //不在 build 内，context.select 会直接触发 provider 断言。
        _bookName = book == null
            ? ''
            : localizeWordBookName(
                book.name,
                context.read<ThemeProvider>().isEnglishLocale,
              );
        _loading = false;
      });
      // 刚读出来的进度就是"已落盘"的状态，避免进入页面后立刻又原样写回一次
      _lastSavedWordIndex = _currentWordIndex;
    } catch (e) {
      debugPrint('WordbookReaderScreen._load error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// 上一次已落盘的词下标：避免退出/退后台时把刚写过的同一条进度再写一遍。
  /// 阅读页是这份进度的唯一写入者，所以「下标没变 = 数据没变」成立。
  int? _lastSavedWordIndex;

  void _saveNow() {
    if (_words.isEmpty) return;
    // 翻页去抖写完 500ms 后退出页面会再写一次同样的值（退后台同理），
    // 每次都是一次 upsert 事务 + fsync，这里直接跳过重复写
    if (_lastSavedWordIndex == _currentWordIndex) return;
    _lastSavedWordIndex = _currentWordIndex;
    unawaited(
      DatabaseService.readerDao.saveProgress(
        bookId: widget.bookId,
        wordIndex: _currentWordIndex,
      ),
    );
  }

  // ========== 分页：像小说排版，由字体大小/粗细决定每页词数 ==========

  /// 排版入口。缓存键变化才重排，且大词书按帧预算续排，避免首帧被测量卡死
  void _paginate(BoxConstraints c, ReaderSettingsProvider s, double topInset) {
    final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
    //标记设置签名也进缓存键：行首图标/行尾星标占宽度、行底色加内边距，
    //设置一变必须重排，否则页尾会被裁掉
    //底部避让用 padding 而非 viewPadding：Android 沉浸式（immersiveSticky）
    //下导航栏/手势条默认隐藏，padding.bottom 随之归零，而 viewPadding.bottom
    //恒为原始栏高，用它会在页尾白白多留一截空白
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final key =
        '${c.maxWidth}|${c.maxHeight}|${s.fontSize}|${s.fontWeightIndex}|$scale|'
        '$_markVersion|${s.markStyleSignature}|$bottomInset|$topInset|'
        '${s.spacingScale}|${s.pageMargin}';
    if (key != _pageKey) {
      _pageKey = key;
      final reflow = _pages.isNotEmpty;
      _resetPaginate(c, s, topInset, scale);
      //重排后页码会变，记下要回到的词，排完（或排到该词）再跳回
      if (reflow) _pendingJump = _currentWordIndex;
      //首帧多给预算，保证 PageView 立刻有可翻内容
      _paginateChunk(const Duration(milliseconds: 16));
    }
    //续排统一交给帧回调：若在 build 里续排，每帧都要「setState → build → 测量」，
    //等于把排版成本翻倍到构建阶段
    if (_paginating) {
      _requestPaginateFrame();
    } else if (_pendingJump != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryJump());
    }
  }

  void _resetPaginate(
    BoxConstraints c,
    ReaderSettingsProvider s,
    double topInset,
    double scale,
  ) {
    final fs = s.fontSize;
    final fw = s.fontWeight;
    _paginateFont = fs;
    //行段间距倍率与页面边距纳入排版：倍率同时作用于行高与词条间距，
    //边距决定每行可用宽度，二者一变必须与 _pageContent/_entry 同源，否则页尾被裁
    _paginateSpacing = s.spacingScale;
    _paginateMargin = s.pageMargin;
    //标记样式决定词条宽度/高度，必须与排版测量同源，否则测量与渲染会不一致
    _paginateMarkIcon = s.rememberedMarkIcon;
    _paginateMarkRow = s.rememberedMarkRow;
    _paginateFavoriteStar = s.showFavoriteStar;
    _paginateWidth = c.maxWidth - _paginateMargin * 2;
    // 可用高度必须与 _pageContent 的实际 padding 严格同源：
    // 顶部占 topInset + _pageTopGap，底部占 _vPad + padding.bottom，
    // 只留 4 吸收 TextPainter 与渲染的字号缩放误差。
    // 此前测量按 16 预留、渲染只占 4，每页凭空少放一截内容，页尾就空出来
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    _paginateHeight =
        c.maxHeight -
        (topInset + _pageTopGap) -
        _vPad -
        bottomInset -
        _measureSlack;
    //整轮排版内样式对象保持不变，复用可避免每词重复分配 TextStyle
    //行高乘以间距倍率，与 _entry 渲染同源
    final lh = 1.35 * _paginateSpacing;
    _styleWord = TextStyle(
      fontSize: (fs + 4) * scale,
      fontWeight: fw,
      height: lh,
      color: Colors.black,
    );
    _stylePhonetic = TextStyle(
      fontSize: (fs - 2) * scale,
      fontWeight: fw,
      height: lh,
      color: Colors.black,
    );
    _styleDef = TextStyle(
      fontSize: fs * scale,
      fontWeight: fw,
      height: lh,
      color: Colors.black,
    );
    _paginateFrom = 0;
    _paginateH = 0;
    _paginateCur = [];
    _pages = [];
    _paginating = _words.isNotEmpty;
  }

  /// 在给定时间预算内尽量多排版词条；未排完时下一帧继续
  ///
  /// 词条按释义的视觉行跨页拆分：当前页装不下的词条先放"单词行+能容纳的
  /// 释义行"，剩余行作为续段逐页放完，页尾不再整条挪页留出大块空白
  void _paginateChunk(Duration budget) {
    if (!_paginating) return;
    final sw = Stopwatch()..start();
    final width = _paginateWidth;
    final n = _words.length;
    while (_paginateFrom < n) {
      final i = _paginateFrom;
      final headH = _headHeight(i, width);
      final lines = _definitionLines(i, width);
      final gap = _entryGap * _paginateSpacing;
      final total =
          headH +
          lines.fold<double>(0, (s, l) => s + l.h) +
          gap +
          _segVInset(i);
      if (total <= _paginateHeight - _paginateH) {
        _pushSeg(
          _ReaderSeg(
            word: i,
            withHead: true,
            def: _words[i].definition,
            tail: true,
            height: total,
          ),
        );
        _paginateFrom++;
      } else {
        _splitEntry(i, headH, lines, gap);
      }
      //每 32 词检查一次预算，Stopwatch 读数本身也有开销
      if ((_paginateFrom & 31) == 0 && sw.elapsed >= budget) return;
    }
    _flushPage();
    _paginating = false;
  }

  void _pushSeg(_ReaderSeg seg) {
    _paginateCur.add(seg);
    _paginateH += seg.height;
  }

  void _flushPage() {
    if (_paginateCur.isEmpty) return;
    _pages.add(_ReaderPage(_paginateCur));
    _paginateCur = [];
    _paginateH = 0;
  }

  /// 拆分一个装不进当前页的词条：当前页放头部段（单词行+音标+若干释义行），
  /// 剩余行逐页放续段；每个新页从空页开始，直到该词放完
  void _splitEntry(
    int i,
    double headH,
    List<({String text, double h})> lines,
    double gap,
  ) {
    final vInset = _segVInset(i);
    final firstLineH = lines.isEmpty ? 0.0 : lines.first.h;
    //当前页有内容且连"头部+首行"都放不下：先封页，从空页开始拆
    if (_paginateCur.isNotEmpty &&
        _paginateHeight - _paginateH < headH + vInset + firstLineH) {
      _flushPage();
    }
    var avail = _paginateHeight - _paginateH;
    var h = headH + vInset;
    var k = 0;
    //逐行累加；末行额外预留词条间距
    while (k < lines.length &&
        h + lines[k].h <= avail - (k + 1 == lines.length ? gap : 0)) {
      h += lines[k].h;
      k++;
    }
    //至少保证一行释义跟着头部走（超长单词行除外：此时允许溢出）
    if (k == 0 && lines.isNotEmpty && h + lines.first.h <= avail) {
      h += lines.first.h;
      k = 1;
    }
    _pushSeg(
      _ReaderSeg(
        word: i,
        withHead: true,
        def: _joinLines(lines.take(k)),
        tail: k == lines.length,
        height: h + (k == lines.length ? gap : 0),
      ),
    );
    if (k == lines.length) {
      _paginateFrom++;
      return;
    }
    var rest = lines.sublist(k);
    while (true) {
      _flushPage();
      var hh = vInset;
      var j = 0;
      while (j < rest.length &&
          hh + rest[j].h <=
              _paginateHeight - (j + 1 == rest.length ? gap : 0)) {
        hh += rest[j].h;
        j++;
      }
      //空页连一行都放不下（异常数据）：强制放一行防死循环
      if (j == 0) {
        hh += rest.first.h;
        j = 1;
      }
      _paginateCur.add(
        _ReaderSeg(
          word: i,
          withHead: false,
          def: _joinLines(rest.take(j)),
          tail: j == rest.length,
          height: hh + (j == rest.length ? gap : 0),
        ),
      );
      _paginateH = hh + (j == rest.length ? gap : 0);
      if (j == rest.length) {
        _paginateFrom++;
        return;
      }
      rest = rest.sublist(j);
    }
  }

  /// 释义按视觉行拆开：返回每行的原文与行高（用 LineMetrics 实测行高，
  /// 与渲染端逐行一致）。行边界用 getPositionForOffset 在下一行顶部
  /// （x=0，左对齐文本落在行首字符之前）探测。
  /// 测量宽度与渲染同源：释义在图标 Row 之外，只扣「行底色」左右内边距
  List<({String text, double h})> _definitionLines(int i, double width) {
    final def = _words[i].definition;
    if (def.isEmpty) return const [];
    final inset = (_markedIds.contains(_words[i].id) && _paginateMarkRow)
        ? _markRowPadding
        : 0.0;
    _pDef.text = TextSpan(text: def, style: _styleDef!);
    _pDef.layout(maxWidth: width - inset * 2);
    final metrics = _pDef.computeLineMetrics();
    if (metrics.isEmpty) return const [];
    final lines = <({String text, double h})>[];
    var y = 0.0;
    var start = 0;
    for (var li = 0; li < metrics.length; li++) {
      final m = metrics[li];
      //下一行垂直中点处 x=0 探测行首字符（左对齐落在行首），比取行边界更稳；
      //最后一行直接到文本末尾
      final int probe;
      if (li == metrics.length - 1) {
        probe = def.length;
      } else {
        final nextMid = y + m.height + metrics[li + 1].height / 2;
        probe = _pDef.getPositionForOffset(Offset(0, nextMid)).offset;
      }
      final end = probe > start ? probe : start;
      //行尾换行符/空格去掉：拆分后行与行之间的换行由分段本身表达，
      //保留会让续段渲染出多余空行
      final text = def.substring(start, end).replaceAll(RegExp(r'\s+$'), '');
      lines.add((text: text, h: m.height));
      start = end;
      y += m.height;
    }
    return lines;
  }

  String _joinLines(Iterable<({String text, double h})> lines) =>
      lines.map((l) => l.text).join('\n');

  /// 「行底色」标记给每段加的内边距（头部段与续段都有底色容器）
  double _segVInset(int i) =>
      (_markedIds.contains(_words[i].id) && _paginateMarkRow)
      ? _markRowPadV * 2
      : 0.0;

  /// 词条头部高度：单词行 + 音标行（释义单独按行测量）
  double _headHeight(int i, double width) {
    final w = _words[i];
    final marked = _markedIds.contains(w.id);
    final favorited = _favoriteIds.contains(w.id);
    //行首勾记图标 / 行尾收藏星标会挤占单词行宽度，「行底色」还会加左右内边距；
    //测量不扣除的话长单词实际换行数会算少，导致页尾被裁
    var iconW = 0.0;
    if (marked && _paginateMarkIcon) {
      iconW += (_paginateFont + 4) * 0.8 + 6;
    }
    if (favorited && _paginateFavoriteStar) {
      iconW += (_paginateFont + 2) * 0.9 + 6;
    }
    final inset = (marked && _paginateMarkRow) ? _markRowPadding : 0.0;
    final contentW = width - iconW - inset * 2;
    var h = _measure(_pWord, w.word, _styleWord!, contentW);
    if (w.phonetic.isNotEmpty) {
      h += _measure(_pPhonetic, w.phonetic, _stylePhonetic!, contentW);
    }
    return h;
  }

  void _requestPaginateFrame() {
    if (_paginateFrameScheduled) return;
    _paginateFrameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _paginateFrameScheduled = false;
      if (!mounted || !_paginating) return;
      //在帧回调里续排，只在「排完」或「新排出了页」时重建，
      //避免每帧一次无意义的空 setState
      final pageCountBefore = _pages.length;
      _paginateChunk(const Duration(milliseconds: 6));
      if (!_paginating || _pages.length != pageCountBefore) {
        setState(() {});
      }
      if (_paginating) _requestPaginateFrame();
    });
  }

  /// 复用固定样式的 TextPainter：只换文本内容，不重建排版模板
  double _measure(TextPainter p, String text, TextStyle style, double width) {
    if (text.isEmpty) return 0;
    p.text = TextSpan(text: text, style: style);
    p.layout(maxWidth: width);
    return p.height;
  }

  // ========== 颜色 ==========

  bool _hasImage(ReaderSettingsProvider s) {
    final p = s.bgImagePath;
    if (p == null) return false;
    //existsSync 是磁盘 IO，一帧内会被多处调用，按路径缓存
    if (p != _bgExistsPath) {
      _bgExistsPath = p;
      _bgExistsValue = reader_bg.readerBgFileExists(p);
    }
    return _bgExistsValue;
  }

  double? _bgPxFor;
  int _bgPxValue = 0;

  /// 壁纸解码宽度（物理像素），按视口宽度缓存，避免每帧重复换算
  int _bgPixels(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w != _bgPxFor) {
      _bgPxFor = w;
      _bgPxValue = (w * MediaQuery.devicePixelRatioOf(context)).round().clamp(
        1,
        4096,
      );
    }
    return _bgPxValue;
  }

  bool _isLightBg(ReaderSettingsProvider s) =>
      _hasImage(s) ? false : s.bgColor.computeLuminance() >= 0.5;

  Color _textColor(ReaderSettingsProvider s) {
    if (s.textColor != null) return s.textColor!;
    return _hasImage(s) || !_isLightBg(s)
        ? Colors.white
        : const Color(0xFF1A1A1A);
  }

  Color _subColor(ReaderSettingsProvider s) =>
      _textColor(s).withValues(alpha: 0.72);

  // ========== 构建 ==========

  @override
  Widget build(BuildContext context) {
    //只订阅影响阅读器外观的设置：书签命名、音量键等变化不再触发整页重建
    context.select<ReaderSettingsProvider, int>((p) => p.renderSignature);
    final s = context.read<ReaderSettingsProvider>();
    final fg = _textColor(s);
    //底栏是在 LayoutBuilder 的 builder 里构造的，那里不能调用 context.select
    //（provider 会断言"只能在 build 方法内使用"），所以在 build 里先取好再传下去
    final controlsGlass = context.select<ThemeProvider, bool>(
      (p) => p.isLiquidGlass,
    );
    //阅读区背景完全由阅读器设置决定：图片 > 纯色，不跟随 App 主题
    //ScrollConfiguration 关掉 overscroll：Android 的下拉越界拉伸看起来
    //像在"刷新"，与沉浸阅读的预期冲突（用户要求阅读页不要下拉刷新）
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: Scaffold(
        backgroundColor: _hasImage(s) ? Colors.black : s.bgColor,
        //顶栏不再挂 Scaffold.appBar：那会让 body 整体下移一条工具栏高度，
        //页首凭空多出一大块空白。改为浮层覆盖在内容上（小说 App 逻辑：
        //唤出时盖住部分文字，收起后内容顶边紧贴状态栏下沿）
        body: _loading
            ? Center(child: CircularProgressIndicator(color: fg))
            : _words.isEmpty
            ? Center(
                child: Text(
                  context.tr.emptyBookDesc,
                  style: TextStyle(color: _subColor(s), fontSize: 15),
                ),
              )
            : _buildBody(s, controlsGlass, fg),
      ),
    );
  }

  Widget _readerAppBar(ReaderSettingsProvider s, Color fg, bool glass) {
    final tr = context.tr;
    //只显示词书名称：原「名称 · 第x/y页」在窄屏上被截断成半个书名，
    //页码信息底栏已有，标题保持一本书名最清晰
    final title = _bookName.isEmpty ? tr.readerMode : _bookName;
    //顶栏是浮层（不占布局高度），唤出时正文会从下面透出来与标题叠在一起，
    //标题因此完全读不清。这里给顶栏铺一层与阅读背景同色的压底色，
    //底边用渐变淡出，既盖住正文又不出现生硬的横边。
    //壁纸背景时用半透明黑（纯阅读底色会被壁纸"看穿"，标题仍然糊）。
    final scrim = _hasImage(s)
        ? Colors.black.withValues(alpha: 0.72)
        : s.bgColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scrim, scrim, scrim.withValues(alpha: 0)],
          stops: const [0.0, 0.84, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Stack(
            alignment: Alignment.center,
            children: [
              //标题居中于整栏，不受两侧按钮数量差影响
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 96),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: _barButton(
                  glass: glass,
                  icon: Icons.arrow_back,
                  tooltip: tr.back,
                  onPressed: () => Navigator.pop(context),
                  s: s,
                  fg: fg,
                ),
              ),
              //书签/添加书签与底栏重复，顶栏只保留返回：
              //顶栏是浮层，少两个按钮也让标题可用宽度更大
            ],
          ),
        ),
      ),
    );
  }

  ///顶栏图标按钮：玻璃风格用 GlassSurface 胶囊（材质明暗跟随阅读背景），
  ///流体风格用半透明渐变底
  Widget _barButton({
    required bool glass,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required ReaderSettingsProvider s,
    required Color fg,
  }) {
    final darkSurface = !_isLightBg(s);
    final button = IconButton(
      //显式固定图标色：玻璃主题的 appBarTheme.iconTheme 会覆盖 AppBar 的
      //foregroundColor，深色模式下变白并融入浅色阅读背景导致不可见
      icon: Icon(icon, color: fg),
      iconSize: 22,
      onPressed: onPressed,
      tooltip: tooltip,
      color: fg,
      highlightColor: fg.withValues(alpha: 0.12),
    );
    if (glass) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GlassSurface(
          darkSurface: darkSurface,
          borderRadius: 18,
          // 44dp：顶栏按钮在手机上要够大才好点（原先 40dp 略显局促）
          child: SizedBox(width: 44, height: 44, child: button),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: darkSurface
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06),
          border: Border.all(
            color: darkSurface
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.10),
          ),
        ),
        child: button,
      ),
    );
  }

  Widget _buildBody(ReaderSettingsProvider s, bool glassControls, Color fg) {
    //方向键/空格翻页是键盘特性，只在桌面端挂载；移动端完全触摸操作
    final desktop = PlatformAdapt.isDesktop;
    return Focus(
      focusNode: _focusNode,
      autofocus: desktop,
      onKeyEvent: desktop ? _onKeyEvent : null,
      child: Listener(
        //桌面端鼠标滚轮翻页
        onPointerSignal: PlatformAdapt.isDesktop ? _onPointerSignal : null,
        child: LayoutBuilder(
          builder: (context, c) {
            // 用 paddingOf / sizeOf 而不是 of(context)：LayoutBuilder 的 builder
            // 每次布局都会执行，而 of(context) 依赖整份 MediaQueryData
            // （键盘、字号、方向），会让这里的重新布局与 _paginate 更频繁触发
            // 顶部避让只传纯状态栏/挖孔高度：页首额外留白由 _pageTopGap
            // 统一控制（测量与渲染同源）。顶栏是浮层不占布局高度，
            // 唤出时盖住部分文字（小说 App 逻辑）；桌面端同样默认收起，
            // 不再为常驻顶栏预留工具栏高度
            final topInset = MediaQuery.paddingOf(context).top;
            //左右翻页区/中央手势区宽度只取决于屏幕宽，取一次复用
            final screenWidth = MediaQuery.sizeOf(context).width;
            _paginate(c, s, topInset);
            _scheduleDictGuide();
            if (!_initialJumpDone) {
              _initialJumpDone = true;
              _jumpToWord(_currentWordIndex);
            }
            //按屏幕物理像素解码壁纸，避免原图直出导致模糊/重绘开销过大
            final bgPx = _bgPixels(context);
            return Stack(
              children: [
                if (_hasImage(s))
                  Positioned.fill(
                    //壁纸层独立重绘，翻页与文字变化不再连带重算高斯模糊
                    child: RepaintBoundary(
                      child: Stack(
                        children: [
                          //景深：对壁纸做高斯模糊
                          Positioned.fill(
                            child: s.bgBlur > 0.1
                                ? ImageFiltered(
                                    imageFilter: ImageFilter.blur(
                                      sigmaX: s.bgBlur,
                                      sigmaY: s.bgBlur,
                                      tileMode: TileMode.decal,
                                    ),
                                    child: reader_bg.readerBgImage(
                                      s.bgImagePath!,
                                      cacheWidth: bgPx,
                                    ),
                                  )
                                : reader_bg.readerBgImage(
                                    s.bgImagePath!,
                                    cacheWidth: bgPx,
                                  ),
                          ),
                          //压暗蒙层保证文字可读，透明度可调
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(
                                alpha: s.bgOverlay,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                _pageListView(s, topInset),
                //点击屏幕左右区域翻页
                if (s.tapTurnEnabled) ...[
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: screenWidth * 0.3,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _turnPage(-1),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: screenWidth * 0.3,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _turnPage(1),
                    ),
                  ),
                ],
                //屏幕中间：切换顶栏 / 底栏显隐（小说式沉浸交互）。
                //关掉「点击翻页」时整屏都是切换区，仍然点得出来。
                //桌面端用鼠标点击同一区域，行为与移动端一致。
                Positioned(
                  left: s.tapTurnEnabled ? screenWidth * 0.3 : 0,
                  right: s.tapTurnEnabled ? screenWidth * 0.3 : 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                  ),
                ),
                //小说式底部工具栏：与顶栏联动显隐
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: AnimatedSlide(
                      offset: _controlsVisible
                          ? Offset.zero
                          : const Offset(0, 1),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: _controlsVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: _readerBottomBar(
                          s,
                          _textColor(s),
                          glassControls,
                        ),
                      ),
                    ),
                  ),
                ),
                //顶栏浮层：覆盖在内容之上（不占布局高度），与底栏联动显隐。
                //放在 Stack 最后保证按钮优先命中；收起时 IgnorePointer 让点击穿透
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: AnimatedSlide(
                      offset: _controlsVisible
                          ? Offset.zero
                          : const Offset(0, -1),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: _controlsVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: _readerAppBar(s, fg, glassControls),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pageListView(ReaderSettingsProvider s, double topInset) {
    final curl = s.pageTransition == ReaderPageTransition.curl;
    //整页共用的颜色在此算一次，避免每个词条重复推导
    final fg = _textColor(s);
    final sub = _subColor(s);
    final lightBg = _isLightBg(s);
    final curlBack = lightBg
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF424242);
    return PageView.builder(
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (_, index) {
        // s 由外层传入：每个词条都自己 context.read 一次会向上遍历元素树
        final content = _pageContent(index, topInset, fg, sub, lightBg, s);
        if (!curl) return content;
        //每页独立监听 controller，拖拽过程中折叠线才能连续动画
        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) => ReaderCurlPage(
            index: index,
            page: _pageController.hasClients
                ? (_pageController.page ?? index.toDouble())
                : index.toDouble(),
            backColor: curlBack,
            child: child!,
          ),
          child: content,
        );
      },
    );
  }

  Widget _pageContent(
    int page,
    double topInset,
    Color fg,
    Color sub,
    bool lightBg,
    ReaderSettingsProvider s,
  ) {
    if (page < 0 || page >= _pages.length) return const SizedBox.shrink();
    final segs = _pages[page].segs;
    return Padding(
      padding: EdgeInsets.only(
        //与 _resetPaginate 的可用高度同源：topInset + _pageTopGap
        top: topInset + _pageTopGap,
        //左右边距与测量同源（页面边距可调）
        left: s.pageMargin,
        right: s.pageMargin,
        //与分页测量保持一致：底部避让用 padding（沉浸式下导航栏隐藏时归零）
        bottom: _vPad + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final seg in segs) _seg(seg, fg, sub, lightBg, s)],
      ),
    );
  }

  Widget _seg(
    _ReaderSeg seg,
    Color fg,
    Color sub,
    bool lightBg,
    ReaderSettingsProvider s,
  ) {
    final i = seg.word;
    final w = _words[i];
    final marked = _markedIds.contains(w.id);
    final favorited = _favoriteIds.contains(w.id);
    final def = seg.def;
    final fs = s.fontSize;
    final fw = s.fontWeight;
    final defColor = fg.withValues(alpha: 0.88);
    //「记住了」的三种标记方式彼此独立：行首图标 / 整行底色 / 单词文字变色，
    //可以只开一种，也能三种全开（在阅读设置的「标记」分区里调）
    final markColor = s.markColor(lightBg);
    final showMarkIcon = marked && s.rememberedMarkIcon && seg.withHead;
    final tintRow = marked && s.rememberedMarkRow;
    //「文字变色」按整行生效：只染单词而放着音标与释义不管，视觉上像只改了一半，
    //读起来割裂。这里让单词 / 音标 / 释义一起换成标记色。
    final markText = marked && s.rememberedMarkWord;
    final wordColor = markText ? markColor : fg;
    final phoneticColor = markText ? markColor : sub;
    final definitionColor = markText ? markColor : defColor;
    // 收藏星标：与「记住了」刻意用不同位置与颜色区分，
    // 绿色对勾=已掌握，金色星标=想再看
    final showStar = favorited && s.showFavoriteStar && seg.withHead;
    //行高与词条间距随「行段间距」倍率缩放（与测量同源）
    final lh = 1.35 * s.spacingScale;

    return GestureDetector(
      //引导锚点：整个阅读器只有一个词条会挂这个 Key（见 _dictGuideAnchorIndex），
      //只挂在头部段上，续段不重复挂
      key: (seg.withHead && i == _dictGuideAnchorIndex)
          ? guideReaderDictKey
          : null,
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (d) => _showEntryMenu(i, d.globalPosition),
      onSecondaryTapUp: (d) => _showEntryMenu(i, d.globalPosition),
      child: Padding(
        //续段与下一段之间不加间距：它们与下一页的首段同属一个词条
        padding: EdgeInsets.only(
          bottom: seg.tail ? _entryGap * s.spacingScale : 0,
        ),
        child: Container(
          decoration: tintRow
              ? BoxDecoration(
                  color: markColor.withValues(alpha: lightBg ? 0.10 : 0.18),
                  //续段接在上一页下方：上圆角改直，视觉上连成一块底色
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(seg.withHead ? 8 : 0),
                    bottom: Radius.circular(seg.tail ? 8 : 0),
                  ),
                )
              : null,
          padding: EdgeInsets.symmetric(
            horizontal: tintRow ? _markRowPadding : 0,
            vertical: tintRow ? _markRowPadV : 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (seg.withHead)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showMarkIcon)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.check_circle,
                          color: markColor,
                          size: (fs + 4) * 0.8,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        w.word,
                        style: TextStyle(
                          fontSize: fs + 4,
                          fontWeight: fw,
                          color: wordColor,
                          height: lh,
                        ),
                      ),
                    ),
                    if (showStar)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.star,
                          color: FluidTheme.favorite,
                          size: (fs + 2) * 0.9,
                        ),
                      ),
                  ],
                ),
              if (seg.withHead && w.phonetic.isNotEmpty)
                Text(
                  w.phonetic,
                  style: TextStyle(
                    fontSize: fs - 2,
                    color: phoneticColor,
                    height: lh,
                  ),
                ),
              if (def.isNotEmpty)
                Text(
                  def,
                  style: TextStyle(
                    fontSize: fs,
                    color: definitionColor,
                    height: lh,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 上下文引导 ==========

  /// 排版出内容后调度一次「长按查词典」引导（每个页面实例只调度一次）
  void _scheduleDictGuide() {
    if (_dictGuideScheduled) return;
    _dictGuideScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDictGuide();
    });
  }

  /// 首次进入阅读页：介绍词条菜单（记住了 / 收藏 / 书签 / 查词典）
  /// 以及顶栏的书签与阅读设置入口。
  ///
  /// 高亮目标挂在当前阅读位置的那个词条上（见 [_entry]），
  /// 只提示一次；开屏未结束时会留到下次进入再提示。
  Future<void> _showDictGuide() async {
    if (!mounted || _words.isEmpty) return;
    await CoachMarkOverlay.maybeShowAfterSplash(
      context,
      guideId: GuideService.tipReaderFeatures,
      //弹出前锁定高亮锚点，避免提示期间翻页把同一个 Key 换到别的词条上
      onBeforeShow: () {
        if (!mounted) return;
        setState(() {
          _dictGuideAnchorIndex = _currentWordIndex;
          //顶栏默认收在屏幕外，而这里的引导要指到书签 / 设置按钮上，
          //先把工具栏唤出来，否则高亮框会落在看不见的位置
          _controlsVisible = true;
        });
      },
      steps: () => [
        CoachMarkStep(
          targetKey: guideReaderDictKey,
          title: context.tr.coachReaderEntryTitle,
          message: context.tr.coachReaderEntryMsg,
          icon: Icons.touch_app_outlined,
        ),
        CoachMarkStep(
          targetKey: guideReaderDictKey,
          title: context.tr.coachReaderDictTitle,
          message: context.tr.coachReaderDictMsg,
          icon: Icons.menu_book_outlined,
        ),
        CoachMarkStep(
          targetKey: guideReaderBookmarkKey,
          title: context.tr.coachReaderBookmarkTitle,
          message: context.tr.coachReaderBookmarkMsg,
          icon: Icons.bookmark_border,
        ),
        CoachMarkStep(
          targetKey: guideReaderSettingsKey,
          title: context.tr.coachReaderSettingsTitle,
          message: context.tr.coachReaderSettingsMsg,
          icon: Icons.text_fields,
        ),
      ],
    );
  }

  // ========== 勾记 ==========

  Future<void> _showEntryMenu(int i, Offset global) async {
    final w = _words[i];
    final marked = _markedIds.contains(w.id);
    final favorited = _favoriteIds.contains(w.id);
    final v = await showFluidDialog<String>(
      context: context,
      maxWidth: 320,
      //用对话框 context 出栈，避免误弹阅读器路由
      content: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuAction(
              icon: marked ? Icons.undo : Icons.check_circle_outline,
              label: marked
                  ? context.tr.unmarkRemembered
                  : context.tr.markRemembered,
              onTap: () => Navigator.pop(ctx, 'toggle'),
            ),
            //收藏与「记住了」语义相反，刻意分开：勾记=已掌握，收藏=想再看
            _menuAction(
              icon: favorited ? Icons.star : Icons.star_border,
              label: favorited
                  ? context.tr.removeFromFavorites
                  : context.tr.addToFavorites,
              onTap: () => Navigator.pop(ctx, 'favorite'),
            ),
            _menuAction(
              icon: Icons.bookmark_add_outlined,
              label: context.tr.addBookmarkHere,
              onTap: () => Navigator.pop(ctx, 'bookmark'),
            ),
            _menuAction(
              icon: Icons.menu_book_outlined,
              label: context.tr.lookupDictionary,
              onTap: () => Navigator.pop(ctx, 'lookup'),
            ),
            //词条长按已被本菜单占用，复制走菜单而不是文本选择手势
            _menuAction(
              icon: Icons.copy_outlined,
              label: context.tr.copyWord,
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || v == null) return;
    if (v == 'lookup') {
      await showDictionaryLookupDialog(context: context, word: w.word);
      return;
    }
    if (v == 'copy') {
      await Clipboard.setData(ClipboardData(text: w.word));
      if (!mounted) return;
      _tip(context.tr.copiedToClipboard);
      return;
    }
    if (v == 'toggle') {
      final now = await DatabaseService.readerDao.toggleMark(w.id!);
      if (!mounted) return;
      //勾记图标改变词条可用宽度，递增版本号让分页缓存键自动失效
      _markVersion++;
      setState(() {
        now ? _markedIds.add(w.id!) : _markedIds.remove(w.id!);
      });
    } else if (v == 'favorite') {
      await _toggleFavorite(i);
      //_toggleFavorite 内的 mounted 守卫只保护它自己；跨过这个 async gap
      //后调用方再用 context 前必须自行复核，否则 defunct State 断言崩溃
      if (!mounted) return;
    } else if (v == 'bookmark') {
      await _addBookmark(context.read<ReaderSettingsProvider>(), i);
    }
  }

  /// 收藏 / 取消收藏当前词条
  ///
  /// 收藏是单词级、跨词库全局唯一的，与学习模式顶栏星标共用同一条数据。
  Future<void> _toggleFavorite(int i) async {
    final wordId = _words[i].id;
    if (wordId == null) return;
    try {
      final now = await DatabaseService.favoriteDao.toggle(
        wordId,
        source: FavoriteSource.reader.name,
      );
      if (!mounted) return;
      //星标会占用单词行宽度，递增版本号让分页缓存键自动失效
      _markVersion++;
      setState(() {
        now ? _favoriteIds.add(wordId) : _favoriteIds.remove(wordId);
      });
    } catch (e) {
      debugPrint('WordbookReaderScreen._toggleFavorite error: $e');
    }
  }

  Widget _menuAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: FluidTheme.primaryFluidGradient[0]),
      title: Text(label),
      onTap: onTap,
    );
  }

  // ========== 键盘与滚轮翻页 ==========

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      _turnPage(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      _turnPage(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      _turnPage(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      _turnPage(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 滚轮翻页的节流时间戳：触控板/高精度滚轮一次物理滑动会产生几十个
  /// PointerScrollEvent（惯性滚动还会持续数百毫秒），不节流会连翻几十页
  DateTime? _lastScrollTurnAt;

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;
    final now = DateTime.now();
    final last = _lastScrollTurnAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 180)) {
      return;
    }
    _lastScrollTurnAt = now;
    _turnPage(dy > 0 ? 1 : -1);
  }

  Future<void> _onVolumeCall(MethodCall call) async {
    if (call.method == 'onVolumeKey') {
      //原生侧传参异常（null/类型不符）时静默忽略，避免未捕获异常
      final args = call.arguments;
      if (args is! Map) return;
      final dir = args['direction'];
      if (dir is! int) return;
      _turnPage(dir);
    }
  }

  void _syncVolumeTurn(bool enabled) {
    if (!isAndroidPlatform) return;
    unawaited(_volumeChannel.invokeMethod('setEnabled', {'enabled': enabled}));
  }

  // ========== 翻页与进度 ==========

  void _onPageChanged(int page) {
    if (_pages.isEmpty) return;
    // 排版重建中（改字号/字体/边距，或在 Windows 上拖动窗口改尺寸）：
    // _pages 被清空重建，PageView 的 pixels 越界会被框架 clamp 到第 0 页
    // 并回调这里 —— 此时若记账并落盘，阅读进度会被写回开头
    if (_paginating) return;
    // 越界页码（重排瞬间的过渡态）直接忽略：clamp 兜底会把
    // _currentWordIndex 悄悄挪到末页第一个词，加书签就会加到错位置
    if (page < 0 || page >= _pages.length) return;
    final idx = _pages[page].firstWord;
    //翻页（含手势滑动、目录跳转）后收起工具栏，保持沉浸阅读
    _hideControls();
    setState(() {
      _currentPage = page;
      _currentWordIndex = idx;
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  void _turnPage(int delta) {
    if (!_pageController.hasClients) return;
    //翻页即回到干净阅读：工具栏自动收起
    _hideControls();
    final p = _pageController.page?.round() ?? 0;
    final target = p + delta;
    if (target < 0 || target >= _pages.length) return;
    final s = context.read<ReaderSettingsProvider>();
    if (s.pageTransition == ReaderPageTransition.none) {
      _pageController.jumpToPage(target);
      return;
    }
    //平滑滑动：短促的 easeOut，松手即到位；
    //仿真翻页：稍长 + easeInOut，让卷边有起势和收势，纸张感更真实
    final curl = s.pageTransition == ReaderPageTransition.curl;
    _pageController.animateToPage(
      target,
      duration: Duration(milliseconds: curl ? 380 : 240),
      curve: curl ? Curves.easeInOut : Curves.easeOutCubic,
    );
  }

  /// 跳到某个词所在页。排版尚未覆盖该词时挂起，后续分块排到后自动补跳
  void _jumpToWord(int idx) {
    if (_words.isEmpty) return;
    _pendingJump = idx.clamp(0, _words.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryJump());
  }

  void _tryJump() {
    final t = _pendingJump;
    if (t == null || _pages.isEmpty || !_pageController.hasClients) return;
    final p = _pageOfWord(t);
    if (p < 0) {
      //已排完却仍找不到（异常数据）就放弃，避免持续申请新帧
      if (!_paginating) _pendingJump = null;
      return;
    }
    _pendingJump = null;
    _pageController.jumpToPage(p);
    //跳到当前页时 onPageChanged 不会回调，这里兜底同步页码
    if (_currentPage != p && mounted) setState(() => _currentPage = p);
  }

  /// 页内索引递增，用二分代替逐页线性扫描。
  /// 跨页拆分的词会出现在多页上，命中后继续向左找，优先返回词条首页
  int _pageOfWord(int idx) {
    var lo = 0;
    var hi = _pages.length - 1;
    var ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final p = _pages[mid];
      if (idx < p.firstWord) {
        hi = mid - 1;
      } else if (idx > p.lastWord) {
        lo = mid + 1;
      } else {
        ans = mid;
        hi = mid - 1;
      }
    }
    return ans;
  }

  // ========== 书签 ==========

  String _defaultName(int idx) {
    if (idx < 0 || idx >= _words.length) return '';
    final w = _words[idx];
    var s = '${w.word} ${w.definition}'.replaceAll('\n', ' ').trim();
    return s.length > 30 ? '${s.substring(0, 30)}…' : s;
  }

  String _bookmarkName(
    ReaderBookmark b,
    int ordinal,
    ReaderSettingsProvider s,
  ) {
    final base = switch (s.naming) {
      ReaderBookmarkNaming.word => _defaultName(b.wordIndex),
      ReaderBookmarkNaming.number => '${context.tr.bookmarkLabel} $ordinal',
      ReaderBookmarkNaming.custom =>
        (b.customName != null && b.customName!.trim().isNotEmpty)
            ? b.customName!
            : _defaultName(b.wordIndex),
    };
    // 词序失效（词库重新导入/排序变化后序号指向了别的词）：在名称后附加
    // 提示，避免用户点击后被静默带到错误的词条
    return _isBookmarkOutdated(b)
        ? '$base · ${context.tr.bookmarkOutdated}'
        : base;
  }

  /// 书签序号是否已失效：创建时记录的词文本与当前序号位置的词不一致。
  /// 旧数据没有文本快照（wordText 为 null）时无从判断，按未失效处理。
  bool _isBookmarkOutdated(ReaderBookmark b) {
    final text = b.wordText;
    if (text == null) return false;
    if (b.wordIndex < 0 || b.wordIndex >= _words.length) return true;
    return _words[b.wordIndex].word != text;
  }

  /// 后台补录旧书签的 word_text 快照，之后刷新面板让它们参与失效检测。
  Future<void> _backfillBookmarkTextsIfNeeded() async {
    if (_words.isEmpty) return;
    try {
      await DatabaseService.readerDao.backfillBookmarkWordTexts(
        widget.bookId,
        _words.map((w) => w.word).toList(growable: false),
      );
      if (!mounted) return;
      final refreshed = await DatabaseService.readerDao.getBookmarks(
        widget.bookId,
      );
      if (mounted) setState(() => _bookmarks = refreshed);
    } catch (e) {
      debugPrint('回填书签词文本失败：$e');
    }
  }

  Future<void> _addBookmark(ReaderSettingsProvider s, int wordIndex) async {
    if (_words.isEmpty) return;
    final idx = wordIndex.clamp(0, _words.length - 1);
    final dao = DatabaseService.readerDao;
    final existsMsg = context.tr.bookmarkExists;
    final addedMsg = context.tr.bookmarkAdded;
    if (await dao.hasBookmarkAt(widget.bookId, idx)) {
      _tip(existsMsg);
      return;
    }
    String? name;
    if (s.naming == ReaderBookmarkNaming.custom) {
      name = await _promptName(_defaultName(idx));
      if (name == null) return; //用户取消
      if (name.trim().isEmpty) name = null;
    }
    await dao.addBookmark(
      bookId: widget.bookId,
      wordIndex: idx,
      // 记录创建时的词文本：词库重新导入/词序变化后可识别序号已失效
      wordText: _words[idx].word,
      customName: name,
    );
    _bookmarks = await dao.getBookmarks(widget.bookId);
    if (mounted) setState(() {});
    _tip(addedMsg);
  }

  /// 书签面板删除/重命名后回调宿主刷新。
  ///
  /// 面板与宿主生命周期不一致：面板直接 setState 改宿主私有字段时，
  /// 宿主已卸载就会出现"数据更新但宿主 UI 不刷"。统一走这里，mounted 守卫由宿主负责。
  void refreshBookmarks(List<ReaderBookmark> list) {
    if (!mounted) return;
    setState(() => _bookmarks = list);
  }

  Future<String?> _promptName(String? initial) {
    final controller = TextEditingController(text: initial ?? '');
    final title = context.tr.renameBookmarkBtn;
    final hint = context.tr.bookmarkNameHint;
    final cancelText = context.tr.cancel;
    final confirmText = context.tr.confirm;
    return showFluidDialog<String>(
      context: context,
      maxWidth: 400,
      title: title,
      content: Builder(
        //用对话框 context 出栈，避免误弹阅读器路由
        builder: (ctx) => TextField(
          controller: controller,
          // Android 不自动调起输入法（除拼写/听力模式外都要用户主动点击）
          autofocus: PlatformAdapt.isDesktop,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
      ),
      actions: [
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(cancelText),
          ),
        ),
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(confirmText),
          ),
        ),
      ],
    ).whenComplete(controller.dispose);
  }

  void _showBookmarks() {
    final s = context.read<ReaderSettingsProvider>();
    showFluidDialog(
      context: context,
      title: context.tr.bookmarksTitle,
      maxWidth: 480,
      scrollable: false,
      content: _BookmarkPanel(state: this, settings: s),
    );
  }

  String _fmtDate(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 阅读器内的一次性提示（复制 / 书签 / 收藏…）。
  ///
  /// 不用底部 SnackBar：它正好压在「添加书签 / 书签 / 阅读设置」那排按钮上
  /// （用户反馈"书签已添加挡住了按钮"）。改为顶部轻提示，1.6 秒后自动消失，
  /// 期间不遮挡任何操作区，也不需要用户确认。
  void _tip(String msg) => ErrorHandler.showTransientToast(context, msg);

  // ========== 阅读设置 ==========

  // ========== 小说式沉浸交互（点击屏幕唤出顶栏 / 底栏） ==========

  /// 点击屏幕中间：切换顶栏 / 底栏显隐
  void _toggleControls() {
    if (!mounted) return;
    setState(() => _controlsVisible = !_controlsVisible);
  }

  /// 翻页时自动收起工具栏：翻页即回到干净阅读（与小说 App 行为一致），
  /// 桌面端与移动端相同。
  void _hideControls() {
    if (!_controlsVisible || !mounted) return;
    setState(() => _controlsVisible = false);
  }

  /// 底栏「夜间」：在浅色 / 深色阅读背景之间一键切换
  Future<void> _toggleNightMode(ReaderSettingsProvider s) async {
    final target = _isLightBg(s)
        ? const Color(0xFF212121)
        : const Color(0xFFFFFFFF);
    //自定义文字色会盖住"按背景亮度自动推导"的颜色，换背景时一并清掉
    if (s.textColor != null) {
      await s.setTextColor(null);
    }
    await s.setBgColor(target);
    if (mounted) setState(() {});
  }

  /// 底栏「目录」：列出本词书词条，支持搜索跳转
  void _showWordList() {
    if (_words.isEmpty) return;
    final panelKey = GlobalKey<_CatalogPanelState>();
    showFluidDialog(
      context: context,
      title: context.tr.readerCatalog,
      maxWidth: 520,
      content: _CatalogPanel(
        key: panelKey,
        words: _words,
        currentIndex: _currentWordIndex,
        onJump: _jumpToWord,
      ),
      // 标题栏右侧的搜索按钮：点开在列表上方展开搜索框，按单词/释义过滤
      titleTrailing: IconButton(
        icon: Icon(Icons.search, color: FluidTheme.primaryFluidGradient[0]),
        tooltip: context.tr.searchHint,
        onPressed: () => panelKey.currentState?.toggleSearch(),
      ),
    );
  }

  /// 底栏按钮：图标 + 文字（小说 App 的通用样式）。
  ///
  /// [anchorKey] 供新手引导高亮定位（KeyedSubtree 必须放在 Expanded 内部，
  /// 否则它包住的 Expanded 不再是 Row 的直接子级，会触发 Flex 的父级断言）。
  Widget _bottomBarItem({
    required bool glass,
    required Color fg,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Key? anchorKey,
  }) {
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: fg),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
    return Expanded(
      child: anchorKey == null
          ? content
          : KeyedSubtree(key: anchorKey, child: content),
    );
  }

  /// 小说式底部工具栏：目录 / 夜间 / 添加书签 / 书签 / 阅读设置。
  ///
  /// [glass] 由 build 传入：本方法在 LayoutBuilder 的 builder 内被调用，
  /// 那里直接 context.select 会触发 provider 的"只能在 build 中订阅"断言。
  Widget _readerBottomBar(ReaderSettingsProvider s, Color fg, bool glass) {
    final darkSurface = !_isLightBg(s);
    final isLight = _isLightBg(s);
    final barFg = isLight ? const Color(0xFF1A1A1A) : Colors.white;

    final row = Row(
      children: [
        _bottomBarItem(
          glass: glass,
          fg: barFg,
          icon: Icons.format_list_bulleted,
          label: context.tr.readerCatalog,
          onTap: _showWordList,
        ),
        _bottomBarItem(
          glass: glass,
          fg: barFg,
          icon: isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          label: isLight ? context.tr.readerNight : context.tr.readerDay,
          onTap: () => _toggleNightMode(s),
        ),
        // 原「标记（记住了）」入口改为添加书签：勾记仍能在词条长按菜单里切换，
        // 而书签是阅读时更常用的动作，值得占一个底栏位置
        _bottomBarItem(
          glass: glass,
          fg: barFg,
          icon: Icons.bookmark_add,
          label: context.tr.addBookmarkBtn,
          onTap: () => _addBookmark(s, _currentWordIndex),
        ),
        //书签入口从顶栏移到底栏（顶栏与底栏功能重复，只保留返回），引导锚点跟着挪过来
        _bottomBarItem(
          glass: glass,
          fg: barFg,
          icon: Icons.bookmarks_outlined,
          label: context.tr.bookmarksTitle,
          onTap: _showBookmarks,
          anchorKey: guideReaderBookmarkKey,
        ),
        // 顶栏不再放设置按钮，底栏「阅读设置」就是唯一入口，引导锚点跟着挪过来
        _bottomBarItem(
          glass: glass,
          fg: barFg,
          icon: Icons.settings_outlined,
          label: context.tr.readerSettingsTitle,
          onTap: _showSettings,
          anchorKey: guideReaderSettingsKey,
        ),
      ],
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: glass
            ? GlassSurface(
                darkSurface: darkSurface,
                borderRadius: 20,
                child: row,
              )
            : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: darkSurface
                      ? Colors.black.withValues(alpha: 0.72)
                      : Colors.white.withValues(alpha: 0.88),
                  border: Border.all(
                    color: darkSurface
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: row,
              ),
      ),
    );
  }

  void _showSettings() {
    showFluidDialog(
      context: context,
      title: context.tr.readerSettingsTitle,
      maxWidth: 520,
      content: _ReaderSettingsPanel(
        onVolumeTurnChanged: _syncVolumeTurn,
        pickBgImage: _pickBgImage,
      ),
    );
  }

  Future<void> _pickBgImage() async {
    final pickTitle = context.tr.chooseImageBtn;
    final failMsg = context.tr.pickImageFailed;
    final f = await PickedFileHelper.pickSingleFile(
      extensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      dialogTitle: pickTitle,
    );
    if (f == null) return;
    final name = PickedFileHelper.basename(f.path);
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'png';
    final path = await reader_bg.saveReaderBackground(f, ext);
    //图片已复制到应用目录，清理选择器生成的临时副本
    await f.cleanup();
    if (path == null || !mounted) {
      _tip(failMsg);
      return;
    }
    await context.read<ReaderSettingsProvider>().setBgImage(path);
    // 旧壁纸必须等新路径**成功落盘**之后再删：先删后写时，一旦 prefs 写入
    // 失败/进程被杀，设置里仍指向已被删除的旧文件，用户壁纸静默消失
    unawaited(reader_bg.cleanOldReaderBackgrounds(keepPath: path));
  }
}
