import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/platform_db_init.dart';
import 'services/services.dart';
import 'services/local_dictionary_service.dart';
import 'utils/constants.dart';
import 'utils/system_ui.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/fluid_theme.dart';
import 'utils/theme/theme_provider.dart' as glass_theme;
import 'widgets/unlock_celebration_banner.dart';
import 'widgets/tts_error_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge：内容可延伸到系统栏下方，由 Flutter SafeArea 避让
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  applySystemUiOverlay(isDark: false);

  // 根据平台初始化数据库引擎（Web/Desktop/Mobile）
  initDatabaseFactory();

  // 初始化依赖注入容器
  await DIContainer.instance.init();

  // 词典大库不在启动时拷贝，首帧后再后台预热（Web端跳过，无法拷贝本地文件）
  if (!kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocalDictionaryService.warmUpInBackground();
    });
  }

  // 不再自动导入内置词库，由用户在词库页面手动选择添加

  runApp(const QingMangApp());
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
        ChangeNotifierProvider(create: (_) => glass_theme.GlassThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider()..loadPreferences(),
        ),
        ChangeNotifierProvider(create: (_) => WordBookProvider()..init()),
        ChangeNotifierProvider(
          create: (_) => StudySettingsProvider()..loadPreferences(),
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
    return Selector<ThemeProvider, ({ThemeMode mode, bool english})>(
      selector: (_, provider) =>
          (mode: provider.themeMode, english: provider.isEnglishLocale),
      builder: (context, config, _) => MaterialApp(
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
        theme: FluidTheme.lightThemeData,
        darkTheme: FluidTheme.darkThemeData,
        themeMode: config.mode,
        builder: (context, child) => TtsErrorHandler(
          navigatorKey: _navigatorKey,
          child: UnlockCelebrationBanner(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: widget.home,
      ),
    );
  }
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 仅真正后台/销毁时停 TTS；inactive 含下拉通知栏等短暂失焦，不停播
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      DIContainer.instance.ttsService.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings?.removeListener(_sync);
    _theme?.removeListener(_syncSystemUi);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    if (mounted) {
      setState(() {
        _showOnboarding = !hasSeen;
        _isInitialized = true;
      });
    }
  }

  void _showOnboardingAgain() {
    if (mounted) {
      setState(() => _showOnboarding = true);
    }
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
