import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/platform_db_init.dart';
import 'utils/platform_info.dart';
import 'services/services.dart';
import 'services/local_dictionary_service.dart';
import 'services/providers/reader_settings_provider.dart';
import 'utils/app_idle_monitor.dart';
import 'utils/constants.dart';
import 'utils/insets_probe.dart';
import 'utils/platform_adapt.dart';
import 'utils/system_ui.dart';
import 'utils/translations.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/fluid_theme.dart';
import 'widgets/fluid_background.dart';
import 'widgets/quick_word_search_sheet.dart';
import 'widgets/tts_error_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 空闲监视器：高刷新率 / LTPO 适配。空闲 3 秒后暂停背景光斑、shimmer 等
  // 常驻循环动画，让 Android 的 1~120Hz 动态刷新面板能降到 1Hz 省电、
  // Windows 的 60/90/120Hz 屏在静止时不再出帧；任何交互立即恢复
  AppIdleMonitor.instance.start();

  // 全局异常兜底：初始化失败时给出错误页而不是白屏/闪退
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('未捕获的框架异常: ${details.exception}\n${details.stack}');
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('未捕获的运行时异常: $error\n$stack');
    return true;
  };

  try {
    // Android 走沉浸式（隐藏状态栏/灵动岛/小白条），其余平台 edge-to-edge；
    // 顶部避让改由原生 insets 探针提供（挖孔高度/状态栏高度），
    // 见 InsetsProbe 与 MainActivity.setupInsetsProbe
    applySystemUiMode();
    applySystemUiOverlay(isDark: false);
    InsetsProbe.instance.bind();

    // 根据平台初始化数据库引擎（Web/Desktop/Mobile）
    // Windows 依赖系统 winsqlite3.dll，缺失时此处会抛异常
    initDatabaseFactory();

    // 初始化依赖注入容器
    await DIContainer.instance.init();
  } catch (e, stack) {
    debugPrint('应用初始化失败: $e\n$stack');
    runApp(_BootstrapErrorApp(error: e));
    return;
  }

  // 词典大库不在启动时拷贝，首帧后再后台预热（Web端跳过，无法拷贝本地文件）
  if (!kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocalDictionaryService.warmUpInBackground();
    });
  }

  // 不再自动导入内置词库，由用户在词库页面手动选择添加

  runApp(const QingMangApp());
}

/// 初始化失败时的兜底错误页
///
/// 不依赖 Provider/DI/主题系统，保证在 DIContainer 初始化失败时仍可渲染。
class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  '应用初始化失败',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '可能是数据库引擎不可用或数据目录无法访问。\n请尝试重启电脑或重新安装应用，并把以下信息反馈给开发者：',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  '$error',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QingMangApp extends StatefulWidget {
  const QingMangApp({super.key});

  @override
  State<QingMangApp> createState() => _QingMangAppState();
}

class _QingMangAppState extends State<QingMangApp> {
  @override
  Widget build(BuildContext context) {
    final di = DIContainer.instance;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider()..loadPreferences(),
        ),
        ChangeNotifierProvider(create: (_) => WordBookProvider()..init()),
        ChangeNotifierProvider(
          create: (_) => StudySettingsProvider()..loadPreferences(),
        ),
        ChangeNotifierProvider(
          create: (_) => ReaderSettingsProvider()..loadPreferences(),
        ),
        ChangeNotifierProvider(
          create: (_) => WordCollectionSettingsProvider()..loadPreferences(),
        ),
        Provider.value(value: di),
        Provider(create: (_) => di.ttsService),
      ],
      child: const _RuntimeServicesSync(
        child: QingMangMaterialApp(
          home: SplashScreen(child: _OnboardingWrapper(child: HomeScreen())),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 释放所有需显式关闭的运行时资源（StreamController 等）
    DIContainer.instance.dispose();
    super.dispose();
  }
}

class QingMangMaterialApp extends StatefulWidget {
  const QingMangMaterialApp({super.key, required this.home});

  final Widget home;

  @override
  State<QingMangMaterialApp> createState() => _QingMangMaterialAppState();
}

class _QingMangMaterialAppState extends State<QingMangMaterialApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Selector<
      ThemeProvider,
      ({ThemeMode mode, bool english, AppStyle style})
    >(
      selector: (_, provider) => (
        mode: provider.themeMode,
        english: provider.isEnglishLocale,
        style: provider.appStyle,
      ),
      builder: (context, config, _) {
        final glass = config.style == AppStyle.liquidGlass;
        //同步语言广播器：语言翻转时让所有 context.tr 的组件立即重建
        //（见 translations.dart 的 AppLocaleNotifier / withLocaleScope）。
        //不能在 build 中直接调用 syncFrom：它 notifyListeners 会让依赖中的
        //element 在 build 期间被 markNeedsBuild（框架断言风险）。
        //安排到帧后执行，语言切换最多晚一帧（~16ms）生效，无感。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appLocaleNotifier.syncFrom(config.english);
        });
        return MaterialApp(
          title: '清茫微记',
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          locale: config.english ? const Locale('en') : const Locale('zh'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          theme: glass
              ? FluidTheme.glassThemeData(isDark: false)
              : FluidTheme.lightThemeData,
          darkTheme: glass
              ? FluidTheme.glassThemeData(isDark: true)
              : FluidTheme.darkThemeData,
          themeMode: config.mode,
          // 全应用关闭越界回弹指示：列表页已不再提供"下拉刷新"，
          // 保留 Android 12+ 的拉伸/光晕反而像是有刷新动作却没生效
          scrollBehavior: const _AppScrollBehavior(),
          //GlassAmbientScope 始终存在（非玻璃风格时内部直接透传），
          //保证切换风格不会改变 Navigator 在树中的层级——
          //否则每次切换都会重建整棵导航树，页面状态（如引导页步骤）随之丢失
          builder: (context, child) {
            // 系统字体放大上限：本应用多处使用固定高度的卡片与"一行多列"布局，
            // Android 无障碍设置可放大到 2.0，届时这些位置会横向/纵向溢出。
            // 这里全局钳到 1.6 倍，兼顾放大可读性与布局完整性。
            final media = MediaQuery.of(context);
            final wrappedChild = TtsErrorHandler(
              navigatorKey: _navigatorKey,
              //全局氛围光斑：所有透明页面/玻璃组件共享同一折射背景源
              child: GlassAmbientScope(
                child: child ?? const SizedBox.shrink(),
              ),
            );
            return ValueListenableBuilder<double?>(
              valueListenable: InsetsProbe.instance.topInset,
              child: wrappedChild,
              builder: (context, androidTopInset, wrapped) {
                // Android 沉浸式（见 applySystemUiMode）：状态栏默认被系统隐藏，
                // 但部分 ROM 仍把 padding.top 报告成整条状态栏高度，
                // SafeArea 一避让就在顶部空出一条空白；直接归零又会让首行内容
                // 顶进直板机的居中挖孔。这里用原生探针的值（挖孔高度，或系统栏
                // 可见时的状态栏高度）做顶部避让，既铺满又不顶到摄像头；
                // 探针未上报前沿用引擎值，底部（手势条/键盘）避让保持原样。
                final topInset = isAndroidPlatform
                    ? (androidTopInset ?? media.padding.top)
                    : media.padding.top;
                final base = media.copyWith(
                  padding: media.padding.copyWith(top: topInset),
                  viewPadding: media.viewPadding.copyWith(top: topInset),
                );
                return MediaQuery(
                  data: base.copyWith(
                    // 只设上限：系统"缩小字体"（如 0.85）仍应生效，
                    // 设 minScaleFactor 会把用户的无障碍设置一并覆盖掉
                    textScaler: media.textScaler.clamp(maxScaleFactor: 1.6),
                  ),
                  //语言作用域：包在 Navigator 之上，语言切换时立即重建
                  //全站使用 context.tr 的组件（含列表已挂载的缓存项）；
                  //全局快捷键同样包在 Navigator 之上，push 出来的页面可用
                  child: withLocaleScope(
                    _GlobalShortcuts(
                      navigatorKey: _navigatorKey,
                      child: wrapped!,
                    ),
                  ),
                );
              },
            );
          },
          home: widget.home,
        );
      },
    );
  }
}

/// 全局键盘快捷键（仅桌面端注册）。
///
/// 包在 Navigator 之上：所有路由（5 个 Tab、学习页、阅读器、二级设置页）
/// 都能使用 Ctrl+1..5 / Ctrl+F / Ctrl+S。此前挂在 HomeScreen 内部，
/// 只覆盖 Tab 子树，push 出来的页面里快捷键全部失灵。
/// 切页统一走 [GuideService.requestTab]（HomeScreen 监听该信号并切 Tab），
/// 并先把 push 出来的页面出栈回主界面，避免"在阅读器里按 Ctrl+2
/// 看不到任何变化"。
class _GlobalShortcuts extends StatelessWidget {
  const _GlobalShortcuts({required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  void _backToMain() {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformAdapt.isDesktop) return child;
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.digit1, control: true):
            const _SwitchTabIntent(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true):
            const _SwitchTabIntent(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true):
            const _SwitchTabIntent(2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true):
            const _SwitchTabIntent(3),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true):
            const _SwitchTabIntent(4),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const _SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const _StudyIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SwitchTabIntent: CallbackAction<_SwitchTabIntent>(
            onInvoke: (intent) {
              _backToMain();
              GuideService.requestTab(intent.tabIndex);
              return null;
            },
          ),
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) {
              // 与点击首页搜索栏同一个入口：快捷搜索面板
              // （完整搜索页已删除，全应用的搜索只有这一个界面）
              final ctx = navigatorKey.currentContext;
              if (ctx != null && ctx.mounted) showQuickWordSearchSheet(ctx);
              return null;
            },
          ),
          _StudyIntent: CallbackAction<_StudyIntent>(
            onInvoke: (_) {
              // 回到首页，用户可从今日任务入口开始学习
              _backToMain();
              GuideService.requestTab(0);
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

class _SwitchTabIntent extends Intent {
  final int tabIndex;
  const _SwitchTabIntent(this.tabIndex);
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}

class _StudyIntent extends Intent {
  const _StudyIntent();
}

class _RuntimeServicesSync extends StatefulWidget {
  const _RuntimeServicesSync({required this.child});

  final Widget child;

  @override
  State<_RuntimeServicesSync> createState() => _RuntimeServicesSyncState();
}

class _RuntimeServicesSyncState extends State<_RuntimeServicesSync>
    with WidgetsBindingObserver {
  StudySettingsProvider? _settings;
  WordBookProvider? _wordBooks;
  ThemeProvider? _theme;
  bool? _lastIsOnlineAudio;
  String? _lastAccentType;
  double? _lastSpeechRate;
  DictionarySource? _lastDictionarySource;
  bool? _lastIsDark;

  /// 到次日 0 点触发一次"跨天刷新"的定时器。
  ///
  /// 只靠 lifecycle 的 resumed 判断跨天不够：Windows 桌面端把窗口一直开着
  /// 过夜（进程不重启、也不产生 resumed），首页的"今日任务/待复习/昨日已完成"
  /// 会整夜停在昨天。
  Timer? _midnightTimer;

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        _refreshIfDayChanged();
        _scheduleMidnightRefresh();
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    //记录启动当天：首次从后台回到前台时才能正确判断"是否已经跨天"
    _lastRefreshDate = DateTime.now().toIso8601String().substring(0, 10);
    _scheduleMidnightRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<StudySettingsProvider>();
    final wordBooks = context.read<WordBookProvider>();
    final theme = context.read<ThemeProvider>();
    if (_settings != settings || _wordBooks != wordBooks || _theme != theme) {
      _settings?.removeListener(_sync);
      _theme?.removeListener(_syncSystemUi);
      _settings = settings;
      _wordBooks = wordBooks;
      _theme = theme;
      _settings!.addListener(_sync);
      _theme!.addListener(_syncSystemUi);
      _sync();
      _syncSystemUi();
    }
  }

  void _syncSystemUi() {
    final theme = _theme;
    if (theme == null) return;
    final isDark = theme.isDarkMode;
    if (_lastIsDark == isDark) return;
    _lastIsDark = isDark;
    applySystemUiOverlay(isDark: isDark);
  }

  void _sync() {
    final provider = _settings;
    final wordBooks = _wordBooks;
    if (provider == null || wordBooks == null) return;
    final ttsChanged =
        _lastIsOnlineAudio != provider.isOnlineAudio ||
        _lastAccentType != provider.accentType ||
        _lastSpeechRate != provider.speechRate;
    if (ttsChanged) {
      _lastIsOnlineAudio = provider.isOnlineAudio;
      _lastAccentType = provider.accentType;
      _lastSpeechRate = provider.speechRate;
      DIContainer.instance.ttsService.init(
        isOnline: provider.isOnlineAudio,
        accent: provider.accentType,
        speechRate: provider.speechRate,
      );
    }
    if (_lastDictionarySource != provider.dictionarySource) {
      _lastDictionarySource = provider.dictionarySource;
      DefinitionService.setDictionarySource(provider.dictionarySource);
    }
    wordBooks.syncStreak(provider.streak);
  }

  /// 上次触发"跨天刷新"的日期（yyyy-MM-dd）
  String? _lastRefreshDate;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 仅真正后台/销毁时停 TTS；inactive 含下拉通知栏等短暂失焦，不停播
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      DIContainer.instance.ttsService.stop();
      // 在线真人发音用的是另一个播放器单例，TtsService.stop() 管不到它；
      // 退回桌面后仍在播的音频要在这里停掉
      unawaited(DictionaryApiService.stop());
      return;
    }
    // 回到前台重新应用沉浸式：部分 ROM 在切后台、输入法弹出后会把系统栏放出来
    if (state == AppLifecycleState.resumed) {
      applySystemUiMode();
      _refreshIfDayChanged();
    }
  }

  /// 回到前台时若已跨天，触发一次全局数据刷新。
  ///
  /// Android 上应用经常被挂在后台过夜（进程没被杀），直接回到前台时
  /// 首页的"今日任务 / 待复习 / 今日建议 / 薄弱词"仍是昨天的数据。
  void _refreshIfDayChanged() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_lastRefreshDate == today) return;
    _lastRefreshDate = today;
    AppInitializationService.notifyDatabaseRefreshed();
    _wordBooks?.refreshDueCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings?.removeListener(_sync);
    _theme?.removeListener(_syncSystemUi);
    _midnightTimer?.cancel();
    _midnightTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 应用级滚动行为：去掉 Android 的越界拉伸/光晕指示。
///
/// 列表页的下拉刷新入口已全部移除，越界指示会让用户误以为"正在刷新"，
/// 因此这里统一去掉（列表本身仍可正常滚动）。
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

/// 引导流程包装器
class _OnboardingWrapper extends StatefulWidget {
  final Widget child;

  const _OnboardingWrapper({required this.child});

  @override
  State<_OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<_OnboardingWrapper> {
  bool _showOnboarding = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    AppInitializationService.resetSignal.addListener(_showOnboardingAgain);
    _checkOnboarding();
  }

  @override
  void dispose() {
    AppInitializationService.resetSignal.removeListener(_showOnboardingAgain);
    super.dispose();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('hasSeenOnboarding') ?? false;
    //诊断"卸载重装仍跳过引导"：真机上用 adb logcat -s flutter 观察。
    //若全新安装却打出 true，说明该 ROM 重装时恢复了应用数据（prefs 没被清），
    //问题在系统层不在代码；若打出 false 却仍跳过，才需要继续查代码。
    debugPrint('[Onboarding] checkOnboarding: hasSeenOnboarding=$hasSeen');
    if (mounted) {
      setState(() {
        _showOnboarding = !hasSeen;
        _isInitialized = true;
      });
    }
  }

  void _showOnboardingAgain() {
    //已在引导页时忽略重复信号：初始化流程可能连发多次 resetSignal，
    //重复 setState 会让引导页 State 在路由栈未稳时重建
    if (_showOnboarding) return;
    //延迟到下一帧：初始化流程里 resetSignal 和 popUntil 几乎同时发生，
    //同步 setState 可能在旧路由尚未完全出栈时就触发引导页重建，
    //表现为引导页一闪而过。等一帧让路由栈稳定后再切换。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_showOnboarding) {
        setState(() => _showOnboarding = true);
      }
    });
  }

  void _onOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (mounted) {
      setState(() => _showOnboarding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 等待初始化完成
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_showOnboarding) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    return widget.child;
  }
}
