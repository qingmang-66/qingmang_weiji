import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/providers/providers.dart';
import '../services/wrong_word_service.dart';
import '../services/database_service.dart';
import '../widgets/home_components.dart';
import '../utils/constants.dart';
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
            label: '首页',
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: '词库',
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: '设置',
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
    final wordBookProvider = context.watch<WordBookProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();

    void navigateToStudy({required bool isReview}) {
      final currentBook = wordBookProvider.currentBook;
      if (currentBook == null || currentBook.id == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PreStudyScreen(
            isReview: isReview,
            wordBookId: currentBook.id!,
          ),
        ),
      ).then((_) => wordBookProvider.refreshDueCount());
    }

    /// 继续上次未完成的学��
    Future<void> continueStudy(BuildContext context) async {
      final progress = await DatabaseService.getStudyProgress();
      if (progress == null) return;

      final wordBookId = progress['wordBookId'] as int;
      final studyMode = progress['studyMode'] as int;
      final isReview = progress['isReview'] as bool;
      final wordIds = progress['wordIds'] as List<int>;

      // 获取单词详情
      final words = await DatabaseService.getWordsByIds(wordIds);
      if (words.isEmpty) return;

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PreStudyScreen.continueStudy(
              wordBookId: wordBookId,
              words: words,
              studyMode: studyMode,
              isReview: isReview,
            ),
          ),
        ).then((_) => wordBookProvider.refreshDueCount());
      }
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
                  builder: (_) => SearchScreen(wordBookId: wordBookProvider.currentBook?.id),
                ),
              );
            },
          ),
        ],
      ),
      body: wordBookProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : wordBookProvider.errorMessage != null
              ? _buildErrorState(context, wordBookProvider)
              : RefreshIndicator(
                  onRefresh: () => wordBookProvider.loadWordBooks(),
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
                                  if (wordBookProvider.streak > 0)
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
                                            '${wordBookProvider.streak}',
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
                                    child: StatCard(
                                      icon: Icons.add_circle_outline,
                                      label: '新词',
                                      value: wordBookProvider.todayNewCount,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: StatCard(
                                      icon: Icons.replay_outlined,
                                      label: '复习',
                                      value: wordBookProvider.dueCount,
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
                      if (wordBookProvider.currentBook != null) ...[
                        Builder(
                          builder: (context) {
                            final currentBook = wordBookProvider.currentBook!;
                            return Column(
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
                                              '当前词库',
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          currentBook.name,
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          currentBook.description,
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
                            );
                          },
                        ),
                      ],
                      if (wordBookProvider.currentBook == null)
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
                                  '暂无词库',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '添加词库以开始学习',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: switchToWordBook,
                                  icon: const Icon(Icons.add),
                                  label: const Text('前往词库'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...[
                          // 继续学习按钮（如果有未完成的进度）
                          FutureBuilder<bool>(
                            future: DatabaseService.hasStudyProgress(),
                            builder: (context, snapshot) {
                              final hasProgress = snapshot.data ?? false;
                              if (!hasProgress) return const SizedBox.shrink();

                              return Column(
                                children: [
                                  FilledButton.icon(
                                    onPressed: () => continueStudy(context),
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('继续上次学习'),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(56),
                                      backgroundColor: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              );
                            },
                          ),
                          if (wordBookProvider.dueCount > 0)
                            FilledButton.icon(
                              onPressed: () => navigateToStudy(isReview: true),
                              icon: const Icon(Icons.replay),
                              label: Text('Start Review (${wordBookProvider.dueCount})'),
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                            )
                          else
                            FilledButton.icon(
                              onPressed: () => navigateToStudy(isReview: false),
                              icon: const Icon(Icons.school_outlined),
                              label: const Text('开始学习新词'),
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                            ),
                          const SizedBox(height: 28),
                          Text(
                            '快捷操作',
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
                                                  '错词本',
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
                                child: QuickAction(
                                  icon: Icons.add_circle_outline,
                                  label: '学习新词',
                                  color: colorScheme.primary,
                                  onTap: () => navigateToStudy(isReview: false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: QuickAction(
                                  icon: Icons.replay_outlined,
                                  label: '复习',
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
  Widget _buildErrorState(BuildContext context, WordBookProvider provider) {
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
              '加载失败',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.error,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage ?? '未知错误',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => provider.loadWordBooks(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
