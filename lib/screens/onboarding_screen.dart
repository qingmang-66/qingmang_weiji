import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/translations.dart';

/// 新用户引导页面
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.auto_stories,
      titleKey: '欢迎使用清茫微记',
      titleKeyEn: 'Welcome to QingMang',
      descKey: '基于艾宾浩斯遗忘曲线，科学记忆英语单词',
      descKeyEn: 'Based on Ebbinghaus forgetting curve for effective vocabulary learning',
      color: const Color(0xFF6366F1),
    ),
    _OnboardingPage(
      icon: Icons.schedule,
      titleKey: '智能复习计划',
      titleKeyEn: 'Smart Review Schedule',
      descKey: 'AI算法自动安排复习时间，记得更牢固',
      descKeyEn: 'AI algorithm automatically schedules reviews for better retention',
      color: const Color(0xFF10B981),
    ),
    _OnboardingPage(
      icon: Icons.library_books,
      titleKey: '内置丰富词库',
      titleKeyEn: 'Built-in Word Books',
      descKey: '覆盖CET-4、CET-6、考研英语等常用词库',
      descKeyEn: 'Includes CET-4, CET-6, Graduate exams and more',
      color: const Color(0xFFF59E0B),
    ),
    _OnboardingPage(
      icon: Icons.insights,
      titleKey: '学习数据可视化',
      titleKeyEn: 'Learning Analytics',
      descKey: '查看学习进度、记忆曲线和统计数据',
      descKeyEn: 'Track progress, memory curves and learning statistics',
      color: const Color(0xFFEC4899),
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    widget.onComplete();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 跳过按钮
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  Translations.t('跳过', 'Skip'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            // 页面内容
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) => _buildPage(_pages[index], isEnglish),
              ),
            ),
            // 指示器
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            // 按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentPage == _pages.length - 1
                        ? Translations.t('开始学习', 'Get Started')
                        : Translations.t('下一步', 'Next'),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, bool isEnglish) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(
              page.icon,
              size: 64,
              color: page.color,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            isEnglish ? page.titleKeyEn : page.titleKey,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            isEnglish ? page.descKeyEn : page.descKey,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String titleKey;
  final String titleKeyEn;
  final String descKey;
  final String descKeyEn;
  final Color color;

  _OnboardingPage({
    required this.icon,
    required this.titleKey,
    required this.titleKeyEn,
    required this.descKey,
    required this.descKeyEn,
    required this.color,
  });
}