import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/providers/providers.dart';
import '../services/di_container.dart';
import '../services/review_scheduler.dart';
import '../services/definition_service.dart';
import '../services/tts_service.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/translations.dart';
import '../widgets/favorite_sheet.dart';
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
  bool _isCurrentWordFavorite = false;

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
    try {
      List<Word> words;
      if (widget.isReview) {
        final dailyLimit = Provider.of<StudySettingsProvider>(
          context,
          listen: false,
        ).dailyReviewWords;
        words = await wordRepository.getDueWordsWithinDailyRemaining(
          widget.wordBookId,
          dailyLimit: dailyLimit,
        );
      } else {
        final dailyLimit = Provider.of<StudySettingsProvider>(
          context,
          listen: false,
        ).dailyNewWords;
        words = await wordRepository.getNewWordsWithinDailyRemaining(
          widget.wordBookId,
          dailyLimit: dailyLimit,
        );
      }

      final wordIds = words
          .map((w) => w.id)
          .whereType<int>()
          .toList(growable: false);
      final records = await reviewRepository.getReviewRecordsByWordIds(wordIds);

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
        _refreshCurrentFavorite();
      }
    } catch (e) {
      debugPrint('StudyScreen._loadWords error: $e');
      if (!mounted) return;
      setState(() {
        _words = [];
        _isLoading = false;
      });
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: context.tr.loadingError,
      );
    }
  }

  Future<void> _onQualitySelected(int quality) async {
    if (_isSavingQuality) return;
    _isSavingQuality = true;

    final word = _words[_currentIndex];

    final record =
        _cachedRecords[word.id!] ??
        ReviewScheduler.createInitialRecord(word.id!);

    final nextRecord = ReviewScheduler.scheduleNextReview(record, quality);
    try {
      await context.read<DIContainer>().reviewRepository.saveReviewRecord(
        nextRecord,
        bookId: widget.wordBookId,
      );

      _cachedRecords[word.id!] = nextRecord;
      if (quality < 3 && word.id != null) {
        await _addToWrongWords(word.id!);
      }
    } catch (e) {
      debugPrint('保存复习记录失败：$e');
      if (mounted) {
        ErrorHandler.handleException(
          context,
          e,
          fallbackMessage: context.tr.saveRecordFailedHint,
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
      final provider = Provider.of<StudySettingsProvider>(
        context,
        listen: false,
      );
      if (provider.autoPlayAudio) {
        _playCurrentWord();
      }
      _refreshCurrentFavorite();
    } else {
      _finishStudy();
    }
  }

  /// 刷新当前单词的收藏状态
  Future<void> _refreshCurrentFavorite() async {
    if (!mounted || _words.isEmpty) return;
    final word = _words[_currentIndex];
    final wordId = word.id;
    if (wordId == null) {
      if (mounted) setState(() => _isCurrentWordFavorite = false);
      return;
    }
    final isFav = await DIContainer.instance.favoriteRepository.isFavorite(
      wordId,
    );
    if (!mounted) return;
    setState(() => _isCurrentWordFavorite = isFav);
  }

  /// 点击 ⭐ 收藏当前单词
  Future<void> _onFavoriteCurrentWord() async {
    if (_words.isEmpty) return;
    final word = _words[_currentIndex];
    final wordId = word.id;
    if (wordId == null) return;
    final repo = DIContainer.instance.favoriteRepository;
    if (_isCurrentWordFavorite) {
      // 已收藏：直接取消（避免打断学习节奏）
      try {
        await repo.removeFavorite(wordId);
        if (!mounted) return;
        setState(() => _isCurrentWordFavorite = false);
        ErrorHandler.showSuccess(context, context.tr.removedFromFavorites);
      } catch (e) {
        if (!mounted) return;
        ErrorHandler.handleException(
          context,
          e,
          fallbackMessage: context.tr.removeFavoriteFailed,
        );
      }
    } else {
      final result = await showFavoriteSheet(context, wordId: wordId);
      if (result == null || !mounted) return;
      try {
        await repo.addFavorite(
          wordId: wordId,
          groupName: result.groupName,
          note: result.note,
        );
        if (!mounted) return;
        setState(() => _isCurrentWordFavorite = true);
        ErrorHandler.showSuccess(context, context.tr.addedToFavorites);
      } catch (e) {
        if (!mounted) return;
        ErrorHandler.handleException(
          context,
          e,
          fallbackMessage: context.tr.addToFavoritesFailed,
        );
      }
    }
  }

  Future<void> _addToWrongWords(int wordId) async {
    try {
      final service = context.read<DIContainer>().wrongWordService;
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
    // 学习完成后刷新周报缓存
    if (mounted) {
      context.read<DIContainer>().weeklyReportService.invalidate();
    }
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
              style: FluidTheme.headingSmall(
                isDark,
              ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.isReview ? context.tr.todayStudiedCount : context.tr.todayLearnedCount}${_words.length}${context.tr.wordsCountSuffix}',
              style: FluidTheme.bodyMedium(
                isDark,
              ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
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
                style: FluidTheme.bodySmall(
                  isDark,
                ).copyWith(color: FluidTheme.getTextTertiaryColor(isDark)),
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
        style: FluidTheme.headingSmall(isDark).copyWith(color: textColor),
      ),
      actions: [
        if (_words.isNotEmpty)
          IconButton(
            tooltip: _isCurrentWordFavorite
                ? context.tr.removedFromFavorites
                : context.tr.addToFavorites,
            icon: Icon(
              _isCurrentWordFavorite ? Icons.star : Icons.star_border,
              color: _isCurrentWordFavorite
                  ? FluidTheme.warningFluidGradient[0]
                  : textColor,
            ),
            onPressed: _onFavoriteCurrentWord,
          ),
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
                style: FluidTheme.headingMedium(
                  isDark,
                ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr.greatKeepGoing,
                style: FluidTheme.bodyMedium(
                  isDark,
                ).copyWith(color: FluidTheme.getTextSecondaryColor(isDark)),
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

  Future<void> _revealAnswer() async {
    final provider = Provider.of<StudySettingsProvider>(context, listen: false);
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
            content: Text(context.tr.fetchingDefinition),
            duration: const Duration(seconds: 1),
          ),
        );
        await _ensureCurrentWordDefinition();
      }
    }
    if (mounted) setState(() => _showAnswer = true);
  }

  /// 左右滑评分：左=困难(2)/错误，右=容易(4)/正确
  void _onSwipeQuality(DragEndDetails details) {
    if (!_showAnswer || _isSavingQuality) return;
    final dx = details.velocity.pixelsPerSecond.dx;
    if (dx.abs() < 300) return;
    HapticFeedback.mediumImpact();
    if (dx < 0) {
      _onQualitySelected(widget.isReview ? 2 : 1);
    } else {
      _onQualitySelected(4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: FluidTheme.getBackgroundColor(isDark),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _isLoading
            ? Center(child: FluidLoading(message: context.tr.loadingText))
            : _words.isEmpty
            ? _buildEmptyState()
            : _buildStudyCard(),
      ),
    );
  }

  Widget _buildStudyCard() {
    final word = _words[_currentIndex];
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final hintColor = FluidTheme.getTextTertiaryColor(isDark);

    return Column(
      children: [
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
            onHorizontalDragEnd: _showAnswer ? _onSwipeQuality : null,
            onTap: _showAnswer
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    _revealAnswer();
                  },
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
                        showDictionaryDialog(context: context, word: wordText);
                      },
                    ),
                    const SizedBox(height: 20),
                    if (!_showAnswer)
                      FluidButton(
                        text: context.tr.showDefinitionBtn,
                        icon: Icons.visibility_outlined,
                        expanded: true,
                        onPressed: _revealAnswer,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
