import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_initialization_service.dart';
import '../services/asset_wordbook_service.dart';
import '../services/guide_service.dart';
import '../services/providers/providers.dart';
import '../theme/fluid_theme.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_card.dart';
import '../widgets/liquid_controls.dart';
import '../widgets/liquid_glass.dart';

/// 首次启动引导：语言 → 界面风格 → 精简介绍 → 选择词库。
///
/// 与旧版纯轮播不同，这里把「选词库」做成可操作步骤：
/// 用户带着一本已导入的词库离开引导，落在首页就能直接开始学习。
/// 全部页面同时适配流体渐变与液态玻璃两种风格。
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _OnboardingLanguage { zh, en, bilingual }

class _OnboardingScreenState extends State<OnboardingScreen> {
  /// 固定取中/英两份翻译，保证「中英一起」时两段内容始终不被应用语言影响
  static const Translations _zh = Translations(false);
  static const Translations _en = Translations(true);

  final PageController _pageController = PageController();
  int _currentPage = 0;
  _OnboardingLanguage _selectedLanguage = _OnboardingLanguage.bilingual;

  /// 每次挂载唯一的 PageStorageKey：根路由的 PageStorage 会把上一次
  /// 引导的视口位置恢复给新建的 State（_currentPage=0 但视口在末页），
  /// 表现就是"前面几页被直接跳过"；唯一 key 让恢复读不到旧值
  late final PageStorageKey<String> _pageStorageKey = PageStorageKey(
    'onboarding_${DateTime.now().microsecondsSinceEpoch}',
  );

  /// 挂载时刻：用于①延迟复查视口与页码是否脱节；②完成事件诊断
  late final DateTime _mountedAt = DateTime.now();

  /// 进场误触保护窗：引导页经常接在"初始化/确认弹窗"消失的同一瞬间
  /// 出现，上一屏残留的连点会落在跳过/下一步上，表现为"5 页引导一闪而过"。
  ///
  /// 保护窗 = 三条线**同时**到位才解除：
  /// 1. 进场后 500ms 最短窗（挡住上一屏残留连点）；
  /// 2. 开屏结束 + 300ms（引导页挂在开屏层底下，开屏中后段的点击
  ///    落在看不见的满宽「下一步」上，几发就把 5 页点完）；
  /// 3. 最后一次按下后 350ms 静默（惯性连点去抖）。固定缓冲挡不住
  ///    开屏结束后持续 1~2 秒的惯性连点 —— 真机上表现为"开屏一结束，
  ///    引导一闪即逝"；连点期间每次按下都续命，手停 350ms 才放行。
  /// 用 Timer 而不是 DateTime 差值：widget 测试的 fake-async 只推进
  /// 框架时钟，DateTime.now() 不跟着 pump 走，保护窗会永远不解除
  bool _tapGuardActive = true;

  /// 进场 500ms 最短窗已过
  bool _minGuardElapsed = false;

  /// 开屏结束 + 300ms 缓冲已过（无开屏场景直接视为已过）
  bool _splashBufferDone = false;

  /// 保护窗期间 350ms 无新按下（惯性连点去抖线）
  bool _tapGuardIdle = true;
  Timer? _tapGuardTimer;
  Timer? _splashBufferTimer;
  Timer? _tapGuardIdleTimer;

  /// 翻页忙锁：**一次按压只推进一页**。
  ///
  /// 保护窗只管进场，解除后再不上锁（见 [_handleGuardPointerDown]），
  /// 而 [_nextPage] 此前除末页导入外没有任何节流 —— 底部「下一步」又是
  /// 满宽按钮，配上 [_pageAnimDuration] 的翻页动画，连点几下就能把 5 页
  /// 引导全部点完（Android 真机反馈的"选完液态玻璃后引导一闪即逝"）。
  /// 翻页期间锁住导航，并让按钮进入禁用态给出可见反馈。
  bool _advancing = false;
  Timer? _advanceTimer;

  /// 翻页动画时长，与 [_nextPage] / [_previousPage] 共用
  static const Duration _pageAnimDuration = Duration(milliseconds: 300);

  /// 动画结束后再压一小段，防止落定瞬间的补点立刻推进下一页
  static const Duration _advanceSettle = Duration(milliseconds: 180);

  late final List<_OnboardingPage> _pages = _buildPages();

  // 内置词库选择
  bool _isLoadingBooks = true;
  List<Map<String, dynamic>> _builtInBooks = const [];
  final Set<String> _selectedBooks = {};
  bool _isImporting = false;
  int _importDone = 0;
  int _importTotal = 0;

  /// 引导阶段最多先选 3 本，避免一次性导入耗时过长
  static const int _maxBooks = 3;

  /// 步骤下标：0 风格、1 语言、2..n+1 介绍页、n+2 词库
  static const int _styleStepIndex = 0;
  static const int _languageStepIndex = 1;
  int get _wordBookStepIndex => 2 + _pages.length;
  int get _totalPages => 2 + _pages.length + 1;

  bool get _isEnglish => _selectedLanguage == _OnboardingLanguage.en;
  bool get _isLastStep => _currentPage == _totalPages - 1;

  /// 当前是否液态玻璃风格。
  ///
  /// 不能在步骤页面里直接写 `_isGlass`：它内部是 `context.select`，
  /// 而 PageView 的 itemBuilder 是在**布局阶段**被调用的，那里调用 select 会直接
  /// 触发 provider 断言（debug 下整块卡片构建中断，选中的描边框/选项内容错乱）。
  /// 在有合法订阅的 build 里取一次，后续步骤页面读这个字段即可。
  bool _isGlass = false;

  @override
  void initState() {
    super.initState();
    GuideService.logEvent(GuideService.eventStart);
    _loadBuiltInBooks();
    _setupTapGuard();
    //PageView 的滚动位置会从根路由的 PageStorage 恢复：重看引导时
    //State 是新建的（_currentPage=0），但视口却落在上次停留的末页，
    //表现就是"前面几页被直接跳过"。首帧后强制归零
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients && _pageController.page != 0) {
        _pageController.jumpToPage(0);
      }
    });
    // 延迟复查：个别机型上 PageStorage 恢复晚于首帧 post-frame（首帧时
    // page 还是 0，复查时才变成末页），一次 post-frame 兜不住；
    // 250ms 后再对齐一次视口与页码，双保险
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted || !_pageController.hasClients) return;
      final page = _pageController.page;
      if (page != null && page != _currentPage.toDouble()) {
        _pageController.jumpToPage(_currentPage);
      }
    });
  }

  /// 见 [_tapGuardActive]：进场 500ms 与「开屏结束 + 300ms」两条独立计时线，
  /// 都到位才解除保护。
  void _setupTapGuard() {
    _tapGuardTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _minGuardElapsed = true;
        _releaseTapGuardIfReady();
      });
    });
    if (AppInitializationService.splashCompleted.value) {
      // 重看引导等场景：开屏早已结束，不再等开屏这条线
      _splashBufferDone = true;
    } else {
      AppInitializationService.splashCompleted.addListener(_onSplashEnded);
    }
  }

  void _onSplashEnded() {
    if (!AppInitializationService.splashCompleted.value) return;
    AppInitializationService.splashCompleted.removeListener(_onSplashEnded);
    if (!mounted) return;
    _splashBufferTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _splashBufferDone = true;
        _releaseTapGuardIfReady();
      });
    });
  }

  /// 由 setState 回调调用：三条线都到位才真正解除
  void _releaseTapGuardIfReady() {
    if (_minGuardElapsed && _splashBufferDone && _tapGuardIdle) {
      _tapGuardActive = false;
    }
  }

  /// 保护窗期间的每次按下都续命静默线：连点期间保护不解锁，
  /// 手停 350ms 才放行 —— 开屏结束后持续 1~2 秒的惯性连点正是
  /// "5 页引导一闪即逝"的真机根因（固定 300ms 缓冲挡不住它）。
  /// 由 build 里的 Listener 以无参闭包调用，避免方法签名依赖手势类型
  void _handleGuardPointerDown() {
    if (!_tapGuardActive || !mounted) return;
    _tapGuardIdleTimer?.cancel();
    setState(() => _tapGuardIdle = false);
    _tapGuardIdleTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _tapGuardIdle = true;
        _releaseTapGuardIfReady();
      });
    });
  }

  @override
  void dispose() {
    _tapGuardTimer?.cancel();
    _splashBufferTimer?.cancel();
    _tapGuardIdleTimer?.cancel();
    _advanceTimer?.cancel();
    AppInitializationService.splashCompleted.removeListener(_onSplashEnded);
    _pageController.dispose();
    super.dispose();
  }

  //==========================================================================
  // 翻页忙锁
  //==========

  /// 视口真实页码（PageView 当前停留的页）。无客户端或值非法时返回 null。
  ///
  /// 「是否已在末页」必须用它判定，不能信 [_currentPage]：后者是可变量，
  /// 一旦被 [onPageChanged] 的越界值污染成末页，单次按压就让 `target` 越界，
  /// 直接走 [_finishOnboarding] 进首页 —— 真机"只点一次下一步就跳过整段引导"
  /// 的成因（选液态玻璃时整树重建 + BackdropFilter，布局突变最易触发）。
  int? get _viewportPage {
    if (!_pageController.hasClients) return null;
    final page = _pageController.page;
    if (page == null || !page.isFinite) return null;
    return page.round().clamp(0, _totalPages - 1);
  }

  /// 把页码对齐到视口真实位置，返回该页码；视口不可用时返回 null
  int? _syncPageFromViewport() {
    final viewport = _viewportPage;
    if (viewport == null) return null;
    if (_currentPage != viewport) {
      setState(() => _currentPage = viewport);
    }
    return viewport;
  }

  /// 上锁并把页码**乐观**推进到目标页。
  ///
  /// 乐观更新是必须的：[_currentPage] 原本只在 onPageChanged 里更新，而该
  /// 回调要等 300ms 动画落定才来。动画期间连点时每次都读到同一个陈旧页码，
  /// `nextPage` 只是不断把目标往后重定向，几发就冲到末页。现在按下瞬间页码
  /// 就已到位，`_isLastStep` / 底部文案也立刻跟着变。
  void _lockAdvanceTo(int target) {
    _advanceTimer?.cancel();
    setState(() {
      _advancing = true;
      _currentPage = target;
    });
    _advanceTimer = Timer(_pageAnimDuration + _advanceSettle, () {
      if (!mounted) return;
      setState(() => _advancing = false);
    });
  }

  /// 末页"开始学习"：没有下一页可锁，直接占住按钮直到导入/落盘结束
  void _lockAdvanceIndefinitely() {
    _advanceTimer?.cancel();
    setState(() => _advancing = true);
  }

  //==========================================================================
  // 数据
  //==========================================================================

  Future<void> _loadBuiltInBooks() async {
    final books = await AssetWordBookService.getAllBuiltInBooks();
    if (!mounted) return;
    setState(() {
      _builtInBooks = books;
      _isLoadingBooks = false;
    });
  }

  List<_OnboardingPage> _buildPages() {
    return [
      _OnboardingPage(
        icon: Icons.auto_stories,
        titleKey: _zh.welcomeTitle,
        titleKeyEn: _en.welcomeTitle,
        descKey: _zh.welcomeDesc,
        descKeyEn: _en.welcomeDesc,
        highlights: [_zh.hlWordBookMgmt, _zh.hlSmartReview, _zh.hlAnalytics],
        highlightsEn: [_en.hlWordBookMgmt, _en.hlSmartReview, _en.hlAnalytics],
        color: const Color(0xFF6366F1),
        demoVariant: 0,
      ),
      _OnboardingPage(
        icon: Icons.psychology_alt,
        titleKey: _zh.onboardingLoopTitle,
        titleKeyEn: _en.onboardingLoopTitle,
        descKey: _zh.onboardingLoopDesc,
        descKeyEn: _en.onboardingLoopDesc,
        highlights: [
          _zh.hlMultiModePractice,
          _zh.hlSpacedReview,
          _zh.hlDataFeedback,
        ],
        highlightsEn: [
          _en.hlMultiModePractice,
          _en.hlSpacedReview,
          _en.hlDataFeedback,
        ],
        color: const Color(0xFF10B981),
        demoVariant: 1,
      ),
    ];
  }

  //==========================================================================
  // 交互
  //==========================================================================

  Future<void> _nextPage() async {
    // 末页导入词库是异步的，双重点击/回车会并发导入同一批词库多次
    if (_isImporting) return;
    if (_tapGuardActive) return;
    // 一次按压只推进一页
    if (_advancing) return;
    // 以视口为准取来源页：_currentPage 可能是被越界值污染的陈旧值
    final from = _syncPageFromViewport();
    if (from == null) return;
    final target = from + 1;
    if (target > _totalPages - 1) {
      _lockAdvanceIndefinitely();
      await _finishOnboarding();
      return;
    }
    _lockAdvanceTo(target);
    if (from == _languageStepIndex) {
      await _applyLanguageSelection();
    }
    if (!mounted || !_pageController.hasClients) return;
    // 用绝对目标页而不是相对 nextPage：即便视口停在半页上，
    // 落点也必然是 from + 1，不会累积偏移
    _pageController.animateToPage(
      target,
      duration: _pageAnimDuration,
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    if (_tapGuardActive || _advancing) return;
    final from = _syncPageFromViewport();
    if (from == null || from == 0) return;
    _lockAdvanceTo(from - 1);
    _pageController.animateToPage(
      from - 1,
      duration: _pageAnimDuration,
      curve: Curves.easeInOut,
    );
  }

  /// 选中语言即时生效：先按所选语言重绘本页（标题/描述/选项卡），
  /// 再同步到全局 locale —— 用户不必等到下一步，就能看到整段引导
  /// 跟着语言切换（此前只有点「下一步」才落盘，切语言看不出任何变化）。
  Future<void> _selectLanguage(_OnboardingLanguage language) async {
    if (_selectedLanguage != language) {
      setState(() => _selectedLanguage = language);
    }
    await _applyLanguageSelection();
  }

  Future<void> _applyLanguageSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('onboardingLanguage', _selectedLanguage.name);
    if (!mounted) return;
    await context.read<ThemeProvider>().setEnglishLocale(_isEnglish);
  }

  /// 立即落盘并生效，让用户在本页就能看到真实风格效果
  Future<void> _selectStyle(AppStyle style) async {
    final provider = context.read<ThemeProvider>();
    if (provider.appStyle != style) {
      await provider.setAppStyle(style);
    }
  }

  /// 深/浅/跟随系统同样即时生效，便于当场比对
  Future<void> _selectThemeMode(ThemeMode mode) async {
    final provider = context.read<ThemeProvider>();
    if (provider.themeMode != mode) {
      await provider.setThemeMode(mode);
    }
  }

  void _toggleBook(String name) {
    if (_importing) return;
    setState(() {
      if (_selectedBooks.contains(name)) {
        _selectedBooks.remove(name);
      } else {
        if (_selectedBooks.length >= _maxBooks) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr.onboardingBooksCap),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        _selectedBooks.add(name);
      }
    });
  }

  bool get _importing => _isImporting;

  Future<void> _finishOnboarding() async {
    if (_selectedBooks.isNotEmpty) {
      final success = await _importSelectedBooks();
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr.onboardingImportFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    await GuideService.logEvent(
      GuideService.eventComplete,
      params: {
        'books': _selectedBooks.length,
        // 诊断用：完成时的页码与停留时长。"引导一闪而过"类反馈复现时，
        // 靠这两个值区分是用户连点、视口脱节还是路由重建
        'step': _currentPage,
        'ms': DateTime.now().difference(_mountedAt).inMilliseconds,
      },
    );
    // 视口页码与计数不一致说明上游有脱节，留一行日志便于真机排查
    debugPrint(
      '[Onboarding] 完成：step=$_currentPage viewport=$_viewportPage '
      'ms=${DateTime.now().difference(_mountedAt).inMilliseconds}',
    );
    if (_currentPage != _totalPages - 1) {
      // 只有视口确实停在末页时才该走完；否则打一行调用栈，定位是谁触发的
      debugPrint('[Onboarding] 非末页触发了完成，调用栈如下');
      debugPrintStack(maxFrames: 6);
    }
    await _completeOnboarding();
  }

  Future<bool> _importSelectedBooks() async {
    final provider = context.read<WordBookProvider>();
    final names = List<String>.from(_selectedBooks);
    final books = _builtInBooks;
    setState(() {
      _isImporting = true;
      _importDone = 0;
      _importTotal = names.length;
    });
    try {
      for (final name in names) {
        final bookData = books.firstWhere((b) => b['name'] == name);
        final words = await AssetWordBookService.loadBookWords(
          bookData['file'] as String,
        );
        if (words.isEmpty) {
          throw Exception('词库「$name」加载失败或为空');
        }
        await provider.importBuiltInBook(
          name,
          bookData['description'] as String? ?? '',
          words,
        );
        if (mounted) setState(() => _importDone += 1);
      }
      await GuideService.logEvent(
        GuideService.eventImportBooks,
        params: {'count': names.length},
      );
      return true;
    } catch (e) {
      debugPrint('引导页导入词库失败：$e');
      return false;
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _skipOnboarding() async {
    if (_tapGuardActive) return;
    await GuideService.logEvent(
      GuideService.eventSkip,
      params: {'step': _currentPage},
    );
    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    try {
      await _applyLanguageSelection();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasSeenOnboarding', true);
      widget.onComplete();
    } catch (e) {
      // SharedPreferences 写盘失败时按钮"点了没反应"：至少给出提示，
      // 并仍然尝试回调，避免用户被卡在引导页无法进入应用。
      debugPrint('完成引导时写盘失败：$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr.onboardingCompleteFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      widget.onComplete();
    }
  }

  //==========================================================================
  // 构建
  //==========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    //风格也在这里订阅一次：itemBuilder 里不能再调用 context.select（见 _isGlass）
    _isGlass = context.select<ThemeProvider, bool>((p) => p.isLiquidGlass);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final indicatorInactiveColor = FluidTheme.getBorderColor(isDark);

    return Listener(
      //观察保护窗期间的连点：必须在 IgnorePointer 外层且 translucent ——
      //内层被屏蔽时子树 hit test 会 miss，translucent 保证按下事件仍到监听器
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _handleGuardPointerDown(),
      child: IgnorePointer(
        //保护窗内整树屏蔽（含 PageView 滑动与所有按钮）：原先只在
        //_nextPage/_skipOnboarding 里 return，滑动翻页拦不住；
        //三条解除条件见 [_tapGuardActive]
        ignoring: _tapGuardActive,
        child: FluidBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, right: 12),
                      child: TextButton(
                        onPressed: _isImporting ? null : _skipOnboarding,
                        child: Text(
                          context.tr.skip,
                          style: FluidTheme.labelLarge(isDark).copyWith(
                            //跳过按钮文字：主色原色在浅色背景上仅 1.91:1，改用可读版主色
                            color: FluidTheme.primaryAccessible(isDark),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      key: _pageStorageKey,
                      controller: _pageController,
                      //禁掉自由滑动：引导是强引导流程，一次快速 fling 会从
                      //第 1 页直接贯到末页——5 页介绍一滑而过，观感就是
                      //"新手引导被跳过"（保护窗只挡时间窗，不限制滑动距离）。
                      //导航只走 上一步/下一步 按钮，全部受保护窗约束
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        // 钳制后再写入：视口尺寸/布局突变（切液态玻璃后的重建）
                        // 时 PageView 可能报出越界页码，原样写入会让 _currentPage
                        // 停在末页，下一次按压就"一击直达首页"。越界值只记日志
                        final safe = index.clamp(0, _totalPages - 1);
                        if (safe != index) {
                          debugPrint(
                            '[Onboarding] onPageChanged 越界：raw=$index → $safe',
                          );
                        }
                        setState(() => _currentPage = safe);
                        GuideService.logEvent(
                          GuideService.eventStepView,
                          params: {'step': safe},
                        );
                      },
                      itemCount: _totalPages,
                      itemBuilder: (context, index) {
                        if (index == _styleStepIndex) {
                          return _buildAppearancePage(isDark);
                        }
                        if (index == _languageStepIndex) {
                          return _buildLanguagePage(isDark);
                        }
                        if (index == _wordBookStepIndex) {
                          return _buildWordBookPage(isDark);
                        }
                        return _buildIntroPage(_pages[index - 2], isDark);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _totalPages,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? FluidTheme.primaryFluidGradient[0]
                                : indicatorInactiveColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: _buildBottomAction(isDark),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
                    ),
                    child: Text(
                      '${_currentPage + 1} / $_totalPages',
                      style: FluidTheme.bodySmall(
                        isDark,
                      ).copyWith(color: textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(bool isDark) {
    if (_isImporting) {
      final ratio = _importTotal == 0 ? null : _importDone / _importTotal;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: FluidTheme.getProgressTrackColor(
                isDark,
                _isGlass,
              ),
              color: FluidTheme.primaryFluidGradient[0],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${context.tr.onboardingBooksImporting} $_importDone/$_importTotal',
            style: FluidTheme.bodySmall(
              isDark,
            ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
          ),
        ],
      );
    }

    final isWordBookStep = _currentPage == _wordBookStepIndex;
    final label = isWordBookStep && _selectedBooks.isEmpty
        ? context.tr.onboardingStartLater
        : (_isLastStep ? context.tr.onboardingStartNow : context.tr.nextStep);
    final next = FluidButton(
      text: label,
      icon: _isLastStep ? Icons.rocket_launch : Icons.arrow_forward,
      expanded: true,
      onPressed: _nextPage,
      // 翻页忙锁期间置灰：连点被吞掉的同时给出可见反馈，
      // 否则用户会以为按钮失灵，越点越快
      isEnabled: !_advancing,
      // 按钮层再兜一道：语言页的 _applyLanguageSelection 有异步空窗，
      // 忙锁之外的补点由冷却窗吞掉
      minTriggerInterval: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 16),
      fontSize: 18,
    );

    // 第一步没有上一步可退，只留主按钮
    if (_currentPage == 0) return next;
    return Row(
      children: [
        Expanded(child: _buildPreviousButton()),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: next),
      ],
    );
  }

  /// 次要按钮：上一步。玻璃模式走中性玻璃片，经典模式用低饱和灰底与主按钮区分
  Widget _buildPreviousButton() {
    return FluidButton(
      text: context.tr.previousStep,
      icon: Icons.arrow_back,
      expanded: true,
      onPressed: _previousPage,
      isEnabled: !_advancing,
      minTriggerInterval: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 16),
      fontSize: 16,
      colors: const [Color(0xFF94A3B8), Color(0xFF64748B)],
    );
  }

  /// 步骤卡片容器：玻璃模式用玻璃片，经典模式用流体卡片
  Widget _stepCard({required List<Color> accentColors, required Widget child}) {
    const padding = EdgeInsets.fromLTRB(28, 28, 28, 28);
    if (_isGlass) {
      return GlassSurface(
        borderRadius: FluidTheme.cardBorderRadius,
        emphasized: true,
        grain: true,
        glowColor: accentColors.first,
        padding: padding,
        child: child,
      );
    }
    return FluidCard(
      enableShimmer: true,
      enableBorderGradient: true,
      borderColors: accentColors,
      padding: padding,
      child: child,
    );
  }

  String _localized(String zh, String en) {
    switch (_selectedLanguage) {
      case _OnboardingLanguage.zh:
        return zh;
      case _OnboardingLanguage.en:
        return en;
      case _OnboardingLanguage.bilingual:
        return '$zh / $en';
    }
  }

  //==========================================================================
  // 第 1 步：语言
  //==========================================================================

  Widget _buildLanguagePage(bool isDark) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
      child: Center(
        child: _stepCard(
          accentColors: [
            FluidTheme.primaryFluidGradient[0],
            FluidTheme.primaryFluidGradient[2].withValues(alpha: 0.45),
          ],
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FluidGradientContainer(
                    colors: FluidTheme.primaryFluidGradient,
                    borderRadius: 28,
                    padding: const EdgeInsets.all(22),
                    child: const Icon(
                      Icons.translate,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    //标题跟随所选语言即时变化：选「中文」显示中文标题，
                    //选 English 显示英文标题，选「中英一起」同时给出两份
                    _localized(
                      _zh.chooseGuideLanguage,
                      _en.chooseGuideLanguage,
                    ),
                    style: FluidTheme.headingMedium(
                      isDark,
                    ).copyWith(color: textPrimary, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _localized(_zh.guideLanguageDesc, _en.guideLanguageDesc),
                    style: FluidTheme.bodyMedium(
                      isDark,
                    ).copyWith(color: textSecondary, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _choiceRow([
                    _choiceCard(
                      selected: _selectedLanguage == _OnboardingLanguage.zh,
                      icon: Icons.text_fields,
                      accent: FluidTheme.primaryFluidGradient[0],
                      title: context.tr.languageZh,
                      height: 92,
                      isDark: isDark,
                      onTap: () => _selectLanguage(_OnboardingLanguage.zh),
                    ),
                    _choiceCard(
                      selected: _selectedLanguage == _OnboardingLanguage.en,
                      icon: Icons.language,
                      accent: FluidTheme.primaryFluidGradient[0],
                      title: context.tr.languageEn,
                      height: 92,
                      isDark: isDark,
                      onTap: () => _selectLanguage(_OnboardingLanguage.en),
                    ),
                    _choiceCard(
                      selected:
                          _selectedLanguage == _OnboardingLanguage.bilingual,
                      icon: Icons.compare_arrows,
                      accent: FluidTheme.primaryFluidGradient[0],
                      title: context.tr.languageBilingual,
                      height: 92,
                      isDark: isDark,
                      onTap: () =>
                          _selectLanguage(_OnboardingLanguage.bilingual),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 同一行选项卡：等宽、等高、底边自然对齐。
  ///
  /// 早期用 Wrap + 手算宽度：窄屏（360dp）三列时每张卡只有 ~70dp，
  /// 卡片内再各留 16dp 内边距，"English" 这种单词会被拆成两行，
  /// 同行卡片高度随之不同 —— 观感上就是"按钮高矮不一、下方有空位"。
  /// 改成 Row + Expanded 后，同行卡片始终等宽等高；文字改用 FittedBox
  /// 单行缩放，既不会断词，也不会把卡片撑高。
  ///
  /// 注意**不能**用 `CrossAxisAlignment.stretch`：本行位于
  /// `SingleChildScrollView` 的 Column 里，纵向约束是无界的，stretch 会把
  /// 无限高度透传给子项（卡片自带固定高度），整行随后无法完成布局 ——
  /// 表现就是"引导页的风格选择与语言选项整块消失"。
  /// 每张卡片的 `height` 本来就相同，用 center 即可等高对齐。
  Widget _choiceRow(List<Widget> cards, {double maxWidth = 460}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: FluidTheme.labelLarge(isDark).copyWith(
        color: FluidTheme.getTextPrimaryColor(isDark),
        fontWeight: FontWeight.w700,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// 引导页通用选项卡。
  ///
  /// 选中态刻意用了三层信号叠加（主色描边 + 主色淡底 + 右上角勾选徽章，
  /// 图标与标题同时转主色）：液态玻璃模式下强调玻璃片靠自带光斑着色，
  /// 而光斑强度目前为 0，仅靠 emphasized 几乎看不出差别。
  Widget _choiceCard({
    required bool selected,
    required IconData icon,
    required Color accent,
    required String title,
    String? subtitle,
    required bool isDark,
    required VoidCallback onTap,
    double height = 94,
  }) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    // 固定高度 + 内容垂直居中：只放一行文字的卡片不会比放两行的矮，
    // 同行卡片底部因此永远对齐（"按钮下方有空位"的直观来源就是高度不齐）。
    //
    // width 必须是 infinity（占满所在槽位）：本卡片被包在 Stack 里，而 Stack 给
    // 非定位子节点的是**宽松**约束 —— 只写高度时，卡片会收缩到"图标+文字"的
    // 宽度并靠左对齐，而选中的描边框（Positioned.fill）与勾选角标仍然按整个
    // 槽位铺开：于是描边框比卡片宽出一大截、还盖住右边那张卡（用户反馈的
    // "框选错位"）。占满宽度后描边、角标、点击区域才与卡片完全重合。
    final content = SizedBox(
      width: double.infinity,
      height: height,
      child: Padding(
        // 水平内边距收窄：窄屏三列时每张卡只有 ~70dp，
        // 左右各留 16dp 会把 "English" 挤成两行
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? accent : textSecondary, size: 26),
            const SizedBox(height: 8),
            //一行显示：放不下就等比缩小，绝不在单词中间断开
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: FluidTheme.labelLarge(isDark).copyWith(
                  color: selected ? accent : textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            //选项只留名称：描述文字信息量低，还会把卡片撑高导致需要滚动
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FluidTheme.bodySmall(
                  isDark,
                ).copyWith(color: textSecondary, height: 1.3),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );

    final Widget card;
    if (_isGlass) {
      card = GlassSurface(
        borderRadius: 16,
        emphasized: selected,
        tint: selected
            ? Color.alphaBlend(
                accent.withValues(alpha: isDark ? 0.30 : 0.16),
                LiquidGlass.tint(isDark),
              )
            : null,
        child: content,
      );
    } else {
      card = AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: isDark ? 0.22 : 0.14)
              : FluidTheme.getMutedOverlayColor(isDark),
          borderRadius: BorderRadius.circular(16),
        ),
        child: content,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          //选中描边叠在卡片之上，两种风格下都清晰可辨
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent, width: 2),
                  ),
                ),
              ),
            ),
          if (selected)
            Positioned(
              // 徽章挂在卡片右上角外侧；Row 布局下左右都有留白，
              // 不会被 SingleChildScrollView 的硬边裁切
              top: -5,
              right: -5,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  //==========================================================================
  // 第 2 步：显示模式 + 界面风格
  //==========================================================================

  Widget _buildAppearancePage(bool isDark) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    const accent = Color(0xFF6366F1);
    //选中态以 Provider 为准，切换后本页立即反映真实生效值
    final themeProvider = context.watch<ThemeProvider>();
    final themeMode = themeProvider.themeMode;
    final appStyle = themeProvider.appStyle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
      child: Center(
        child: _stepCard(
          accentColors: [accent, accent.withValues(alpha: 0.45)],
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FluidGradientContainer(
                    colors: const [
                      Color(0xFF6366F1),
                      Color(0xFF8B5CF6),
                      Color(0xFF4FACFE),
                    ],
                    borderRadius: 28,
                    padding: const EdgeInsets.all(22),
                    child: const Icon(
                      Icons.palette_outlined,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.tr.onboardingAppearanceTitle,
                    style: FluidTheme.headingMedium(
                      isDark,
                    ).copyWith(color: textPrimary, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr.onboardingAppearanceDesc,
                    style: FluidTheme.bodyMedium(
                      isDark,
                    ).copyWith(color: textSecondary, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  _sectionLabel(context.tr.displayMode, isDark),
                  const SizedBox(height: 10),
                  _choiceRow([
                    _choiceCard(
                      selected: themeMode == ThemeMode.light,
                      icon: Icons.light_mode,
                      accent: accent,
                      title: context.tr.lightMode,
                      isDark: isDark,
                      onTap: () => _selectThemeMode(ThemeMode.light),
                    ),
                    _choiceCard(
                      selected: themeMode == ThemeMode.dark,
                      icon: Icons.dark_mode,
                      accent: accent,
                      title: context.tr.darkModeLabel,
                      isDark: isDark,
                      onTap: () => _selectThemeMode(ThemeMode.dark),
                    ),
                    _choiceCard(
                      selected: themeMode == ThemeMode.system,
                      icon: Icons.brightness_auto,
                      accent: accent,
                      title: context.tr.systemMode,
                      isDark: isDark,
                      onTap: () => _selectThemeMode(ThemeMode.system),
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _sectionLabel(context.tr.uiStyle, isDark),
                  const SizedBox(height: 10),
                  _choiceRow([
                    _choiceCard(
                      selected: appStyle == AppStyle.fluid,
                      icon: Icons.gradient,
                      accent: accent,
                      title: context.tr.onboardingStyleFluidName,
                      isDark: isDark,
                      onTap: () => _selectStyle(AppStyle.fluid),
                    ),
                    _choiceCard(
                      selected: appStyle == AppStyle.liquidGlass,
                      icon: Icons.filter_b_and_w,
                      accent: accent,
                      title: context.tr.onboardingStyleGlassName,
                      isDark: isDark,
                      onTap: () => _selectStyle(AppStyle.liquidGlass),
                    ),
                  ], maxWidth: 380),
                  const SizedBox(height: 20),
                  Text(
                    context.tr.onboardingStylePreview,
                    style: FluidTheme.bodySmall(
                      isDark,
                    ).copyWith(color: textSecondary),
                  ),
                  const SizedBox(height: 10),
                  _buildStylePreview(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 风格实时预览：用当前生效风格渲染一张示例词卡
  Widget _buildStylePreview(bool isDark) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final accent = FluidTheme.primaryFluidGradient[0];

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.24 : 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.volume_up, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'abandon',
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: textPrimary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '/əˈbændən/',
                  style: FluidTheme.bodySmall(
                    isDark,
                  ).copyWith(color: textSecondary),
                ),
              ],
            ),
          ),
          if (_isGlass)
            GlowCapsule(
              color: accent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'v.',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                'v.',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: _isGlass
          ? GlassSurface(
              borderRadius: 18,
              emphasized: true,
              grain: true,
              padding: EdgeInsets.zero,
              child: content,
            )
          : FluidCard(
              enableShimmer: true,
              borderRadius: 18,
              padding: EdgeInsets.zero,
              child: content,
            ),
    );
  }

  //==========================================================================
  // 第 3~4 步：精简介绍页
  //==========================================================================

  Widget _buildIntroPage(_OnboardingPage page, bool isDark) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
      child: Center(
        child: _stepCard(
          accentColors: [page.color, page.color.withValues(alpha: 0.45)],
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: page.color.withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: page.color.withValues(
                          alpha: isDark ? 0.32 : 0.22,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: page.color.withValues(
                            alpha: isDark ? 0.22 : 0.12,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Icon(page.icon, size: 40, color: page.color),
                  ),
                  const SizedBox(height: 16),
                  _IntroDemo(variant: page.demoVariant, accent: page.color),
                  const SizedBox(height: 18),
                  Text(
                    _localized(page.titleKey, page.titleKeyEn),
                    style: FluidTheme.headingMedium(
                      isDark,
                    ).copyWith(color: textPrimary, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _localized(page.descKey, page.descKeyEn),
                    style: FluidTheme.bodyMedium(
                      isDark,
                    ).copyWith(color: textSecondary, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: List.generate(page.highlights.length, (index) {
                      final label = _localized(
                        page.highlights[index],
                        page.highlightsEn[index],
                      );
                      //发光胶囊的底色是同色系暗调，深色下直接用强调色原色写字
                      //对比度不足（反馈"下面三个标签看不清"），深色时把文字
                      //向白色插值提亮，浅色时保持原色。
                      final labelColor = _isGlass
                          ? (isDark
                                ? Color.lerp(page.color, Colors.white, 0.55)!
                                : page.color)
                          : textPrimary;
                      final pillText = Text(
                        label,
                        style: FluidTheme.bodySmall(isDark).copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                      //玻璃模式亮点用发光胶囊，经典模式保留描边圆角块
                      if (_isGlass) {
                        return GlowCapsule(
                          color: page.color,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: pillText,
                        );
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: page.color.withValues(
                            alpha: isDark ? 0.16 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: page.color.withValues(
                              alpha: isDark ? 0.28 : 0.22,
                            ),
                          ),
                        ),
                        child: pillText,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  //==========================================================================
  // 第 5 步：选择词库
  //==========================================================================

  Widget _buildWordBookPage(bool isDark) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final accent = FluidTheme.primaryFluidGradient[2];

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
      child: Center(
        child: _stepCard(
          accentColors: [accent, accent.withValues(alpha: 0.45)],
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: accent.withValues(alpha: isDark ? 0.3 : 0.2),
                      ),
                    ),
                    child: Icon(Icons.library_books, size: 44, color: accent),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    context.tr.onboardingBooksTitle,
                    style: FluidTheme.headingMedium(
                      isDark,
                    ).copyWith(color: textPrimary, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr.onboardingBooksDesc,
                    style: FluidTheme.bodyMedium(
                      isDark,
                    ).copyWith(color: textSecondary, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (_isLoadingBooks)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(),
                    )
                  else
                    ..._builtInBooks.map(
                      (book) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildBookTile(book, isDark),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedBooks.isEmpty
                        ? context.tr.onboardingBooksNoneSelected
                        : context.tr.onboardingSelectedBooks(
                            _selectedBooks.length,
                          ),
                    style: FluidTheme.bodySmall(
                      isDark,
                    ).copyWith(color: textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookTile(Map<String, dynamic> book, bool isDark) {
    final name = book['name'] as String? ?? '';
    final description = book['description'] as String? ?? '';
    final wordCount = book['wordCount'] as int? ?? 0;
    final selected = _selectedBooks.contains(name);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final accent = FluidTheme.primaryFluidGradient[2];

    final content = Row(
      children: [
        //LiquidCheckbox 已内置双风格：玻璃=水银勾选，经典=原生勾选
        LiquidCheckbox(
          value: selected,
          activeColor: accent,
          onChanged: _isImporting ? null : (_) => _toggleBook(name),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: FluidTheme.labelLarge(
                  isDark,
                ).copyWith(color: textPrimary),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FluidTheme.bodySmall(
                    isDark,
                  ).copyWith(color: textSecondary, height: 1.35),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          context.tr.readerWordsCount(wordCount),
          style: FluidTheme.bodySmall(
            isDark,
          ).copyWith(color: textSecondary, fontWeight: FontWeight.w600),
        ),
      ],
    );

    if (_isGlass) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _isImporting ? null : () => _toggleBook(name),
        child: GlassSurface(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          emphasized: selected,
          glowColor: selected ? accent : null,
          child: content,
        ),
      );
    }
    return InkWell(
      onTap: _isImporting ? null : () => _toggleBook(name),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: isDark ? 0.18 : 0.10)
              : FluidTheme.getMutedOverlayColor(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : FluidTheme.getBorderColor(isDark),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: content,
      ),
    );
  }
}

//============================================================================
// 迷你动效演示
//============================================================================

/// 介绍页的循环演示动画：
/// - variant 0：单词卡呼吸 + 声波律动，暗示"背诵/发音"
/// - variant 1：练习 → 复习 → 反馈 三个节点依次点亮，暗示学习闭环
class _IntroDemo extends StatefulWidget {
  final int variant;
  final Color accent;

  const _IntroDemo({required this.variant, required this.accent});

  @override
  State<_IntroDemo> createState() => _IntroDemoState();
}

class _IntroDemoState extends State<_IntroDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  /// 非循环模式下是否已经完整播过一轮
  bool _playedOnce = false;

  /// 当前是否液态玻璃风格。
  ///
  /// [_buildWordCard] / [_buildLoop] 是在 `AnimatedBuilder` 的 builder 里跑的，
  /// 那是**动画帧**而不是 build 阶段，在那里写 `context.isLiquidGlass`
  /// （内部是 `select`）属于非法依赖查找：debug 下直接触发 provider 断言并
  /// 中断整块演示卡的构建（介绍页 3/4 的演示动画变成空白），release 下则不会
  /// 跟随风格切换重建。风格与 isDark 一样在 build 里订阅一次存字段。
  bool _isGlass = false;

  /// 翻译同理：`context.tr` 内部是 `dependOnInheritedWidgetOfExactType`，
  /// 同样不能在动画 builder 里取（理由见 _isGlass）
  Translations _tr = const Translations(false);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    //循环门控：关闭"循环动效"（移动端默认）时不再常驻播放，但**至少播一轮**。
    //演示动画就是这两个介绍页的内容本身 —— 早先它跟随循环开关一起被关掉，
    //第 4 页的学习闭环因此变成一张静止的图（"本来应该是动画的"）。
    final loop =
        tickerEnabled &&
        !reduceMotion &&
        PlatformAdapt.allowLoopEffects(context);
    if (reduceMotion) {
      //系统"减弱动态效果"：不做任何自走动画
      if (_controller.isAnimating) _controller.stop();
    } else if (loop) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (tickerEnabled) {
      if (!_playedOnce) {
        _playedOnce = true;
        _controller.forward(from: 0);
      }
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    // 风格同样只能在这里订阅一次，供动画 builder 内的子树读取（见 _isGlass）
    _isGlass = context.select<ThemeProvider, bool>((p) => p.isLiquidGlass);
    _tr = context.tr;
    return SizedBox(
      height: 118,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return widget.variant == 0
              ? _buildWordCard(isDark, t)
              : _buildLoop(isDark, t);
        },
      ),
    );
  }

  Widget _buildWordCard(bool isDark, double t) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final accent = widget.accent;
    final pulse = 1 + 0.02 * math.sin(t * math.pi * 2);

    // 声波柱高度随时间律动，暗示"听音记词"
    final bars = List.generate(5, (i) {
      final phase = t * math.pi * 2 + i * 0.9;
      return 10 + 14 * (0.5 + 0.5 * math.sin(phase));
    });

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.24 : 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.volume_up, size: 20, color: accent),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'abandon',
                style: FluidTheme.labelLarge(
                  isDark,
                ).copyWith(color: textPrimary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                '/əˈbændən/',
                style: FluidTheme.bodySmall(
                  isDark,
                ).copyWith(color: textSecondary),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final height in bars)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 4,
                    height: height,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return Center(
      child: Transform.scale(
        scale: pulse,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          // 这里是动画 builder（不是 build 阶段），只能读 build 里订阅好的
          // 字段，直接写 context.isLiquidGlass 会触发 provider 断言，见 _isGlass
          child: _isGlass
              ? GlassSurface(
                  borderRadius: 20,
                  emphasized: true,
                  grain: true,
                  glowColor: accent,
                  padding: EdgeInsets.zero,
                  child: content,
                )
              : FluidCard(
                  enableShimmer: true,
                  borderRadius: 20,
                  padding: EdgeInsets.zero,
                  child: content,
                ),
        ),
      ),
    );
  }

  Widget _buildLoop(bool isDark, double t) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final accent = widget.accent;
    final labels = [
      _tr.hlMultiModePractice,
      _tr.hlSpacedReview,
      _tr.hlDataFeedback,
    ];
    final icons = [
      Icons.quiz_outlined,
      Icons.schedule,
      Icons.insights_outlined,
    ];
    // 每段时间推进到下一节点
    final activeIndex = (t * labels.length).floor() % labels.length;

    final nodes = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      final isActive = i == activeIndex;
      nodes.add(
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isActive
                      ? accent.withValues(alpha: isDark ? 0.32 : 0.20)
                      : FluidTheme.getMutedOverlayColor(isDark),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? accent
                        : FluidTheme.getBorderColor(isDark),
                    width: isActive ? 1.8 : 1,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icons[i],
                  size: 22,
                  color: isActive ? accent : textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                labels[i],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FluidTheme.bodySmall(isDark).copyWith(
                  color: isActive ? textPrimary : textSecondary,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
      if (i != labels.length - 1) {
        nodes.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Icon(
              Icons.arrow_forward,
              size: 16,
              color: FluidTheme.getTextTertiaryColor(isDark),
            ),
          ),
        );
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: nodes,
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String titleKey;
  final String titleKeyEn;
  final String descKey;
  final String descKeyEn;
  final List<String> highlights;
  final List<String> highlightsEn;
  final Color color;

  /// 迷你动效演示的形态：0 单词卡，1 学习闭环
  final int demoVariant;

  _OnboardingPage({
    required this.icon,
    required this.titleKey,
    required this.titleKeyEn,
    required this.descKey,
    required this.descKeyEn,
    required this.highlights,
    required this.highlightsEn,
    required this.color,
    this.demoVariant = 0,
  });
}
