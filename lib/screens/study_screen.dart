import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/providers/providers.dart';
import '../services/di_container.dart';
import '../services/review_scheduler.dart';
import '../services/definition_service.dart';
import '../services/wrong_word_service.dart';
import '../services/tts_service.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/fluid_loading.dart';
import '../widgets/word_card.dart';
import '../widgets/study_components.dart';
import '../widgets/dictionary_dialog.dart';

/// 学习/复习页面 - 流体渐变风格
class StudyScreen extends StatefulWidget {
  final bool isReview;
  final int wordBookId;

  const StudyScreen({
    super.key,
    required this.isReview,
    required this.wordBookId,
  });

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with TickerProviderStateMixin {
  List<Word> _words = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isLoading = true;

  late AnimationController _cardAnimController;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;

  final Map<int, ReviewRecord?> _cachedRecords = {};
  bool _isSavingQuality = false;

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _cardSlideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutCubic),
    );
    _cardFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOut),
    );
    _loadWords();
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    final wordRepository = context.read<DIContainer>().wordRepository;
    final reviewRepository = context.read<DIContainer>().reviewRepository;
    List<Word> words;
    if (widget.isReview) {
      final dailyLimit = Provider.of<StudySettingsProvider>(
        context,
        listen: false,
      ).dailyReviewWords;
      words = await wordRepository.getDueWords(
        widget.wordBookId,
        limit: dailyLimit,
      );
    } else {
      final dailyLimit = Provider.of<StudySettingsProvider>(
        context,
        listen: false,
      ).dailyNewWords;
      words = await wordRepository.getNewWords(widget.wordBookId, dailyLimit);
    }

    final Map<int, ReviewRecord?> records = {};
    for (final w in words) {
      records[w.id!] = await reviewRepository.getReviewRecord(w.id!);
    }

    if (mounted) {
      final provider = Provider.of<StudySettingsProvider>(
        context,
        listen: false,
      );
      if (provider.useOnlineDefinition) {
        final limitedWords = words.take(20).toList();
        DefinitionService.prefetchDefinitions(limitedWords, max: 10);
      }
    }

    if (mounted) {
      setState(() {
        _words = words;
        _cachedRecords.addAll(records);
        _isLoading = false;
      });
      _cardAnimController.forward();
    }
  }

  Future<void> _onQualitySelected(int quality) async {
    if (_isSavingQuality) return;
    _isSavingQuality = true;

    final word = _words[_currentIndex];

    final record = _cachedRecords.containsKey(word.id!)
        ? (_cachedRecords[word.id!] ??
              ReviewScheduler.createInitialRecord(word.id!))
        : ReviewScheduler.createInitialRecord(word.id!);

    final nextRecord = ReviewScheduler.scheduleNextReview(record, quality);
    _cachedRecords[word.id!] = nextRecord;

    try {
      await context.read<DIContainer>().reviewRepository.saveReviewRecord(
        nextRecord,
      );

      if (quality < 3 && word.id != null) {
        await _addToWrongWords(word.id!);
      }
    } catch (e) {
      debugPrint('保存复习记录失败：$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr.saveRecordFailedHint)),
        );
      }
      _isSavingQuality = false;
      return;
    }

    _isSavingQuality = false;
    if (!mounted) return;

    if (_currentIndex < _words.length - 1) {
      _cardAnimController.reset();
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
      _preloadNextWordDefinition();
      _cardAnimController.forward();
      _playCurrentWord();
    } else {
      _finishStudy();
    }
  }

  Future<void> _addToWrongWords(int wordId) async {
    try {
      final service = WrongWordService();
      await service.init();
      await service.addWrongWord(wordId);
    } catch (e) {
      debugPrint('添加错词失败：$e');
    }
  }

  void _playCurrentWord() {
    if (_words.isEmpty || _currentIndex >= _words.length) return;

    final word = _words[_currentIndex];
    final ttsService = Provider.of<TtsService>(context, listen: false);
    ttsService.playWord(word.word);
  }

  Future<void> _ensureCurrentWordDefinition() async {
    final word = _words[_currentIndex];
    final definition = word.definition.trim();
    final hasValidDef =
        definition.isNotEmpty &&
        !definition.contains('释义待补充') &&
        !definition.contains('[释义');

    if (!hasValidDef) {
      final provider = Provider.of<StudySettingsProvider>(
        context,
        listen: false,
      );
      if (provider.useOnlineDefinition) {
        final updated = await DefinitionService.getWordWithDefinition(word);
        if (updated.definition != word.definition ||
            updated.phonetic != word.phonetic ||
            updated.example != word.example) {
          if (mounted) {
            setState(() {
              _words[_currentIndex] = updated;
            });
          }
        }
      }
    }
  }

  Future<void> _preloadNextWordDefinition() async {
    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _words.length) return;

    final nextWord = _words[nextIndex];
    final definition = nextWord.definition.trim();
    final hasValidDef =
        definition.isNotEmpty &&
        !definition.contains('释义待补充') &&
        !definition.contains('[释义');

    if (!hasValidDef) {
      final provider = Provider.of<StudySettingsProvider>(
        context,
        listen: false,
      );
      if (provider.useOnlineDefinition) {
        await DefinitionService.getWordWithDefinition(nextWord);
      }
    }
  }

  Future<void> _finishStudy() async {
    if (!mounted) return;
    final provider = Provider.of<StudySettingsProvider>(context, listen: false);
    await provider.updateStreak();
    if (mounted) {
      final isDark = context.read<ThemeProvider>().isDarkMode;
      showFluidDialog(
        context: context,
        barrierDismissible: false,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: Icon(
                  widget.isReview ? Icons.celebration : Icons.school,
                  size: 56,
                  color: FluidTheme.primaryFluidGradient[0],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isReview
                  ? context.tr.reviewCompleteTitle
                  : context.tr.studyCompleteTitle,
              style: FluidTheme.headingSmall.copyWith(
                color: FluidTheme.getTextPrimaryColor(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.isReview ? context.tr.todayStudiedCount : context.tr.todayLearnedCount}${_words.length}${context.tr.wordsCountSuffix}',
              style: FluidTheme.bodyMedium.copyWith(
                color: FluidTheme.getTextSecondaryColor(isDark),
              ),
            ),
            const SizedBox(height: 8),
            if (provider.streak > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text(
                    '${context.tr.streakDays} ${provider.streak}${context.tr.daysUnit}',
                    style: TextStyle(
                      color: FluidTheme.warningFluidGradient[0],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              Text(
                context.tr.keepGoing,
                style: FluidTheme.bodySmall.copyWith(
                  color: FluidTheme.getTextTertiaryColor(isDark),
                ),
              ),
          ],
        ),
        actions: [
          FluidButton(
            text: context.tr.backToHome,
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: FluidTheme.getBackgroundColor(isDark),
      appBar: _buildAppBar(),
      body: _isLoading
          ? Center(child: FluidLoading(message: context.tr.loadingText))
          : _words.isEmpty
          ? _buildEmptyState()
          : _buildStudyCard(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textColor = FluidTheme.getTextPrimaryColor(isDark);

    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: textColor,
      elevation: 0,
      title: Text(
        widget.isReview
            ? context.tr.reviewWordsTitle
            : context.tr.learnNewWordsTitle,
        style: FluidTheme.headingSmall.copyWith(color: textColor),
      ),
      actions: [
        if (_words.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: FluidTheme.primaryFluidGradient,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${_words.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return FluidBackground(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FluidGradientContainer(
                colors: FluidTheme.primaryFluidGradient,
                borderRadius: 50,
                padding: const EdgeInsets.all(24),
                child: const Icon(
                  Icons.celebration,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.isReview
                    ? context.tr.noReviewWords
                    : context.tr.noNewWords,
                style: FluidTheme.headingMedium.copyWith(
                  color: FluidTheme.getTextPrimaryColor(isDark),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr.greatKeepGoing,
                style: FluidTheme.bodyMedium.copyWith(
                  color: FluidTheme.getTextSecondaryColor(isDark),
                ),
              ),
              const SizedBox(height: 32),
              FluidButton(
                text: context.tr.back,
                icon: Icons.arrow_back,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudyCard() {
    final word = _words[_currentIndex];
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final hintColor = FluidTheme.getTextTertiaryColor(isDark);

    return Column(
      children: [
        // 进度条
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (_currentIndex + 1) / _words.length),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return LinearProgressIndicator(
              value: value,
              backgroundColor: FluidTheme.getBorderColor(isDark),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
              valueColor: AlwaysStoppedAnimation<Color>(
                FluidTheme.primaryFluidGradient[0],
              ),
            );
          },
        ),

        Expanded(
          child: GestureDetector(
            onPanEnd: _showAnswer
                ? (details) {
                    final velocity = details.velocity.pixelsPerSecond.dx;
                    if (velocity.abs() > 300) {
                      HapticFeedback.selectionClick();
                    }
                  }
                : null,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AnimatedBuilder(
                animation: _cardAnimController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _cardSlideAnimation.value),
                    child: Opacity(
                      opacity: _cardFadeAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    WordCard(
                      word: word,
                      showDefinition: _showAnswer,
                      onDictionaryQuery: (wordText) {
                        showDialog(
                          context: context,
                          builder: (ctx) => DictionaryDialog(word: wordText),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    if (!_showAnswer)
                      FluidButton(
                        text: context.tr.showDefinitionBtn,
                        icon: Icons.visibility_outlined,
                        expanded: true,
                        onPressed: () async {
                          final provider = Provider.of<StudySettingsProvider>(
                            context,
                            listen: false,
                          );
                          if (provider.useOnlineDefinition) {
                            final word = _words[_currentIndex];
                            final definition = word.definition.trim();
                            final hasValidDef =
                                definition.isNotEmpty &&
                                !definition.contains('释义待补充') &&
                                !definition.contains('[释义');
                            if (!hasValidDef) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.tr.fetchingDefinition,
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                              await _ensureCurrentWordDefinition();
                            }
                          }
                          if (mounted) {
                            setState(() => _showAnswer = true);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 评分按钮区域
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swipe_left, size: 14, color: hintColor),
                    const SizedBox(width: 4),
                    Text(
                      context.tr.swipeHint,
                      style: TextStyle(color: hintColor, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.swipe_right, size: 14, color: hintColor),
                  ],
                ),
              ),
              if (_showAnswer)
                QualityPanel(
                  isReview: widget.isReview,
                  onQualitySelected: _onQualitySelected,
                ),
            ],
          ),
          crossFadeState: _showAnswer
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }
}
