import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/services.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/ui_theme.dart';
import 'utils/theme/theme_provider.dart' as glass_theme;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows/Linux 桌面端需要 FFI 初始化（Web 平台不支持）
  if (!kIsWeb) {
    // 仅在非 Web 平台导入 dart:io
    // ignore: avoid_print
    print('Running on desktop platform');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 初始化依赖注入容器
  await DIContainer.instance.init();

  // 初始化通知服务
  await NotificationService().init();

  // 自动初始化内置词库（如果不存在）
  try {
    await SeedService.seedBuiltInData();
  } catch (e) {
    debugPrint('初始化内置词库失败：$e');
  }

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
        ChangeNotifierProvider(create: (_) => glass_theme.ThemeProvider()),
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
      child:
          Consumer4<
            ThemeProvider,
            WordBookProvider,
            StudySettingsProvider,
            DIContainer
          >(
            builder:
                (
                  context,
                  themeProvider,
                  wordBookProvider,
                  studySettingsProvider,
                  di,
                  child,
                ) {
                  // 仅在相关设置变化时同步服务配置，避免 build 中重复初始化。
                  _syncRuntimeServices(studySettingsProvider, di.ttsService);

                  // 同步 streak：StudySettingsProvider 是 streak 的唯一数据源
                  wordBookProvider.syncStreak(studySettingsProvider.streak);

                  return MaterialApp(
                    title: '清茫微记',
                    debugShowCheckedModeBanner: false,
                    locale: themeProvider.isEnglishLocale
                        ? const Locale('en')
                        : const Locale('zh'),
                    theme: UITheme.themeData,
                    darkTheme: UITheme.themeData,
                    themeMode: themeProvider.themeMode,
                    home: const _OnboardingWrapper(child: HomeScreen()),
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
