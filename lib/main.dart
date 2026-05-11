import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/app_provider.dart';
import 'services/seed_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'utils/theme.dart';
import 'utils/translations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Windows/Linux 桌面端需要 FFI 初始化
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
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

class QingMangApp extends StatelessWidget {
  const QingMangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            title: '清茫微记',
            debugShowCheckedModeBanner: false,
            locale: provider.isEnglishLocale ? const Locale('en') : const Locale('zh'),
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: provider.isLoading
                ? const _SplashScreen()
                : provider.hasInitError
                    ? const _ErrorScreen()
                    : _OnboardingWrapper(
              child: const HomeScreen(),
            ),
          );
        },
      ),
    );
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
    _checkOnboarding();
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showOnboarding) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    return widget.child;
  }
}

/// 启动骨架屏
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.auto_stories,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              Translations.t('清茫微记', 'QingMang Notes'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              Translations.t('让记忆更简单', 'Make memory easier'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// 错误页面
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    Translations.t('初始化失败', 'Initialization Failed'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage ?? Translations.t('未知错误', 'Unknown error'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      provider.init();
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(Translations.t('重试', 'Retry')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
