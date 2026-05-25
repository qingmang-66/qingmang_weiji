import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/providers/providers.dart';
import '../services/wrong_word_service.dart';
import '../services/database_service.dart';
import '../theme/fluid_theme.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_loading.dart';
import 'pre_study_screen.dart';
import 'wordbook_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import 'wrong_words_screen.dart';

/// 首页 - 流体渐变UI风格
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [
    _HomeDashboard(),
    WordBookScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  void switchToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: FluidTheme.getBackgroundColor(isDark),
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// 构建底部导航栏
  Widget _buildBottomNavigationBar() {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final inactiveColor = FluidTheme.getTextTertiaryColor(isDark);
    final navBackground = isDark
        ? FluidTheme.background.withValues(alpha: 0.96)
        : FluidTheme.getElevatedSurfaceColor(isDark);

    return Container(
      decoration: BoxDecoration(
        color: navBackground,
        border: Border(
          top: BorderSide(color: FluidTheme.getBorderColor(isDark), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        indicatorColor: FluidTheme.primaryFluidGradient[0].withValues(
          alpha: isDark ? 0.22 : 0.16,
        ),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: inactiveColor),
            selectedIcon: Icon(
              Icons.home,
              color: FluidTheme.primaryFluidGradient[0],
            ),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined, color: inactiveColor),
            selectedIcon: Icon(
              Icons.menu_book,
              color: FluidTheme.primaryFluidGradient[2],
            ),
            label: '词库',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined, color: inactiveColor),
            selectedIcon: Icon(
              Icons.bar_chart,
              color: FluidTheme.primaryFluidGradient[1],
            ),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: inactiveColor),
            selectedIcon: Icon(
              Icons.settings,
              color: FluidTheme.primaryFluidGradient[2],
            ),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

/// 首页仪表板
class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard();

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  late final Future<int> _wrongWordCountFuture;
  late final Future<bool> _hasStudyProgressFuture;

  @override
  void initState() {
    super.initState();
    _wrongWordCountFuture = _getWrongWordCount();
    _hasStudyProgressFuture = DatabaseService.hasStudyProgress();
  }

  Future<int> _getWrongWordCount() async {
    try {
      final service = WrongWordService();
      await service.init();
      return await service.getWrongWordCount();
    } catch (e) {
      return 0;
    }
  }

  void refreshData() {
    setState(() {
      _wrongWordCountFuture = _getWrongWordCount();
      _hasStudyProgressFuture = DatabaseService.hasStudyProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wordBookProvider = context.watch<WordBookProvider>();
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();

    void navigateToStudy({required bool isReview}) {
      final currentBook = wordBookProvider.currentBook;
      if (currentBook == null || currentBook.id == null) return;
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => PreStudyScreen(
                isReview: isReview,
                wordBookId: currentBook.id!,
              ),
            ),
          )
          .then((_) => wordBookProvider.refreshDueCount());
    }

    Future<void> continueStudy(BuildContext context) async {
      final progress = await DatabaseService.getStudyProgress();
      if (progress == null) return;

      final wordBookId = progress['wordBookId'] as int;
      final studyMode = progress['studyMode'] as int;
      final isReview = progress['isReview'] as bool;
      final wordIds = progress['wordIds'] as List<int>;

      final words = await DatabaseService.getWordsByIds(wordIds);
      if (words.isEmpty) return;

      if (context.mounted) {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => PreStudyScreen.continueStudy(
                  wordBookId: wordBookId,
                  words: words,
                  studyMode: studyMode,
                  isReview: isReview,
                ),
              ),
            )
            .then((_) => wordBookProvider.refreshDueCount());
      }
    }

    void switchToWordBook() {
      homeState?.switchToTab(1);
    }

    return FluidBackground(
      child: SafeArea(
        child: wordBookProvider.isLoading
            ? const Center(child: FluidLoading(message: '加载中...'))
            : wordBookProvider.errorMessage != null
            ? _buildErrorState(context, wordBookProvider)
            : RefreshIndicator(
                onRefresh: () => wordBookProvider.loadWordBooks(),
                color: FluidTheme.primaryFluidGradient[0],
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildAppBar(wordBookProvider),
                    const SizedBox(height: 24),
                    _buildTodayCard(wordBookProvider),
                    const SizedBox(height: 16),
                    if (wordBookProvider.currentBook != null) ...[
                      _buildCurrentBookCard(wordBookProvider),
                      const SizedBox(height: 16),
                    ],
                    if (wordBookProvider.currentBook == null)
                      _buildEmptyState(switchToWordBook)
                    else ...[
                      _buildContinueButton(context, continueStudy),
                      _buildStartButton(wordBookProvider, navigateToStudy),
                      const SizedBox(height: 28),
                      _buildQuickActionsTitle(),
                      const SizedBox(height: 12),
                      _buildWrongWordsEntry(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  /// 构建顶部标题栏
  Widget _buildAppBar(WordBookProvider provider) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = FluidTheme.getTextPrimaryColor(isDark);

    return Row(
      children: [
        FluidGradientContainer(
          colors: FluidTheme.primaryFluidGradient,
          borderRadius: FluidTheme.smallBorderRadius,
          padding: const EdgeInsets.all(10),
          animationDuration: const Duration(seconds: 8),
          child: const Icon(Icons.auto_stories, size: 24, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(
          '清茫微记',
          style: FluidTheme.headingMedium.copyWith(color: textColor),
        ),
        const Spacer(),
        if (provider.streak > 0) _buildStreakBadge(provider.streak),
        IconButton(
          icon: Icon(Icons.search, color: textColor.withValues(alpha: 0.8)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SearchScreen(wordBookId: provider.currentBook?.id),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 构建连续打卡徽章
  Widget _buildStreakBadge(int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: FluidTheme.warningFluidGradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: FluidTheme.warningFluidGradient[0].withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建今日学习卡片
  Widget _buildTodayCard(WordBookProvider provider) {
    return FluidCard(
      enableShimmer: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluidCardTitle(
            text: 'Today',
            icon: Icons.wb_sunny_outlined,
            gradientColors: FluidTheme.primaryFluidGradient,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.add_circle_outline,
                  label: '新词',
                  value: provider.todayNewCount,
                  colors: [
                    FluidTheme.accentSecondary,
                    FluidTheme.accentSecondary,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.replay_outlined,
                  label: '复习',
                  value: provider.dueCount,
                  colors: FluidTheme.primaryFluidGradient.sublist(1, 3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int value,
    required List<Color> colors,
  }) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = FluidTheme.getTextSecondaryColor(isDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors[0].withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors[0].withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: colors[0], size: 28),
          const SizedBox(height: 8),
          FluidCardNumber(
            value: '$value',
            gradientColors: colors,
            fontSize: 24,
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: textColor, fontSize: 14)),
        ],
      ),
    );
  }

  /// 构建当前词库卡片
  Widget _buildCurrentBookCard(WordBookProvider provider) {
    final currentBook = provider.currentBook!;
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return FluidCard(
      enableShimmer: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FluidCardTitle(
            text: '当前词库',
            icon: Icons.menu_book,
            gradientColors: [
              FluidTheme.accentSecondary,
              FluidTheme.accentSecondary,
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currentBook.name,
            style: FluidTheme.headingSmall.copyWith(
              color: FluidTheme.getTextPrimaryColor(isDark),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            currentBook.description,
            style: FluidTheme.bodyMedium.copyWith(
              color: FluidTheme.getTextSecondaryColor(isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(VoidCallback onSwitchToWordBook) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          FluidGradientContainer(
            colors: FluidTheme.primaryFluidGradient,
            borderRadius: 50,
            padding: const EdgeInsets.all(20),
            child: const Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '暂无词库',
            style: FluidTheme.headingSmall.copyWith(
              color: FluidTheme.getTextPrimaryColor(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '添加词库以开始学习',
            style: FluidTheme.bodyMedium.copyWith(
              color: FluidTheme.getTextSecondaryColor(isDark),
            ),
          ),
          const SizedBox(height: 20),
          FluidButton(
            text: '前往词库',
            icon: Icons.add,
            onPressed: onSwitchToWordBook,
          ),
        ],
      ),
    );
  }

  /// 构建继续学习按钮
  Widget _buildContinueButton(
    BuildContext context,
    Future<void> Function(BuildContext) continueStudy,
  ) {
    return FutureBuilder<bool>(
      future: _hasStudyProgressFuture,
      builder: (context, snapshot) {
        final hasProgress = snapshot.data ?? false;
        if (!hasProgress) return const SizedBox.shrink();

        return Column(
          children: [
            FluidButton(
              text: '继续上次学习',
              icon: Icons.play_arrow,
              colors: FluidTheme.warningFluidGradient,
              expanded: true,
              onPressed: () => continueStudy(context),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  /// 构建开始学习按钮
  Widget _buildStartButton(
    WordBookProvider provider,
    void Function({required bool isReview}) navigateToStudy,
  ) {
    if (provider.dueCount > 0) {
      return FluidButton(
        text: 'Start Review (${provider.dueCount})',
        icon: Icons.replay,
        expanded: true,
        onPressed: () => navigateToStudy(isReview: true),
      );
    } else {
      return FluidButton(
        text: '开始学习新词',
        icon: Icons.school_outlined,
        expanded: true,
        onPressed: () => navigateToStudy(isReview: false),
      );
    }
  }

  /// 构建快捷操作标题
  Widget _buildQuickActionsTitle() {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Text(
      '快捷操作',
      style: FluidTheme.headingSmall.copyWith(
        color: FluidTheme.getTextPrimaryColor(isDark),
      ),
    );
  }

  /// 构建错词本入口
  Widget _buildWrongWordsEntry() {
    return FutureBuilder<int>(
      future: _wrongWordCountFuture,
      builder: (context, snapshot) {
        final wrongCount = snapshot.data;
        final isDark = context.watch<ThemeProvider>().isDarkMode;
        if (wrongCount == null || wrongCount == 0) {
          return const SizedBox.shrink();
        }

        return FluidCard(
          enableShimmer: true,
          enableBorderGradient: true,
          borderColors: FluidTheme.errorFluidGradient,
          padding: const EdgeInsets.all(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WrongWordsScreen()),
            );
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FluidTheme.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.error_outline, color: FluidTheme.error),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '错词本',
                      style: FluidTheme.labelLarge.copyWith(
                        color: FluidTheme.getTextPrimaryColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$wrongCount 个错词',
                      style: FluidTheme.bodyMedium.copyWith(
                        color: FluidTheme.getTextSecondaryColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: FluidTheme.getTextTertiaryColor(isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建错误状态
  Widget _buildErrorState(BuildContext context, WordBookProvider provider) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: FluidTheme.error),
            const SizedBox(height: 24),
            Text(
              '初始化失败',
              style: FluidTheme.headingMedium.copyWith(
                color: FluidTheme.getTextPrimaryColor(isDark),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage ?? '未知错误',
              textAlign: TextAlign.center,
              style: FluidTheme.bodyMedium.copyWith(
                color: FluidTheme.getTextSecondaryColor(isDark),
              ),
            ),
            const SizedBox(height: 32),
            FluidButton(
              text: '重试',
              icon: Icons.refresh,
              onPressed: () => provider.init(),
            ),
          ],
        ),
      ),
    );
  }
}
