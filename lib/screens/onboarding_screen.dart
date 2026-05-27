import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/providers/providers.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_card.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _OnboardingLanguage { zh, en, bilingual }

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  _OnboardingLanguage _selectedLanguage = _OnboardingLanguage.bilingual;

  late final List<_OnboardingPage> _pages = _buildPages();

  List<_OnboardingPage> _buildPages() {
    return [
      _OnboardingPage(
        icon: Icons.auto_stories,
        titleKey: context.tr.welcomeTitle,
        titleKeyEn: 'Welcome to QingMang',
        descKey: context.tr.welcomeDesc,
        descKeyEn:
            'A vocabulary learning app built around word books, review planning, and learning feedback.',
        highlights: [
          context.tr.hlWordBookMgmt,
          context.tr.hlSmartReview,
          context.tr.hlAnalytics,
        ],
        highlightsEn: ['Word books', 'Smart review', 'Analytics'],
        color: const Color(0xFF6366F1),
      ),
      _OnboardingPage(
        icon: Icons.library_books,
        titleKey: context.tr.chooseBookTitle,
        titleKeyEn: 'Start with the right word book',
        descKey: context.tr.chooseBookDesc,
        descKeyEn:
            'Use built-in junior, senior, CET, graduate, TOEFL, and SAT books, or import your own.',
        highlights: [
          context.tr.hlBuiltInBooks,
          context.tr.hlCustomBooks,
          context.tr.hlBatchActions,
        ],
        highlightsEn: ['Built-in books', 'Custom books', 'Batch actions'],
        color: const Color(0xFFF59E0B),
      ),
      _OnboardingPage(
        icon: Icons.psychology_alt,
        titleKey: context.tr.practiceModesTitle,
        titleKeyEn: 'Practice with multiple modes',
        descKey: context.tr.practiceModesDesc,
        descKeyEn:
            'Recall, spelling, listening, and two-way quizzes reinforce words from different angles.',
        highlights: [
          context.tr.hlRecallMode,
          context.tr.hlSpellingListening,
          context.tr.hlTwoWayQuiz,
        ],
        highlightsEn: ['Recall', 'Spelling & listening', 'Two-way quiz'],
        color: const Color(0xFF10B981),
      ),
      _OnboardingPage(
        icon: Icons.schedule,
        titleKey: context.tr.reviewScheduleTitle,
        titleKeyEn: 'Review on a memory schedule',
        descKey: context.tr.reviewScheduleDesc,
        descKeyEn:
            'Your results become review records, helping you focus on words that need reinforcement.',
        highlights: [
          context.tr.hlDueReview,
          context.tr.hlMemoryStages,
          context.tr.hlStreaks,
        ],
        highlightsEn: ['Due review', 'Memory stages', 'Streaks'],
        color: const Color(0xFF4FACFE),
      ),
      _OnboardingPage(
        icon: Icons.insights,
        titleKey: context.tr.dataProgressTitle,
        titleKeyEn: 'See progress through data',
        descKey: context.tr.dataProgressDesc,
        descKeyEn:
            'The statistics page shows calendar activity, review trends, memory stages, and vocabulary estimates.',
        highlights: [
          context.tr.hlCalendar,
          context.tr.hlReviewTrend,
          context.tr.hlVocabEstimate,
        ],
        highlightsEn: ['Calendar', 'Review trend', 'Vocabulary estimate'],
        color: const Color(0xFFEC4899),
      ),
    ];
  }

  int get _totalPages => _pages.length + 1;

  bool get _isEnglish => _selectedLanguage == _OnboardingLanguage.en;

  void _nextPage() {
    if (_currentPage == 0) {
      _applyLanguageSelection();
    }
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _applyLanguageSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('onboardingLanguage', _selectedLanguage.name);
    if (!mounted) return;
    await context.read<ThemeProvider>().setEnglishLocale(_isEnglish);
  }

  Future<void> _completeOnboarding() async {
    await _applyLanguageSelection();
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final indicatorInactiveColor = FluidTheme.getBorderColor(isDark);

    return FluidBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 12),
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      context.tr.skip,
                      style: FluidTheme.labelLarge.copyWith(
                        color: FluidTheme.primaryFluidGradient[0],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemCount: _totalPages,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildLanguagePage(isDark);
                    return _buildPage(_pages[index - 1], isDark);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _totalPages,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? FluidTheme.primaryFluidGradient[0]
                            : indicatorInactiveColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: FluidButton(
                  text: _currentPage == _totalPages - 1
                      ? _localized(context.tr.getStarted, 'Get Started')
                      : _localized(context.tr.nextStep, 'Next'),
                  icon: _currentPage == _totalPages - 1
                      ? Icons.rocket_launch
                      : Icons.arrow_forward,
                  expanded: true,
                  onPressed: _nextPage,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  fontSize: 18,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: FluidTheme.bodySmall.copyWith(color: textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguagePage(bool isDark) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
      child: Center(
        child: FluidCard(
          enableShimmer: true,
          enableBorderGradient: true,
          borderColors: [
            FluidTheme.primaryFluidGradient[0],
            FluidTheme.primaryFluidGradient[2].withValues(alpha: 0.45),
          ],
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FluidGradientContainer(
                  colors: FluidTheme.primaryFluidGradient,
                  borderRadius: 28,
                  padding: const EdgeInsets.all(22),
                  child: const Icon(
                    Icons.translate,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  context.tr.chooseGuideLanguage,
                  style: FluidTheme.headingMedium.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr.guideLanguageDesc,
                  style: FluidTheme.bodyMedium.copyWith(
                    color: textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildLanguageOption(
                      value: _OnboardingLanguage.zh,
                      title: context.tr.languageZh,
                      subtitle: context.tr.languageZhDesc,
                      icon: Icons.text_fields,
                      isDark: isDark,
                    ),
                    _buildLanguageOption(
                      value: _OnboardingLanguage.en,
                      title: context.tr.languageEn,
                      subtitle: context.tr.languageEnDesc,
                      icon: Icons.language,
                      isDark: isDark,
                    ),
                    _buildLanguageOption(
                      value: _OnboardingLanguage.bilingual,
                      title: context.tr.languageBilingual,
                      subtitle: context.tr.languageBilingualDesc,
                      icon: Icons.compare_arrows,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required _OnboardingLanguage value,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    final selected = _selectedLanguage == value;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return InkWell(
      onTap: () => setState(() => _selectedLanguage = value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 176,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? FluidTheme.primaryFluidGradient[0].withValues(
                  alpha: isDark ? 0.22 : 0.14,
                )
              : FluidTheme.getMutedOverlayColor(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? FluidTheme.primaryFluidGradient[0]
                : FluidTheme.getBorderColor(isDark),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: FluidTheme.primaryFluidGradient[0], size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: FluidTheme.labelLarge.copyWith(color: textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: FluidTheme.bodySmall.copyWith(
                color: textSecondary,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, bool isDark) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
      child: Center(
        child: FluidCard(
          enableShimmer: true,
          enableBorderGradient: true,
          borderColors: [page.color, page.color.withValues(alpha: 0.45)],
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: page.color.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: page.color.withValues(alpha: isDark ? 0.32 : 0.22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: page.color.withValues(
                          alpha: isDark ? 0.22 : 0.12,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Icon(page.icon, size: 60, color: page.color),
                ),
                const SizedBox(height: 30),
                Text(
                  _localized(page.titleKey, page.titleKeyEn),
                  style: FluidTheme.headingMedium.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  _localized(page.descKey, page.descKeyEn),
                  style: FluidTheme.bodyMedium.copyWith(
                    color: textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: List.generate(page.highlights.length, (index) {
                    final label = _localized(
                      page.highlights[index],
                      page.highlightsEn[index],
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: page.color.withValues(
                          alpha: isDark ? 0.16 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: page.color.withValues(
                            alpha: isDark ? 0.28 : 0.22,
                          ),
                        ),
                      ),
                      child: Text(
                        label,
                        style: FluidTheme.bodySmall.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _localized(String zh, String en) {
    switch (_selectedLanguage) {
      case _OnboardingLanguage.zh:
        return zh;
      case _OnboardingLanguage.en:
        return en;
      case _OnboardingLanguage.bilingual:
        return '$zh / $en';
    }
  }
}

class _OnboardingPage {
  final IconData icon;
  final String titleKey;
  final String titleKeyEn;
  final String descKey;
  final String descKeyEn;
  final List<String> highlights;
  final List<String> highlightsEn;
  final Color color;

  _OnboardingPage({
    required this.icon,
    required this.titleKey,
    required this.titleKeyEn,
    required this.descKey,
    required this.descKeyEn,
    required this.highlights,
    required this.highlightsEn,
    required this.color,
  });
}
