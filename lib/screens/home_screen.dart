import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../services/wrong_word_service.dart';
import '../utils/constants.dart';
import '../utils/translations.dart';
import 'pre_study_screen.dart';
import 'wordbook_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import 'wrong_words_screen.dart';

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
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: Translations.t('首页', 'Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: Translations.t('词库', 'Books'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: Translations.t('统计', 'Stats'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: Translations.t('设置', 'Settings'),
          ),
        ],
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard();

  Future<int> _getWrongWordCount() async {
    try {
      final service = WrongWordService();
      await service.init();
      return await service.getWrongWordCount();
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();

    void navigateToStudy({required bool isReview}) {
      if (provider.currentBook == null || provider.currentBook!.id == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PreStudyScreen(
            isReview: isReview,
            wordBookId: provider.currentBook!.id!,
          ),
        ),
      ).then((_) => provider.refreshDueCount());
    }

    void switchToWordBook() {
      homeState?.switchToTab(1);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.auto_stories, size: 20, color: colorScheme.primary),
            ),
            const SizedBox(width: 10),
            const Text(AppConstants.appName),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchScreen(wordBookId: provider.currentBook?.id),
                ),
              );
            },
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.errorMessage != null
              ? _buildErrorState(context, provider)
              : RefreshIndicator(
                  onRefresh: () => provider.loadWordBooks(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.wb_sunny_outlined,
                                      color: colorScheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Today',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const Spacer(),
                                  if (provider.streak > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('🔥', style: TextStyle(fontSize: 14)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${provider.streak}',
                                            style: TextStyle(
                                              color: Colors.orange.shade800,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.add_circle_outline,
                                      label: Translations.t('新词', 'New'),
                                      value: provider.todayNewCount,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.replay_outlined,
                                      label: Translations.t('复习', 'Review'),
                                      value: provider.dueCount,
                                      color: colorScheme.tertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (provider.currentBook != null) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.menu_book,
                                        color: colorScheme.primary,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      Translations.t('当前词库', 'Current Book'),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  provider.currentBook!.name,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  provider.currentBook!.description,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (provider.currentBook == null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.menu_book_outlined,
                                    size: 48,
                                    color: colorScheme.outline,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  Translations.t('暂无词库', 'No word book yet'),
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  Translations.t('添加词库以开始学习', 'Add a word book to start learning'),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: switchToWordBook,
                                  icon: const Icon(Icons.add),
                                  label: Text(Translations.t('前往词库', 'Go to Books')),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...[
                          if (provider.dueCount > 0)
                            FilledButton.icon(
                              onPressed: () => navigateToStudy(isReview: true),
                              icon: const Icon(Icons.replay),
                              label: Text('Start Review (${provider.dueCount})'),
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                            )
                          else
                            FilledButton.icon(
                              onPressed: () => navigateToStudy(isReview: false),
                              icon: const Icon(Icons.school_outlined),
                              label: Text(Translations.t('开始学习新词', 'Start Learning New')),
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                            ),
                          const SizedBox(height: 28),
                          Text(
                            Translations.t('快捷操作', 'Quick Actions'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 12),
                          // 错词本入口（如果有错词）
                          FutureBuilder<int>(
                            future: _getWrongWordCount(),
                            builder: (context, snapshot) {
                              final wrongCount = snapshot.data;
                              if (wrongCount == null || wrongCount == 0) return const SizedBox.shrink();
                              
                              return Column(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const WrongWordsScreen(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.red.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.error_outline,
                                              color: Colors.red,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  Translations.t('错词本', 'Wrong Words'),
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                ),
                                                Text(
                                                  '$wrongCount 个单词需要加强',
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: Colors.red,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              );
                            },
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.add_circle_outline,
                                  label: Translations.t('学习新词', 'Learn New'),
                                  color: colorScheme.primary,
                                  onTap: () => navigateToStudy(isReview: false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.replay_outlined,
                                  label: Translations.t('复习', 'Review'),
                                  color: colorScheme.tertiary,
                                  onTap: () => navigateToStudy(isReview: true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  /// 构建错误状态 UI
  Widget _buildErrorState(BuildContext context, AppProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              Translations.t('加载失败', 'Failed to load'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.error,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage ?? Translations.t('未知错误', 'Unknown error'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => provider.loadWordBooks(),
              icon: const Icon(Icons.refresh),
              label: Text(Translations.t('重试', 'Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
