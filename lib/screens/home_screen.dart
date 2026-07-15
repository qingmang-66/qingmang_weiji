import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/providers/providers.dart';
import '../services/di_container.dart';
import '../services/notification_service.dart';
import '../services/study_plan_service.dart';
import '../services/app_initialization_service.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/translations.dart';
import '../utils/page_transitions.dart';
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
import 'favorites_screen.dart';
import 'custom_word_sets_screen.dart';
import '../widgets/recent_achievement_card.dart';
import '../widgets/weak_vocabulary_summary_card.dart';

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
  void initState() {
    super.initState();
    final notifications = DIContainer.instance.notificationService;
    notifications.pendingLaunchPayload.addListener(_onNotificationPayload);
    // 冷启动时可能已有 payload
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onNotificationPayload();
    });
  }

  @override
  void dispose() {
    DIContainer.instance.notificationService.pendingLaunchPayload
        .removeListener(_onNotificationPayload);
    super.dispose();
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;

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
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const _SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const _StudyIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SwitchTabIntent: CallbackAction<_SwitchTabIntent>(
            onInvoke: (intent) {
              setState(() => _currentIndex = intent.tabIndex);
              return null;
            },
          ),
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) {
              Navigator.push(
                context,
                PageTransitions.slideFromRight(page: const SearchScreen()),
              );
              return null;
            },
          ),
          _StudyIntent: CallbackAction<_StudyIntent>(
            onInvoke: (_) {
              // 切到首页，用户可从今日任务入口开始学习
              setState(() => _currentIndex = 0);
              return null;
            },
          ),
        },
        child: Builder(
          builder: (context) {
            final navPosition = context.watch<ThemeProvider>().navPosition;
            final useRail = navPosition == NavPosition.left;
            return Scaffold(
              backgroundColor: FluidTheme.getBackgroundColor(isDark),
              body: SafeArea(
                bottom: !useRail,
                child: useRail
                    ? Row(
                        children: [
                          _buildNavigationRail(isDark),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: IndexedStack(
                              index: _currentIndex,
                              children: [
                                for (var i = 0; i < _screens.length; i++)
                                  TickerMode(
                                    enabled: i == _currentIndex,
                                    child: _screens[i],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : IndexedStack(
                        index: _currentIndex,
                        children: [
                          for (var i = 0; i < _screens.length; i++)
                            TickerMode(
                              enabled: i == _currentIndex,
                              child: _screens[i],
                            ),
                        ],
                      ),
              ),
              bottomNavigationBar: useRail
                  ? null
                  : SafeArea(top: false, child: _buildBottomNavigationBar()),
            );
          },
        ),
      ),
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
            label: context.tr.navHome,
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined, color: inactiveColor),
            selectedIcon: Icon(
              Icons.menu_book,
              color: FluidTheme.primaryFluidGradient[2],
            ),
            label: context.tr.navWordBooks,
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined, color: inactiveColor),
            selectedIcon: Icon(
              Icons.bar_chart,
              color: FluidTheme.primaryFluidGradient[1],
            ),
            label: context.tr.navStats,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: inactiveColor),
            selectedIcon: Icon(
              Icons.settings,
              color: FluidTheme.primaryFluidGradient[2],
            ),
            label: context.tr.navSettings,
          ),
        ],
      ),
    );
  }

  /// 桌面端侧边导航栏
  Widget _buildNavigationRail(bool isDark) {
    final inactiveColor = FluidTheme.getTextTertiaryColor(isDark);
    final railBackground = isDark
        ? FluidTheme.background.withValues(alpha: 0.96)
        : FluidTheme.getElevatedSurfaceColor(isDark);
    return Container(
      width: 200,
      color: railBackground,
      child: NavigationRail(
        backgroundColor: Colors.transparent,
        indicatorColor: FluidTheme.primaryFluidGradient[0].withValues(
          alpha: isDark ? 0.22 : 0.16,
        ),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        labelType: NavigationRailLabelType.all,
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.22 : 0.12,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/app_icon_source_760.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(context.tr.appName, style: FluidTheme.labelMedium(isDark)),
            ],
          ),
        ),
        destinations: [
          NavigationRailDestination(
            icon: Icon(Icons.home_outlined, color: inactiveColor),
            selectedIcon: Icon(
              Icons.home,
              color: FluidTheme.primaryFluidGradient[0],
            ),
            label: Text(context.tr.navHome),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.menu_book_outlined, color: inactiveColor),
            selectedIcon: Icon(
              Icons.menu_book,
              color: FluidTheme.primaryFluidGradient[2],
            ),
            label: Text(context.tr.navWordBooks),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.bar_chart_outlined, color: inactiveColor),
            selectedIcon: Icon(
              Icons.bar_chart,
              color: FluidTheme.primaryFluidGradient[1],
            ),
            label: Text(context.tr.navStats),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.settings_outlined, color: inactiveColor),
            selectedIcon: Icon(
              Icons.settings,
              color: FluidTheme.primaryFluidGradient[2],
            ),
            label: Text(context.tr.navSettings),
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
  late Future<int> _wrongWordCountFuture;
  late Future<bool> _hasStudyProgressFuture;
  late Future<TodayTask> _todayTaskFuture;

  @override
  void initState() {
    super.initState();
    _wrongWordCountFuture = _getWrongWordCount();
    _hasStudyProgressFuture = DIContainer.instance.studyProgressRepository
        .hasStudyProgress();
    _todayTaskFuture = DIContainer.instance.studyPlanService.getTodayTask();
    AppInitializationService.databaseRefreshSignal.addListener(refreshData);
  }

  @override
  void dispose() {
    AppInitializationService.databaseRefreshSignal.removeListener(refreshData);
    super.dispose();
  }

  Future<int> _getWrongWordCount() async {
    try {
      final service = DIContainer.instance.wrongWordService;
      return await service.getWrongWordCount();
    } catch (e) {
      return 0;
    }
  }

  void refreshData() {
    setState(() {
      _wrongWordCountFuture = _getWrongWordCount();
      _hasStudyProgressFuture = DIContainer.instance.studyProgressRepository
          .hasStudyProgress();
      _todayTaskFuture = DIContainer.instance.studyPlanService.getTodayTask();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wordBookProvider = context.watch<WordBookProvider>();
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();

    Future<void> navigateToStudy({required bool isReview}) async {
      final currentBook = wordBookProvider.currentBook;
      if (currentBook == null || currentBook.id == null) return;

      final settings = context.read<StudySettingsProvider>();
      final availability = await context
          .read<DIContainer>()
          .reviewRepository
          .getStudyAvailability(
            currentBook.id!,
            isReview: isReview,
            dailyNewLimit: settings.dailyNewWords,
            dailyReviewLimit: settings.dailyReviewWords,
          );

      if (!context.mounted) return;
      if (!availability.canStart) {
        _showStudyUnavailableDialog(availability);
        return;
      }

      Navigator.of(context)
          .push(
            PageTransitions.slideFromRight(
              page: PreStudyScreen(
                isReview: isReview,
                wordBookId: currentBook.id!,
              ),
            ),
          )
          .then((_) {
            wordBookProvider.refreshDueCount();
            refreshData();
          });
    }

    Future<void> continueStudy(BuildContext context) async {
      final di = context.read<DIContainer>();
      final progress = await di.studyProgressRepository
          .getResumableStudyProgress();
      if (progress == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr.continueStudyUnavailable),
              behavior: SnackBarBehavior.floating,
            ),
          );
          refreshData();
        }
        return;
      }

      final wordBookId = progress['wordBookId'] as int;
      final studyMode = progress['studyMode'] as int;
      final isReview = progress['isReview'] as bool;
      final wordIds = progress['wordIds'] as List<int>;
      final source = progress['source'] as String?;
      final title = progress['title'] as String?;
      final progressKey = progress['progressKey'] as String?;

      final List<Word> words;
      try {
        words = source == StudySource.wrongWords.key
            ? await di.wrongWordService.getWrongWordsByIds(wordIds)
            : await di.wordRepository.getWordsByIds(wordIds);
      } catch (e) {
        if (context.mounted) {
          ErrorHandler.handleException(
            context,
            e,
            fallbackMessage: context.tr.loadingError,
          );
        }
        return;
      }
      if (words.isEmpty) return;

      if (context.mounted) {
        final Widget page;
        if (source == StudySource.wrongWords.key) {
          final request = SpecializedStudyRequest(
            source: StudySource.wrongWords,
            title: title ?? context.tr.wrongWordsReviewTitle,
            wordBookId: wordBookId == 0 ? null : wordBookId,
            wordIds: wordIds,
            studyMode: studyMode,
            isReview: isReview,
            explicitProgressKey: progressKey,
          );
          page = PreStudyScreen.specialized(request: request, words: words);
        } else {
          page = PreStudyScreen.continueStudy(
            wordBookId: wordBookId,
            words: words,
            studyMode: studyMode,
            isReview: isReview,
          );
        }

        Navigator.of(
          context,
        ).push(PageTransitions.slideFromRight(page: page)).then((_) {
          wordBookProvider.refreshDueCount();
          refreshData();
        });
      }
    }

    void switchToWordBook() {
      homeState?.switchToTab(1);
    }

    // SafeArea 已在 HomeScreen 外层处理
    return FluidBackground(
      child: wordBookProvider.isLoading
          ? Center(child: FluidLoading(message: context.tr.loading))
          : wordBookProvider.errorMessage != null
          ? _buildErrorState(context, wordBookProvider)
          : RefreshIndicator(
              onRefresh: () async {
                await wordBookProvider.loadWordBooks();
                refreshData();
              },
              color: FluidTheme.primaryFluidGradient[0],
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildAppBar(wordBookProvider),
                  const SizedBox(height: 24),
                  _buildTodayCard(wordBookProvider),
                  const SizedBox(height: 16),
                  const RecentAchievementCard(),
                  const SizedBox(height: 16),
                  const WeakVocabularySummaryCard(),
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
                    _buildHomeShortcutEntry(
                      title: context.tr.homeFavoritesTitle,
                      subtitle: context.tr.homeFavoritesSubtitle,
                      icon: Icons.bookmark,
                      colors: FluidTheme.primaryFluidGradient,
                      page: const FavoritesScreen(),
                    ),
                    const SizedBox(height: 12),
                    _buildHomeShortcutEntry(
                      title: context.tr.homeCustomSetsTitle,
                      subtitle: context.tr.homeCustomSetsSubtitle,
                      icon: Icons.folder_special,
                      colors: FluidTheme.successFluidGradient,
                      page: const CustomWordSetsScreen(),
                    ),
                    const SizedBox(height: 12),
                    _buildWrongWordsEntry(),
                  ],
                ],
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
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/app_icon_source_760.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          context.tr.appName,
          style: FluidTheme.headingMedium(isDark).copyWith(color: textColor),
        ),
        const Spacer(),
        if (provider.streak > 0) _buildStreakBadge(provider.streak),
        IconButton(
          icon: Icon(Icons.search, color: textColor.withValues(alpha: 0.8)),
          onPressed: () {
            Navigator.push(
              context,
              PageTransitions.slideFromRight(
                page: SearchScreen(wordBookId: provider.currentBook?.id),
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
            style: FluidTheme.numberStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建今日任务中心卡片
  Widget _buildTodayCard(WordBookProvider provider) {
    return FutureBuilder<TodayTask>(
      future: _todayTaskFuture,
      builder: (context, snapshot) {
        final task = snapshot.data;
        final completedNew = task?.completedNewWords ?? 0;
        final completedReview = task?.completedReviewWords ?? 0;
        final targetNew = task?.targetNewWords ?? provider.todayNewCount;
        final targetReview = task?.targetReviewWords ?? provider.dueCount;
        final totalTarget = targetNew + targetReview;
        final totalCompleted = completedNew + completedReview;
        final progress = totalTarget <= 0
            ? 1.0
            : (totalCompleted / totalTarget).clamp(0.0, 1.0);

        return FluidCard(
          enableShimmer: false,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FluidCardTitle(
                      text: context.tr.todayTask,
                      icon: Icons.wb_sunny_outlined,
                      gradientColors: FluidTheme.primaryFluidGradient,
                    ),
                  ),
                  if (task?.isCompleted == true)
                    Icon(Icons.check_circle, color: FluidTheme.success),
                ],
              ),
              if (task?.plan != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${context.tr.studyPlan}: ${task!.plan!.name}',
                  style:
                      FluidTheme.bodySmall(
                        context.watch<ThemeProvider>().isDarkMode,
                      ).copyWith(
                        color: FluidTheme.getTextSecondaryColor(
                          context.watch<ThemeProvider>().isDarkMode,
                        ),
                      ),
                ),
              ],
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: FluidTheme.primaryFluidGradient[0].withValues(
                  alpha: 0.12,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  FluidTheme.primaryFluidGradient[0],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTaskItem(
                      icon: Icons.add_circle_outline,
                      label: context.tr.todayTaskNew,
                      completed: completedNew,
                      target: targetNew,
                      colors: [
                        FluidTheme.accentSecondary,
                        FluidTheme.accentSecondary,
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTaskItem(
                      icon: Icons.replay_outlined,
                      label: context.tr.todayTaskReview,
                      completed: completedReview,
                      target: targetReview,
                      colors: FluidTheme.primaryFluidGradient.sublist(1, 3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建今日任务项
  Widget _buildTaskItem({
    required IconData icon,
    required String label,
    required int completed,
    required int target,
    required List<Color> colors,
  }) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
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
            value: '$completed/$target',
            gradientColors: colors,
            fontSize: 26,
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
            text: context.tr.currentBook,
            icon: Icons.menu_book,
            gradientColors: [
              FluidTheme.accentSecondary,
              FluidTheme.accentSecondary,
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currentBook.name,
            style: FluidTheme.headingSmall(
              isDark,
            ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
          ),
          const SizedBox(height: 6),
          Text(
            currentBook.description,
            style: FluidTheme.bodyMedium(
              isDark,
            ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
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
            context.tr.emptyWordBook,
            style: FluidTheme.headingSmall(
              isDark,
            ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr.emptyWordBookDesc,
            style: FluidTheme.bodyMedium(
              isDark,
            ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
          ),
          const SizedBox(height: 20),
          FluidButton(
            text: context.tr.goToWordBooks,
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
              text: context.tr.continueStudy,
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
    Future<void> Function({required bool isReview}) navigateToStudy,
  ) {
    if (provider.dueCount > 0) {
      return FluidButton(
        text: '${context.tr.startStudy} (${provider.dueCount})',
        icon: Icons.replay,
        expanded: true,
        onPressed: () => navigateToStudy(isReview: true),
      );
    } else {
      return FluidButton(
        text: context.tr.startNewWords,
        icon: Icons.school_outlined,
        expanded: true,
        onPressed: () => navigateToStudy(isReview: false),
      );
    }
  }

  void _showStudyUnavailableDialog(StudyAvailability availability) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final title = _availabilityTitle(availability.status);
    final description = _availabilityDescription(availability.status);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FluidTheme.getDialogSurfaceColor(isDark),
        title: Text(
          title,
          style: FluidTheme.headingSmall(
            isDark,
          ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: FluidTheme.bodyMedium(isDark).copyWith(
                color: FluidTheme.getTextSecondaryColor(isDark),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              availability.isReview
                  ? '${context.tr.todayProgress}：${availability.todayReviewedWords}/${availability.dailyReviewLimit}'
                  : '${context.tr.todayProgress}：${availability.todayNewWords}/${availability.dailyNewLimit}',
              style: FluidTheme.bodyMedium(
                isDark,
              ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
            ),
            const SizedBox(height: 6),
            Text(
              '${context.tr.remainingUnlearned}：${availability.unlearnedWords}',
              style: FluidTheme.bodyMedium(
                isDark,
              ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr.gotIt),
          ),
        ],
      ),
    );
  }

  String _availabilityTitle(StudyAvailabilityStatus status) {
    return switch (status) {
      StudyAvailabilityStatus.dailyNewCompleted =>
        context.tr.dailyNewCompletedTitle,
      StudyAvailabilityStatus.allNewWordsLearned =>
        context.tr.allNewWordsLearnedTitle,
      StudyAvailabilityStatus.noDueReviews => context.tr.noDueReviewsTitle,
      StudyAvailabilityStatus.dailyReviewCompleted =>
        context.tr.dailyReviewCompletedTitle,
      StudyAvailabilityStatus.emptyBook => context.tr.emptyWordBook,
      StudyAvailabilityStatus.available => context.tr.study,
    };
  }

  String _availabilityDescription(StudyAvailabilityStatus status) {
    return switch (status) {
      StudyAvailabilityStatus.dailyNewCompleted =>
        context.tr.dailyNewCompletedDesc,
      StudyAvailabilityStatus.allNewWordsLearned =>
        context.tr.allNewWordsLearnedDesc,
      StudyAvailabilityStatus.noDueReviews => context.tr.noDueReviewsDesc,
      StudyAvailabilityStatus.dailyReviewCompleted =>
        context.tr.dailyReviewCompletedDesc,
      StudyAvailabilityStatus.emptyBook => context.tr.emptyBookDesc,
      StudyAvailabilityStatus.available => context.tr.studyAdvice,
    };
  }

  /// 构建快捷操作标题
  Widget _buildQuickActionsTitle() {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Text(
      context.tr.quickActions,
      style: FluidTheme.headingSmall(
        isDark,
      ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
    );
  }

  /// 构建首页快捷入口
  Widget _buildHomeShortcutEntry({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required Widget page,
  }) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return FluidCard(
      enableShimmer: true,
      enableBorderGradient: true,
      borderColors: colors,
      padding: const EdgeInsets.all(16),
      onTap: () {
        Navigator.push(context, PageTransitions.slideFromRight(page: page));
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.first.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colors.first),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: FluidTheme.bodyMedium(
                    isDark,
                  ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
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
          enableShimmer: false,
          enableBorderGradient: true,
          borderColors: FluidTheme.errorFluidGradient,
          padding: const EdgeInsets.all(16),
          onTap: () {
            Navigator.push(
              context,
              PageTransitions.slideFromRight(page: const WrongWordsScreen()),
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
                      context.tr.wrongWords,
                      style: FluidTheme.labelLarge(
                        isDark,
                      ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$wrongCount${context.tr.wrongWordsCount}',
                      style: FluidTheme.bodyMedium(isDark).copyWith(
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
              context.tr.initFailed,
              style: FluidTheme.headingMedium(
                isDark,
              ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
            ),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage ?? context.tr.unknownError,
              textAlign: TextAlign.center,
              style: FluidTheme.bodyMedium(
                isDark,
              ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
            ),
            const SizedBox(height: 32),
            FluidButton(
              text: context.tr.retry,
              icon: Icons.refresh,
              onPressed: () => provider.init(),
            ),
          ],
        ),
      ),
    );
  }
}

// 键盘快捷键 Intent
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
