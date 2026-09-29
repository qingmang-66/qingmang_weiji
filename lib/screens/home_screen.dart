import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/providers/providers.dart';
import '../services/di_container.dart';
import '../services/notification_service.dart';
import '../services/app_initialization_service.dart';
import '../services/guide_service.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/guide_keys.dart';
import '../utils/translations.dart';
import '../utils/page_transitions.dart';
import '../utils/platform_adapt.dart';
import '../utils/wordbook_localization.dart';
import '../widgets/coach_mark_overlay.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/fluid_loading.dart';
import '../widgets/liquid_pill_nav_bar.dart';
import '../widgets/quick_word_search_sheet.dart';
import 'pre_study_screen.dart';
import 'wordbook_screen.dart';
import 'reader_home_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'wrong_words_screen.dart';
import 'favorites_screen.dart';
import '../widgets/home_components.dart';

part 'home_screen/dashboard.dart';

/// 首页 - 流体渐变UI风格
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _tabCount = 5;

  int _currentIndex = 0;

  /// 上一次在首页按返回键的时间：1.5 秒内连按两次才真正退出应用
  DateTime? _lastBackAt;

  /// 各 Tab 页面实例，由 [_ensureScreens] 按语言重建
  List<Widget> _screens = const [];
  bool? _screensEnglish;

  /// 已打开过的 Tab 下标：未打开过的 Tab 不构建（见 [_buildTabChildren]）。
  /// 打开过的会一直保留在树上，页面状态与滚动位置照旧。
  final Set<int> _visitedTabs = <int>{0};

  /// 本会话内已经弹过的 Tab 引导，避免来回切 Tab 时重复提示
  final Set<String> _shownTabGuides = <String>{};

  /// 构造各 Tab 页面。
  ///
  /// 刻意不使用 const：Flutter 对「同一个 Widget 实例」会直接复用 element 而不
  /// 触发重建，IndexedStack 里的 Tab 便不会跟随语言变化更新文字。
  /// 只在语言真正变化时换新实例，其余重建（如切 Tab）沿用旧实例，避免无谓刷新。
  void _ensureScreens(bool english) {
    if (_screensEnglish == english && _screens.isNotEmpty) return;
    _screensEnglish = english;
    _screens = [
      _HomeDashboard(),
      WordBookScreen(),
      ReaderHomeScreen(),
      StatsScreen(),
      SettingsScreen(),
    ];
  }

  void switchToTab(int index) {
    _selectTab(index);
  }

  /// 用户主动切换 Tab：切过去之后补一次该页的功能引导。
  ///
  /// 主导览（[GuideService.tipMainTour]）播放期间不插队，否则两套遮罩会叠在一起，
  /// 用户也不知道该点哪一个。
  void _selectTab(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
    unawaited(_maybeShowTabGuide(index));
  }

  /// 该 Tab 首次被打开时播放一次对应的功能引导。
  Future<void> _maybeShowTabGuide(int index) async {
    final spec = _tabGuideFor(index);
    if (spec == null) return;
    if (_shownTabGuides.contains(spec.guideId)) return;
    // 主导览没走完就先不打扰
    if (!await GuideService.isSeen(GuideService.tipMainTour)) return;
    // 读完偏好用户可能已经切走了，别在别的 Tab 上弹这一页的提示
    if (!mounted || _currentIndex != index) return;
    _shownTabGuides.add(spec.guideId);
    await CoachMarkOverlay.maybeShow(
      context,
      guideId: spec.guideId,
      steps: spec.steps,
    );
  }

  /// 各 Tab 的功能引导定义。
  ///
  /// 只挂"必然可见"的锚点：这些页面都是懒加载长列表，屏幕外的控件根本没被构建，
  /// 高亮不到就会退化成居中的空气泡，所以设置页这类长页面只提示第一个分组，
  /// 其余内容交给文案说明。
  ///
  /// 每个 steps 闭包都先判断"用户是否还停在这个 Tab"：闭包在真正展示前会被
  /// 反复求值（等待目标控件完成布局），期间用户完全可能已经切走，返回空步骤
  /// 可以让引导安静地放弃、留到下次再提示，而不是糊在别的页面上。
  _TabGuideSpec? _tabGuideFor(int index) {
    List<CoachMarkStep> buildOnTab(List<CoachMarkStep> steps) =>
        _currentIndex == index ? steps : const <CoachMarkStep>[];

    switch (index) {
      case 1:
        return _TabGuideSpec(
          guideId: GuideService.tipWordBook,
          steps: () => buildOnTab([
            CoachMarkStep(
              targetKey: guideWordBookImportKey,
              title: context.tr.coachWordbookTitle,
              message: context.tr.coachWordbookMsg,
              icon: Icons.library_add_outlined,
            ),
            CoachMarkStep(
              targetKey: guideWordBookBatchKey,
              title: context.tr.coachWordbookBatchTitle,
              message: context.tr.coachWordbookBatchMsg,
              icon: Icons.checklist,
            ),
            //没有词库时列表是空状态，第一张卡片不存在
            if (context.read<WordBookProvider>().currentBook != null)
              CoachMarkStep(
                targetKey: guideWordBookFirstKey,
                title: context.tr.coachWordbookCardTitle,
                message: context.tr.coachWordbookCardMsg,
                icon: Icons.touch_app_outlined,
              ),
          ]),
        );
      case 3:
        return _TabGuideSpec(
          guideId: GuideService.tipStats,
          steps: () => buildOnTab([
            CoachMarkStep(
              targetKey: guideStatsAdviceKey,
              title: context.tr.coachStatsAdviceTitle,
              message: context.tr.coachStatsAdviceMsg,
              icon: Icons.wb_sunny_outlined,
            ),
          ]),
        );
      case 4:
        return _TabGuideSpec(
          guideId: GuideService.tipSettings,
          steps: () => buildOnTab([
            CoachMarkStep(
              targetKey: guideSettingsAppearanceKey,
              title: context.tr.coachSettingsAppearanceTitle,
              message: context.tr.coachSettingsAppearanceMsg,
              icon: Icons.palette_outlined,
              //设置页是长列表，气泡贴锚点会被推到屏幕最底部；
              //这条提示是"整页导览"性质，居中阅读体验更好
              centerBubble: true,
            ),
          ]),
        );
      default:
        return null;
    }
  }

  /// 全部 Tab 共用同一套子树，TickerMode 关闭非激活页动画。
  ///
  /// 另外只构建**访问过的** Tab：IndexedStack 会把所有子节点都 inflate、
  /// 参与布局（官方注释明确写代价是 O(N)），未访问的页面还会在冷启动就发出
  /// 自己的数据库查询（统计页进度、周报聚合、书架进度、词库进度四处），
  /// 与首帧抢同一个 sqflite 串行队列。未访问的 Tab 本来就不可见，
  /// 用零尺寸占位替代，画面与交互完全一致。
  List<Widget> _buildTabChildren() {
    // 当前 Tab 在同一帧记为已访问：底部栏、侧栏、通知点击、引导切页都直接改
    // _currentIndex，这里兜底可保证"可见页一定被构建"，不会出现空白页
    _visitedTabs.add(_currentIndex);
    return [
      for (var i = 0; i < _screens.length; i++)
        TickerMode(
          enabled: i == _currentIndex,
          child: _visitedTabs.contains(i)
              ? _TabTransition(active: i == _currentIndex, child: _screens[i])
              : const SizedBox.shrink(),
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    final notifications = DIContainer.instance.notificationService;
    notifications.pendingLaunchPayload.addListener(_onNotificationPayload);
    GuideService.requestedTab.addListener(_onGuideTabRequested);
    GuideService.replayTipsSignal.addListener(_onReplayTipsRequested);
    // 冷启动时可能已有 payload
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onNotificationPayload();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runMainTour();
    });
  }

  @override
  void dispose() {
    DIContainer.instance.notificationService.pendingLaunchPayload
        .removeListener(_onNotificationPayload);
    GuideService.requestedTab.removeListener(_onGuideTabRequested);
    GuideService.replayTipsSignal.removeListener(_onReplayTipsRequested);
    super.dispose();
  }

  /// 引导流程请求切换底部 Tab（首页之外的目标需要先切过去）
  void _onGuideTabRequested() {
    final index = GuideService.requestedTab.value;
    if (index == null) return;
    GuideService.clearRequestedTab();
    if (!mounted || index == _currentIndex) return;
    if (index >= 0 && index < _tabCount) {
      setState(() => _currentIndex = index);
    }
  }

  /// 「重看功能提示」：清掉本会话的已展示缓存，从主导览开始重播。
  /// 只清 prefs 标记不会让 initState 重来，必须在这里主动触发。
  void _onReplayTipsRequested() {
    if (!mounted) return;
    _shownTabGuides.clear();
    _runMainTour();
  }

  /// 首次进入主界面时播放一遍主导览：首页 → 词库 → 阅读 → 统计
  ///
  /// 加 600ms 延迟：引导页刚结束就立刻弹首页巡览，视觉上像是引导页
  /// 被"吞掉"了（一闪而过直接进首页引导）。留一点缓冲让首页先渲染完，
  /// 用户也能看清自己落在哪个页面。
  Future<void> _runMainTour() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await CoachMarkOverlay.maybeShow(
      context,
      guideId: GuideService.tipMainTour,
      steps: _buildTourSteps,
      // 巡览结束后把用户送回首页，从今日任务开始
      onFinish: () => GuideService.requestTab(0),
    );
  }

  List<CoachMarkStep> _buildTourSteps() {
    final hasBook = context.read<WordBookProvider>().currentBook != null;
    return [
      if (hasBook)
        CoachMarkStep(
          targetKey: guideHomePrimaryKey,
          title: context.tr.coachHomeTitle,
          message: context.tr.coachHomeMsg,
          icon: Icons.play_circle_outline,
          tabIndex: 0,
        )
      else
        CoachMarkStep(
          targetKey: guideHomeEmptyKey,
          title: context.tr.coachNoBookTitle,
          message: context.tr.coachNoBookMsg,
          icon: Icons.library_add_outlined,
          tabIndex: 0,
        ),
      CoachMarkStep(
        targetKey: guideHomeSearchKey,
        title: context.tr.coachHomeSearchTitle,
        message: context.tr.coachHomeSearchMsg,
        icon: Icons.search,
        tabIndex: 0,
      ),
      CoachMarkStep(
        targetKey: guideNavKey,
        title: context.tr.coachNavTitle,
        message: context.tr.coachNavMsg,
        icon: Icons.touch_app_outlined,
        tabIndex: 0,
      ),
      CoachMarkStep(
        targetKey: guideWordBookImportKey,
        title: context.tr.coachWordbookTitle,
        message: context.tr.coachWordbookMsg,
        icon: Icons.library_add_outlined,
        tabIndex: 1,
      ),
      CoachMarkStep(
        targetKey: hasBook ? guideReaderBookKey : guideReaderEmptyKey,
        title: context.tr.coachReaderTitle,
        message: hasBook
            ? context.tr.coachReaderMsg
            : context.tr.coachReaderEmptyMsg,
        icon: Icons.auto_stories_outlined,
        tabIndex: 2,
      ),
      CoachMarkStep(
        targetKey: guideStatsReportKey,
        title: context.tr.coachStatsTitle,
        message: context.tr.coachStatsMsg,
        icon: Icons.insights_outlined,
        tabIndex: 3,
      ),
    ];
  }

  void _onNotificationPayload() {
    final service = DIContainer.instance.notificationService;
    final payload = service.pendingLaunchPayload.value;
    if (payload == null || !mounted) return;
    service.clearPendingLaunchPayload();
    // 提醒点击：回首页看板，用户可直接开始学习/复习
    if (payload == NotificationService.payloadDailyReminder ||
        payload == NotificationService.payloadReviewReminder) {
      setState(() => _currentIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = context
        .select<ThemeProvider, ({bool isDark, bool isGlass, bool english})>(
          (p) => (
            isDark: p.isDarkMode,
            isGlass: p.isLiquidGlass,
            english: p.isEnglishLocale,
          ),
        );
    final isDark = themeConfig.isDark;
    final glass = themeConfig.isGlass;
    //订阅语言：切换语言后重建自身与各 Tab，导航栏文案才会同步更新
    _ensureScreens(themeConfig.english);

    // 全局快捷键只在桌面端注册：移动端没有物理键盘，注册了也永远不会触发。
    // 键盘快捷键已上移到 main.dart 的全局 Shortcuts（包在 Navigator 之上）：
    // 此前挂在 HomeScreen 内部，只覆盖 5 个 Tab 子树，所有 push 出来的页面
    // （学习页、阅读器、二级设置）里 Ctrl+1..5 / Ctrl+F / Ctrl+S 全部失灵。
    // 全局实现见 main.dart 的 _GlobalShortcuts。
    return Focus(
          // 修复 Windows 端 Ctrl+F / Ctrl+1..5 失灵：Shortcuts 依赖焦点链工作，
          // 页面刚打开、还没点过任何控件时焦点为空，按键事件到不了 Shortcuts
          // 那一层，快捷键看起来就是"没反应"。让首页根节点默认持有焦点即可；
          // 用户点进输入框后焦点自然移交，快捷键让位，属预期行为。
          // 移动端没有物理键盘，不参与焦点竞争。
          autofocus: PlatformAdapt.isDesktop,
          child: PopScope(
            // Android 返回键：非首页 Tab 先回首页；停在首页时双击（1.5 秒内
            // 两次）才退出应用——此前 canPop:true 会直接 pop 掉唯一路由退出，
            // 误触即丢未提交的学习进度且没有任何确认。桌面端没有系统返回键，
            //保持原语义（允许 pop）不受影响。push 出来的页面（学习页、
            //阅读器…）各自在新的路由上，不受这里影响。
            //用 isDesktop 而非 !isMobile：Web 上 isMobile 为 false，
            //会把唯一根路由放行 pop 掉。isDesktop 显式限定桌面端
            canPop: PlatformAdapt.isDesktop && _currentIndex == 0,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (_currentIndex != 0) {
                _selectTab(0);
                return;
              }
              final now = DateTime.now();
              final last = _lastBackAt;
              if (last != null &&
                  now.difference(last) < const Duration(milliseconds: 1500)) {
                SystemNavigator.pop();
                return;
              }
              _lastBackAt = now;
              ScaffoldMessenger.of(context)
                ..removeCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(context.tr.pressAgainToExit),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(milliseconds: 1500),
                  ),
                );
            },
            child: Builder(
              builder: (context) {
                final navPosition = context.select<ThemeProvider, NavPosition>(
                  (p) => p.navPosition,
                );
                // 侧栏导航：left 靠左，right 靠右（仅 Windows 提供该选项）
                final useRail = navPosition != NavPosition.bottom;
                final railOnLeft = navPosition != NavPosition.right;
                final tabStack = IndexedStack(
                  index: _currentIndex,
                  children: _buildTabChildren(),
                );
                return Scaffold(
                  //悬浮胶囊玻璃条需要"身后有内容"才能折射：extendBody 让
                  //页面延伸到胶囊后方，内容从玻璃条下滑过（参考系统同款形态）。
                  //此前 Windows/Impeller 上条后无内容可采样，backdrop 渲染
                  //失败整块变灰（Android/Skia 宽容所以看起来正常）
                  extendBody: !useRail,
                  backgroundColor: glass
                      ? Colors.transparent
                      : FluidTheme.getBackgroundColor(isDark),
                  body: SafeArea(
                    bottom: false,
                    // 侧栏：通高面板占位布局（不悬浮），五个导航项均分整条
                    // 高度，内容区缩短让出侧栏宽度。仅 Windows 提供左/右位置
                    // 选项；侧栏在 body 内（非 bottomNavigationBar 槽位），
                    // Impeller backdrop 失效问题不涉及，实时磨砂玻璃正常渲染。
                    child: useRail
                        ? Row(
                            children: [
                              if (railOnLeft)
                                KeyedSubtree(
                                  key: guideNavKey,
                                  child: _buildNavigationRail(),
                                ),
                              Expanded(child: tabStack),
                              if (!railOnLeft)
                                KeyedSubtree(
                                  key: guideNavKey,
                                  child: _buildNavigationRail(),
                                ),
                            ],
                          )
                        : tabStack,
                  ),
                  bottomNavigationBar: useRail
                      ? null
                      : SafeArea(
                          top: false,
                          child: KeyedSubtree(
                            key: guideNavKey,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: _buildPillNavBar(),
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
    );
  }

  /// 底部/侧栏共用的液态胶囊导航项（图标、文案与配色沿用旧导航栏）
  List<LiquidPillNavItem> _pillItems(BuildContext context) {
    final g = FluidTheme.primaryFluidGradient;
    return [
      LiquidPillNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: context.tr.navHome,
        activeColor: g[0],
      ),
      LiquidPillNavItem(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        label: context.tr.navWordBooks,
        activeColor: g[2],
      ),
      LiquidPillNavItem(
        icon: Icons.auto_stories_outlined,
        activeIcon: Icons.auto_stories,
        label: context.tr.navReader,
        activeColor: g[0],
      ),
      LiquidPillNavItem(
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart,
        label: context.tr.navStats,
        activeColor: g[1],
      ),
      LiquidPillNavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: context.tr.navSettings,
        activeColor: g[2],
      ),
    ];
  }

  /// 悬浮胶囊导航条（底部横向形态）。
  ///
  /// Selector 订阅 isDark + 语言：文案/配色变化才重建导航条，
  /// 避免主题微调导致 IndexedStack 整树重建（沿用旧 _FluidNavBar 的隔离策略）。
  Widget _buildPillNavBar() {
    return Selector<ThemeProvider, ({bool isDark, bool english})>(
      selector: (_, p) => (isDark: p.isDarkMode, english: p.isEnglishLocale),
      builder: (context, _, _) => LiquidPillNavBar(
        items: _pillItems(context),
        currentIndex: _currentIndex,
        onChanged: _selectTab,
      ),
    );
  }

  /// 桌面端侧边导航栏（左/右共用）：纵向液态胶囊通高铺满侧栏，
  /// 五个导航项均分整条高度，按住沿侧栏滑动切换
  Widget _buildNavigationRail() {
    return Padding(
      //左右留缝，底部贴边：侧栏胶囊一路印到窗口底缘
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: SizedBox(
        //外层 Row 给侧栏的就是整高，胶囊条直接撑满
        height: double.infinity,
        child: Selector<ThemeProvider, bool>(
          selector: (_, p) => p.isEnglishLocale,
          builder: (context, _, _) => LiquidPillNavBar(
            axis: Axis.vertical,
            expand: true,
            header: _railAppIcon(),
            items: _pillItems(context),
            currentIndex: _currentIndex,
            onChanged: _selectTab,
          ),
        ),
      ),
    );
  }

  /// 侧栏胶囊顶部：应用图标（保留旧 NavigationRail 的品牌位）
  Widget _railAppIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/images/app_icon_source_760.png',
          // 40dp 显示位，按 3x 密度限制解码尺寸
          cacheWidth: 120,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// 一个 Tab 的功能引导：引导 ID + 惰性构建的步骤列表
class _TabGuideSpec {
  final String guideId;
  final List<CoachMarkStep> Function() steps;

  const _TabGuideSpec({required this.guideId, required this.steps});
}

/// Tab 内容轻转场（方案A）：切到该页时 180ms 淡入 + 轻微上移。
///
/// 只在"变为激活页"那一刻播放一次；离开页不做退场（IndexedStack 直接
/// 换页），与胶囊导航的弹簧动画形成呼应又不拖节奏。
/// 冷启动首帧不播（初始 value = 1），避免开屏闪动。
class _TabTransition extends StatefulWidget {
  final bool active;
  final Widget child;

  const _TabTransition({required this.active, required this.child});

  @override
  State<_TabTransition> createState() => _TabTransitionState();
}

class _TabTransitionState extends State<_TabTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1.0,
  );

  @override
  void didUpdateWidget(covariant _TabTransition old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
        ),
        child: widget.child,
      ),
    );
  }
}
