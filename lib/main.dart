import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/services.dart';
import 'utils/constants.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/ui_theme.dart';
import 'utils/theme/theme_provider.dart' as glass_theme;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面端（Windows/Linux）需要 FFI 初始化
  // Android/iOS 使用原生 sqflite 插件，无需 FFI
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 初始化依赖注入容器
  await DIContainer.instance.init();

  // 不再自动导入内置词库，由用户在词库页面手动选择添加

  runApp(const QingMangApp());
}

class QingMangApp extends StatefulWidget {
  const QingMangApp({super.key});

  @override
  State<QingMangApp> createState() => _QingMangAppState();
}

class _QingMangAppState extends State<QingMangApp> {
  bool? _lastIsOnlineAudio;
  String? _lastAccentType;
  double? _lastSpeechRate;
  DictionarySource? _lastDictionarySource;

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
      child: Consumer3<ThemeProvider, WordBookProvider, StudySettingsProvider>(
        builder:
            (
              context,
              themeProvider,
              wordBookProvider,
              studySettingsProvider,
              child,
            ) {
              // 副作用通过 addPostFrameCallback 延迟执行，避免在 build 中直接调用
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _syncRuntimeServices(studySettingsProvider, di.ttsService);
                wordBookProvider.syncStreak(studySettingsProvider.streak);
              });

              return MaterialApp(
                title: '清茫微记',
                debugShowCheckedModeBanner: false,
                locale: themeProvider.isEnglishLocale
                    ? const Locale('en')
                    : const Locale('zh'),
                theme: UITheme.themeData,
                darkTheme: UITheme.themeData,
                themeMode: themeProvider.themeMode,
                home: SplashScreen(
                  child: const _OnboardingWrapper(child: HomeScreen()),
                ),
              );
            },
      ),
    );
  }

  void _syncRuntimeServices(
    StudySettingsProvider provider,
    TtsService ttsService,
  ) {
    final ttsChanged =
        _lastIsOnlineAudio != provider.isOnlineAudio ||
        _lastAccentType != provider.accentType ||
        _lastSpeechRate != provider.speechRate;
    if (ttsChanged) {
      _lastIsOnlineAudio = provider.isOnlineAudio;
      _lastAccentType = provider.accentType;
      _lastSpeechRate = provider.speechRate;
      ttsService.init(
        isOnline: provider.isOnlineAudio,
        accent: provider.accentType,
        speechRate: provider.speechRate,
      );
    }

    if (_lastDictionarySource != provider.dictionarySource) {
      _lastDictionarySource = provider.dictionarySource;
      DefinitionService.setDictionarySource(provider.dictionarySource);
    }
  }
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
