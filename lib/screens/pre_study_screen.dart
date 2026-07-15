import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/review_scheduler.dart';
import '../services/repositories/review_repository.dart';
import '../services/session_mastery_engine.dart';
import '../services/tts_service.dart';
import '../services/providers/theme_provider.dart';
import '../services/providers/study_settings_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../utils/page_transitions.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_loading.dart';

/// 学习前置选词界面 - 流体渐变风格
class PreStudyScreen extends StatefulWidget {
  final bool isReview;
  final int wordBookId;
  final List<Word>? presetWords;
  final int? presetStudyMode;
  final SpecializedStudyRequest? specializedRequest;

  const PreStudyScreen({
    super.key,
    required this.isReview,
    required this.wordBookId,
    this.presetWords,
    this.presetStudyMode,
    this.specializedRequest,
  });

  factory PreStudyScreen.continueStudy({
    required int wordBookId,
    required List<Word> words,
    required int studyMode,
    required bool isReview,
  }) {
    return PreStudyScreen(
      wordBookId: wordBookId,
      isReview: isReview,
      presetWords: words,
      presetStudyMode: studyMode,
    );
  }

  factory PreStudyScreen.specialized({
    required SpecializedStudyRequest request,
    required List<Word> words,
  }) {
    return PreStudyScreen(
      wordBookId: request.wordBookId ?? 0,
      isReview: request.isReview,
      presetWords: words,
      presetStudyMode: request.studyMode,
      specializedRequest: request,
    );
  }

  @override
  State<PreStudyScreen> createState() => _PreStudyScreenState();
}

class _PreStudyScreenState extends State<PreStudyScreen> {
  List<Word> _allWords = [];
  Set<int> _selectedIds = {};
  bool _isLoading = true;
  int _selectedStudyMode = 1;
  bool _enableSmartMode = false; // 智能模式切换开关状态

  @override
  void initState() {
    super.initState();
    // 从设置中加载智能模式偏好
    final settings = context.read<StudySettingsProvider>();
    _enableSmartMode = settings.enableSmartModeSwitch;

    if (widget.presetWords != null && widget.presetWords!.isNotEmpty) {
      _selectedStudyMode = widget.presetStudyMode ?? 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startDirectStudy();
      });
    } else {
      _loadWords();
    }
  }

  void _startDirectStudy() {
    Navigator.push(
      context,
      PageTransitions.slideFromRight(
        page: DirectStudyScreen(
          isReview: widget.isReview,
          wordBookId: widget.wordBookId,
          presetWords: widget.presetWords!,
          studyMode: _selectedStudyMode,
          enableSmartMode: _enableSmartMode,
          specializedRequest: widget.specializedRequest,
        ),
      ),
    );
  }

  Future<void> _loadWords() async {
    final di = context.read<DIContainer>();
    final settings = context.read<StudySettingsProvider>();

    try {
      List<Word> words;
      if (widget.isReview) {
        //复习模式：只加载到期词，限制每日复习数量
        words = await di.wordRepository.getDueWords(
          widget.wordBookId,
          limit: settings.dailyReviewWords,
        );
      } else {
        //学习新模式：只加载未学习的新词，限制每日新词数量
        words = await di.wordRepository.getNewWords(
          widget.wordBookId,
          settings.dailyNewWords,
        );
      }
      if (!mounted) return;
      _allWords = words;
      _selectedIds = words.map((w) => w.id!).toSet();
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allWords = [];
        _selectedIds = {};
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr.loadingError}：$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _startStudy() {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.selectAtLeastOne),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedList = <Word>[];
    for (int i = 0; i < _allWords.length; i++) {
      if (_selectedIds.contains(_allWords[i].id)) {
        selectedList.add(_allWords[i]);
      }
    }

    if (selectedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.noSelectedWords),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      PageTransitions.slideFromRight(
        page: DirectStudyScreen(
          isReview: widget.isReview,
          wordBookId: widget.wordBookId,
          presetWords: selectedList,
          studyMode: _selectedStudyMode,
          enableSmartMode: _enableSmartMode,
          specializedRequest: widget.specializedRequest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Scaffold(
      backgroundColor: FluidTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        title: Text(
          widget.isReview ? context.tr.reviewMode : context.tr.study,
          style: FluidTheme.headingSmall(isDark).copyWith(color: textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: FluidLoading(message: context.tr.loading))
          : _allWords.isEmpty
          ? Center(
              child: Text(
                context.tr.emptyBookHint,
                style: FluidTheme.bodyMedium(
                  isDark,
                ).copyWith(color: textSecondary),
              ),
            )
          : _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 学习模式选择
          Text(
            context.tr.selectStudyMode,
            style: FluidTheme.headingSmall(isDark).copyWith(color: textPrimary),
          ),
          const SizedBox(height: 16),
          FluidCard(
            enableShimmer: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FluidGradientContainer(
                      colors: FluidTheme.primaryFluidGradient,
                      borderRadius: 12,
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        Icons.library_books,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isReview
                                ? context.tr.reviewWordsTitle
                                : context.tr.studyNewWords,
                            style: FluidTheme.labelLarge(
                              isDark,
                            ).copyWith(color: textPrimary),
                          ),
                          Text(
                            widget.isReview
                                ? '${context.tr.dailyReviewLimitPrefix}${context.read<StudySettingsProvider>().dailyReviewWords}${context.tr.wordsSuffix} · ${context.tr.loaded}${_selectedIds.length}${context.tr.wordsSuffix}'
                                : '${context.tr.dailyNewLimitPrefix}${context.read<StudySettingsProvider>().dailyNewWords}${context.tr.wordsSuffix} · ${context.tr.loaded}${_selectedIds.length}${context.tr.wordsSuffix}',
                            style: FluidTheme.bodySmall(
                              isDark,
                            ).copyWith(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr.modeSelection,
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: textPrimary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    StudyModeChip(
                      icon: Icons.visibility_outlined,
                      label: context.tr.recallMode,
                      isSelected: _selectedStudyMode == 1,
                      onTap: () => setState(() => _selectedStudyMode = 1),
                    ),
                    StudyModeChip(
                      icon: Icons.edit_outlined,
                      label: context.tr.spellingMode,
                      isSelected: _selectedStudyMode == 2,
                      onTap: () => setState(() => _selectedStudyMode = 2),
                    ),
                    StudyModeChip(
                      icon: Icons.headphones_outlined,
                      label: context.tr.listeningMode,
                      isSelected: _selectedStudyMode == 3,
                      onTap: () => setState(() => _selectedStudyMode = 3),
                    ),
                    StudyModeChip(
                      icon: Icons.quiz_outlined,
                      label: context.tr.quizModeEnToCn,
                      isSelected: _selectedStudyMode == 4,
                      onTap: () => setState(() => _selectedStudyMode = 4),
                    ),
                    StudyModeChip(
                      icon: Icons.translate,
                      label: context.tr.quizModeCnToEn,
                      isSelected: _selectedStudyMode == 5,
                      onTap: () => setState(() => _selectedStudyMode = 5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 智能模式切换开关
          FluidCard(
            enableShimmer: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: FluidTheme.primaryFluidGradient[0],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr.smartModeSwitch,
                        style: FluidTheme.labelLarge(
                          isDark,
                        ).copyWith(color: textPrimary),
                      ),
                    ),
                    Switch(
                      value: _enableSmartMode,
                      onChanged: (value) {
                        setState(() => _enableSmartMode = value);
                        // 持久化设置
                        context
                            .read<StudySettingsProvider>()
                            .setEnableSmartModeSwitch(value);
                      },
                      activeThumbColor: FluidTheme.primaryFluidGradient[0],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr.smartModeSwitchDesc,
                  style: FluidTheme.bodySmall(
                    isDark,
                  ).copyWith(color: textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.tr.smartModeSkipMastered,
                        style: FluidTheme.bodySmall(
                          isDark,
                        ).copyWith(color: textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.trending_up, size: 16, color: textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.tr.smartModeSwitchWeak,
                        style: FluidTheme.bodySmall(
                          isDark,
                        ).copyWith(color: textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.find_in_page, size: 16, color: textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.tr.smartModeSpotCheck,
                        style: FluidTheme.bodySmall(
                          isDark,
                        ).copyWith(color: textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          FluidCard(
            enableShimmer: false,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.tips_and_updates,
                  color: FluidTheme.primaryFluidGradient[0],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.isReview
                        ? context.tr.reviewAdvice
                        : context.tr.studyAdvice,
                    style: FluidTheme.bodyMedium(
                      isDark,
                    ).copyWith(color: textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          FluidButton(
            text: context.tr.startLearningBtn,
            icon: Icons.play_arrow,
            expanded: true,
            isEnabled: _selectedIds.isNotEmpty,
            onPressed: _selectedIds.isEmpty ? null : _startStudy,
          ),
        ],
      ),
    );
  }
}

/// 学习模式选择芯片
class StudyModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const StudyModeChip({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final unselectedColor = FluidTheme.getTextSecondaryColor(isDark);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: FluidTheme.primaryFluidGradient)
              : null,
          color: isSelected ? null : FluidTheme.getMutedOverlayColor(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : FluidTheme.getBorderColor(isDark),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : unselectedColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 直接进入学习（使用预设词列表）
class DirectStudyScreen extends StatefulWidget {
  final bool isReview;
  final int wordBookId;
  final List<Word> presetWords;
  final int studyMode;
  final bool enableSmartMode;
  final SpecializedStudyRequest? specializedRequest;
  final ReviewRepository? reviewRepository;

  const DirectStudyScreen({
    super.key,
    required this.isReview,
    required this.wordBookId,
    required this.presetWords,
    required this.studyMode,
    this.enableSmartMode = false,
    this.specializedRequest,
    this.reviewRepository,
  });

  @override
  State<DirectStudyScreen> createState() => _DirectStudyScreenState();
}

enum StudyInitializationState { loading, ready, empty, error }

class _DirectStudyScreenState extends State<DirectStudyScreen> {
  late List<Word> _words;
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _answerFocusNode = FocusNode();
  final FocusNode _shortcutFocusNode = FocusNode();
  final SessionMasteryEngine _masteryEngine = SessionMasteryEngine();
  final Map<int, ReviewRecord?> _cachedRecords = {};
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isPlaying = false;
  bool _isSavingQuality = false;
  bool _hasCheckedAnswer = false;
  bool _isAnswerCorrect = false;
  bool _hasRevealedTypedAnswer = false;
  bool _hasRecordedTypedWrongAttempt = false;
  bool _hasRecordedTypedRevealAttempt = false;
  int? _selectedQuizOption;
  List<String> _quizOptions = [];
  StudyInitializationState _initializationState =
      StudyInitializationState.loading;
  String? _initializationError;

  // 学习统计
  int _correctCount = 0;
  int _wrongCount = 0;
  int _revealedCount = 0;
  int _skippedCount = 0;
  int _completedOriginalWords = 0;
  int _totalOriginalWords = 0;
  int _totalOriginalCorrect = 0;
  int _totalOriginalWrong = 0;
  int _totalOriginalRevealed = 0;
  final List<Word> _wrongWords = [];
  final List<Word> _revealedWords = [];
  final List<Word> _sessionWrongWords = [];
  final Set<int> _sessionWeakWordIds = {};

  // 错词强化队列
  bool _isStrengtheningMode = false;
  List<Word> _strengthenWords = [];

  // 智能模式切换：当前词的实际学习模式（可能与widget.studyMode不同）
  int _currentWordMode = 0;

  // 答题耗时记录
  DateTime? _wordStartTime;

  // 错词专项复习结果跟踪
  final Map<int, WrongWordReviewResult> _wrongWordReviewResults = {};
  final Map<int, int> _wrongWordCorrectStreaks = {};

  // 获取当前有效的学习模式（智能模式开启时使用_currentWordMode，否则使用widget.studyMode）
  int get _effectiveStudyMode => widget.enableSmartMode && _currentWordMode > 0
      ? _currentWordMode
      : widget.studyMode;

  @override
  void initState() {
    super.initState();
    _words = widget.presetWords
        .where((word) => word.id != null)
        .toList(growable: false);

    _initializeStudy();
  }

  Future<void> _initializeStudy() async {
    if (_words.isEmpty) {
      if (mounted) {
        setState(() => _initializationState = StudyInitializationState.empty);
      }
      return;
    }
    try {
      await _preloadRecords();

      if (!mounted) return;
      _totalOriginalWords = _words.length;

      _prepareModeState(playListeningAudio: true);

      setState(() => _initializationState = StudyInitializationState.ready);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializationState = StudyInitializationState.error;
        _initializationError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _shortcutFocusNode.dispose();
    _answerFocusNode.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _preloadRecords() async {
    final reviewRepository =
        widget.reviewRepository ?? context.read<DIContainer>().reviewRepository;
    final wordIds = _words
        .map((w) => w.id)
        .whereType<int>()
        .toList(growable: false);
    final loaded = await reviewRepository.getReviewRecordsByWordIds(wordIds);
    _cachedRecords.addAll(loaded);
  }

  void _prepareModeState({bool playListeningAudio = false}) {
    _showAnswer = false;
    _hasCheckedAnswer = false;
    _isAnswerCorrect = false;
    _hasRevealedTypedAnswer = false;
    _hasRecordedTypedWrongAttempt = false;
    _hasRecordedTypedRevealAttempt = false;
    _selectedQuizOption = null;
    _answerController.clear();

    // 智能模式切换：确定当前词的学习模式
    int effectiveMode = widget.studyMode;
    if (widget.enableSmartMode) {
      final word = _words[_currentIndex];
      final wordId = word.id;
      if (wordId != null && _masteryEngine.states.containsKey(wordId)) {
        final state = _masteryEngine.stateFor(wordId);
        final recommendedMode = _masteryEngine.recommendNextMode(
          currentMode: widget.studyMode,
          state: state,
          enableSpotCheck: true,
        );

        if (recommendedMode == null) {
          // 跳过已掌握的词
          _skippedCount++;
          // 继续下一个词
          if (_currentIndex < _words.length - 1) {
            setState(() {
              _currentIndex++;
            });
            // 使用循环代替递归，防止栈溢出
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _prepareModeState(playListeningAudio: playListeningAudio);
            });
            return;
          } else {
            _finishStudy();
            return;
          }
        } else {
          effectiveMode = recommendedMode;
        }
      }
    }

    _currentWordMode = effectiveMode;

    // 记录开始答题时间
    _wordStartTime = DateTime.now();

    if (effectiveMode == 4 || effectiveMode == 5) {
      _quizOptions = _generateQuizOptions(_words[_currentIndex]);
    } else {
      _quizOptions = [];
    }

    if (effectiveMode == 2 || effectiveMode == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _answerFocusNode.canRequestFocus) {
          _answerFocusNode.requestFocus();
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _shortcutFocusNode.canRequestFocus) {
          _shortcutFocusNode.requestFocus();
        }
      });
    }
    final settings = context.read<StudySettingsProvider>();
    if (playListeningAudio && effectiveMode == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _playWord());
    } else if (playListeningAudio) {
      // 非听力模式下根据自动发音设置决定是否播放
      if (settings.autoPlayAudio) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _playWord());
      }
    }
  }

  Future<bool> _saveCurrentQuality(int quality) async {
    if (_isSavingQuality) return false;
    _isSavingQuality = true;

    final word = _words[_currentIndex];
    final record = _cachedRecords.containsKey(word.id!)
        ? (_cachedRecords[word.id!] ??
              ReviewScheduler.createInitialRecord(word.id!))
        : ReviewScheduler.createInitialRecord(word.id!);
    final reviewQuality = _masteryEngine.states.containsKey(word.id!)
        ? _masteryEngine.calculateReviewQuality(word.id!)
        : quality;

    final nextRecord = ReviewScheduler.scheduleNextReview(
      record,
      reviewQuality,
    );
    try {
      final reviewRepository =
          widget.reviewRepository ??
          context.read<DIContainer>().reviewRepository;
      await reviewRepository.saveReviewRecord(nextRecord);
      _cachedRecords[word.id!] = nextRecord;
      if (!_isStrengtheningMode) _completedOriginalWords++;
      if (reviewQuality < 3) await _addCurrentWordToWrongWords(word);
    } catch (e) {
      debugPrint('保存复习记录失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr.saveRecordFailed)));
      }
      _isSavingQuality = false;
      return false;
    }

    _isSavingQuality = false;
    return true;
  }

  Future<void> _addCurrentWordToWrongWords(Word word) async {
    if (widget.specializedRequest?.source == StudySource.wrongWords) return;
    final wordId = word.id;
    if (wordId == null) return;
    try {
      await context.read<DIContainer>().wrongWordService.addWrongWord(wordId);
    } catch (e) {
      debugPrint('保存错词失败: $e');
    }
  }

  void _goToNextWord() {
    if (_currentIndex < _words.length - 1) {
      setState(() {
        _currentIndex++;
        _prepareModeState(playListeningAudio: true);
      });
    } else {
      _finishStudy();
    }
  }

  void _recordMasteryAttempt(StudyAttemptOutcome outcome) {
    final word = _words[_currentIndex];
    final wordId = word.id;
    if (wordId == null) return;

    // 保护：确保当前模式已初始化
    if (_currentWordMode == 0) {
      debugPrint('警告：_currentWordMode未初始化，使用默认模式');
    }

    // 计算答题耗时（如果_wordStartTime为null，使用默认值3000ms）
    int durationMs = 3000; // 默认3秒
    if (_wordStartTime != null) {
      durationMs = DateTime.now().difference(_wordStartTime!).inMilliseconds;
      // 保护：如果耗时异常（小于100ms或大于5分钟），使用默认值
      if (durationMs < 100 || durationMs > 300000) {
        debugPrint('警告：答题耗时异常($durationMs ms)，使用默认值');
        durationMs = 3000;
      }
    }

    // 使用带耗时的记录方法
    final state = _masteryEngine.recordAttemptWithDuration(
      wordId: wordId,
      mode: SessionMasteryEngine.modeFromStudyMode(
        _currentWordMode > 0 ? _currentWordMode : widget.studyMode,
      ),
      outcome: outcome,
      reviewRecord: _cachedRecords[wordId],
      durationMs: durationMs,
    );
    if (state.isMastered) {
      _wrongWords.removeWhere((wrongWord) => wrongWord.id == wordId);
    }
  }

  void _recordCorrectProgress(Word word) {
    _correctCount++;
    _wrongWords.removeWhere((wrongWord) => wrongWord.id == word.id);
  }

  void _recordWeakProgress(Word word, {bool revealed = false}) {
    final wordId = word.id;
    if (wordId != null) {
      _sessionWeakWordIds.add(wordId);
      if (!_sessionWrongWords.any((wrongWord) => wrongWord.id == wordId)) {
        _sessionWrongWords.add(word);
      }
    }
    if (revealed) {
      _revealedCount++;
      if (!_revealedWords.contains(word)) {
        _revealedWords.add(word);
      }
    } else {
      _wrongCount++;
    }
    if (!_wrongWords.contains(word)) {
      _wrongWords.add(word);
    }
  }

  void _recordWrongWordReviewResult({
    required Word word,
    required bool wasCorrect,
    required bool revealedAnswer,
  }) {
    if (widget.specializedRequest?.source != StudySource.wrongWords) return;
    final wordId = word.id;
    if (wordId == null) return;

    final previous = _wrongWordCorrectStreaks[wordId] ?? 0;
    final result = WrongWordReviewResult(
      wordId: wordId,
      wasCorrect: wasCorrect,
      revealedAnswer: revealedAnswer,
      previousCorrectStreak: previous,
    );
    _wrongWordCorrectStreaks[wordId] = result.nextCorrectStreak;
    _wrongWordReviewResults[wordId] = result;
  }

  void _focusStudyShortcuts() {
    if (!mounted) return;
    if (_isTypedMode) {
      _answerFocusNode.unfocus();
    }
    if (_shortcutFocusNode.canRequestFocus) {
      _shortcutFocusNode.requestFocus();
    }
  }

  Future<void> _onQualitySelected(int quality) async {
    final word = _words[_currentIndex];
    final outcome = switch (quality) {
      4 || 5 => StudyAttemptOutcome.recallEasy,
      3 => StudyAttemptOutcome.recallRemembered,
      2 => StudyAttemptOutcome.recallVague,
      _ => StudyAttemptOutcome.recallForgot,
    };
    setState(() {
      _recordMasteryAttempt(outcome);
      if (quality >= 3) {
        _recordCorrectProgress(word);
      } else {
        _recordWeakProgress(word);
      }
      _recordWrongWordReviewResult(
        word: word,
        wasCorrect: quality >= 3,
        revealedAnswer: false,
      );
    });
    final saved = await _saveCurrentQuality(quality);
    if (!saved || !mounted) return;
    _goToNextWord();
  }

  Future<void> _onPracticeNext() async {
    if (!_hasCheckedAnswer) return;
    if ((_effectiveStudyMode == 2 || _effectiveStudyMode == 3) &&
        !_isAnswerCorrect &&
        !_hasRevealedTypedAnswer) {
      return;
    }
    final saved = await _saveCurrentQuality(_isAnswerCorrect ? 4 : 1);
    if (!saved || !mounted) return;
    _goToNextWord();
  }

  Future<void> _finishStudy() async {
    // 如果有错词且不在强化模式中，进入错词强化队列
    if (!_isStrengtheningMode && _wrongWords.isNotEmpty) {
      _startStrengthenMode();
      return;
    }

    // 保存会话状态到数据库（跨天持久化）
    final di = context.read<DIContainer>();
    final studySettingsProvider = context.read<StudySettingsProvider>();
    final studyProgressRepository = di.studyProgressRepository;
    final wrongWordService = di.wrongWordService;
    await _masteryEngine.saveSession();
    await studyProgressRepository.clearStudyProgress();

    // 应用错词专项复习结果
    if (widget.specializedRequest?.source == StudySource.wrongWords &&
        _wrongWordReviewResults.isNotEmpty) {
      await wrongWordService.applyReviewResults(
        _wrongWordReviewResults.values.toList(),
      );
    }

    // 收集S-MARS状态分布
    final masteryStates = Map<int, SessionMasteryState>.from(
      _masteryEngine.states,
    );

    // 合并原始阶段和强化阶段的统计数据
    final finalCorrectCount = _totalOriginalCorrect + _correctCount;
    final finalWrongCount = _totalOriginalWrong + _wrongCount;
    final finalRevealedCount = _totalOriginalRevealed + _revealedCount;

    // 回写学习计划今日任务进度：普通学习/计划学习计入任务，错词等专项不计入新词/复习目标
    final source = widget.specializedRequest?.source;
    if (source == null || source == StudySource.studyPlan) {
      await di.studyPlanService.recordProgress(
        newWords: widget.isReview ? 0 : _completedOriginalWords,
        reviewWords: widget.isReview ? _completedOriginalWords : 0,
      );
    }
    await studySettingsProvider.updateStreak();

    // 阶段三：专项学习完成回调
    // 优先调用 Request.onCompleted（统一抽象），否则走兼容分支。
    final callback = widget.specializedRequest?.onCompleted;
    if (callback != null) {
      try {
        await callback();
      } catch (e) {
        debugPrint('专项学习完成回调失败：$e');
      }
    } else {
      // 兼容：旧 Request 无 onCompleted 时的兜底分支
      if (source == StudySource.favorites) {
        try {
          final wordIds = _words
              .map((w) => w.id)
              .whereType<int>()
              .toList(growable: false);
          if (wordIds.isNotEmpty) {
            await di.specializedStudyService.markFavoritesStudied(wordIds);
          }
        } catch (e) {
          debugPrint('更新收藏学习时间失败：$e');
        }
      }

      if (source == StudySource.customWordSet) {
        final setId = widget.specializedRequest?.customWordSetId;
        if (setId != null) {
          try {
            await di.specializedStudyService.markCustomWordSetStudied(setId);
          } catch (e) {
            debugPrint('更新词集学习时间失败：$e');
          }
        }
      }
    }

    final todayTask = await di.studyPlanService.getTodayTask();
    final sessionSummary = StudySessionSummary(
      totalWords: _totalOriginalWords,
      weakWords: _sessionWeakWordIds.length,
      revealedWords: finalRevealedCount,
      skippedWords: _skippedCount,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageTransitions.fade(
        page: _StudySummaryScreen(
          isReview: widget.isReview,
          totalWords: _totalOriginalWords, // 使用原始总词数
          correctCount: finalCorrectCount, // 合并统计
          wrongCount: finalWrongCount,
          revealedCount: finalRevealedCount,
          wrongWords: _sessionWrongWords,
          revealedWords: _revealedWords,
          wordBookId: widget.wordBookId,
          studyMode: widget.studyMode,
          skippedCount: _skippedCount,
          sessionSummary: sessionSummary,
          enableSmartMode: widget.enableSmartMode,
          masteryStates: masteryStates, // 传递S-MARS状态
          dailyTaskCompleted: todayTask.isCompleted,
        ),
      ),
    );
  }

  void _startStrengthenMode() {
    // 保存原始阶段的统计数据（用于总结页显示）
    _totalOriginalCorrect = _correctCount;
    _totalOriginalWrong = _wrongCount;
    _totalOriginalRevealed = _revealedCount;

    setState(() {
      _isStrengtheningMode = true;
      _strengthenWords = List.from(_wrongWords);
      _words = _strengthenWords;
      _currentIndex = 0;
      _correctCount = 0;
      _wrongCount = 0;
      _revealedCount = 0;
      _wrongWords.clear();
      _revealedWords.clear();
      _prepareModeState(playListeningAudio: true);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr.strengthenModeStart),
        behavior: SnackBarBehavior.floating,
        backgroundColor: FluidTheme.warning,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _playWord() async {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);
    try {
      final ttsService = context.read<TtsService>();
      await ttsService.playWord(_words[_currentIndex].word);
    } catch (e) {
      debugPrint('播放失败: $e');
    }
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  void _checkTypedAnswer() {
    final word = _words[_currentIndex];
    final userAnswer = _answerController.text;
    final isCorrect =
        _normalizeAnswer(userAnswer) == _normalizeAnswer(word.word);

    // 拼写容错提示：如果接近正确答案，显示提示但不计为正确
    final isClose = !isCorrect && _isCloseAnswer(userAnswer, word.word);

    setState(() {
      _hasCheckedAnswer = true;
      _isAnswerCorrect = isCorrect;
      if (isCorrect) {
        _hasRevealedTypedAnswer = true;
        if (!_hasRecordedTypedRevealAttempt && !_hasRecordedTypedWrongAttempt) {
          _recordMasteryAttempt(StudyAttemptOutcome.firstCorrect);
          _recordCorrectProgress(word);
        }
        _recordWrongWordReviewResult(
          word: word,
          wasCorrect: true,
          revealedAnswer: false,
        );
      } else {
        if (!_hasRecordedTypedWrongAttempt) {
          _hasRecordedTypedWrongAttempt = true;
          _recordMasteryAttempt(StudyAttemptOutcome.wrong);
          _recordWeakProgress(word);
        }
        _recordWrongWordReviewResult(
          word: word,
          wasCorrect: false,
          revealedAnswer: false,
        );
      }
    });

    // 显示拼写容错提示
    if (isClose && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.spellingCloseHint),
          behavior: SnackBarBehavior.floating,
          backgroundColor: FluidTheme.warning,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (isCorrect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusStudyShortcuts();
      });
    }
    if (!isCorrect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _answerFocusNode.canRequestFocus) {
          _answerFocusNode.requestFocus();
        }
      });
    }
  }

  void _revealTypedAnswer() {
    final word = _words[_currentIndex];
    setState(() {
      _hasCheckedAnswer = true;
      _isAnswerCorrect = false;
      _hasRevealedTypedAnswer = true;
      if (!_hasRecordedTypedRevealAttempt) {
        _hasRecordedTypedRevealAttempt = true;
        _recordMasteryAttempt(StudyAttemptOutcome.revealed);
        _recordWeakProgress(word, revealed: true);
      }
      _recordWrongWordReviewResult(
        word: word,
        wasCorrect: false,
        revealedAnswer: true,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusStudyShortcuts();
    });
  }

  void _retryTypedAnswer() {
    setState(() {
      _hasCheckedAnswer = false;
      _isAnswerCorrect = false;
      _hasRevealedTypedAnswer = false;
      _answerController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _answerFocusNode.canRequestFocus) {
        _answerFocusNode.requestFocus();
      }
    });
  }

  void _selectQuizOption(int index) {
    if (_selectedQuizOption != null) return;
    final word = _words[_currentIndex];
    setState(() {
      _selectedQuizOption = index;
      _hasCheckedAnswer = true;
      _isAnswerCorrect = _quizOptions[index] == _correctQuizAnswer(word);
      _showAnswer = true;
      if (_isAnswerCorrect) {
        _recordMasteryAttempt(StudyAttemptOutcome.firstCorrect);
        _recordCorrectProgress(word);
        _recordWrongWordReviewResult(
          word: word,
          wasCorrect: true,
          revealedAnswer: false,
        );
      } else {
        _recordMasteryAttempt(StudyAttemptOutcome.wrong);
        _recordWeakProgress(word);
        _recordWrongWordReviewResult(
          word: word,
          wasCorrect: false,
          revealedAnswer: false,
        );
      }
    });
  }

  String _normalizeAnswer(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// 计算两个字符串的编辑距离（Levenshtein Distance）
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final List<List<int>> dp = List.generate(
      s1.length + 1,
      (_) => List<int>.filled(s2.length + 1, 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return dp[s1.length][s2.length];
  }

  /// 判断用户输入是否接近正确答案（用于拼写容错提示）
  bool _isCloseAnswer(String input, String correct) {
    final normalizedInput = _normalizeAnswer(input);
    final normalizedCorrect = _normalizeAnswer(correct);

    if (normalizedInput.isEmpty || normalizedCorrect.isEmpty) return false;
    if (normalizedInput == normalizedCorrect) return false; // 已经是正确答案

    final distance = _levenshteinDistance(normalizedInput, normalizedCorrect);
    final maxLen = normalizedInput.length > normalizedCorrect.length
        ? normalizedInput.length
        : normalizedCorrect.length;

    // 如果编辑距离小于等于单词长度的 30% 且最多差 2 个字符，认为是接近答案
    final threshold = (maxLen * 0.3).ceil();
    return distance <= threshold && distance <= 2;
  }

  String _correctQuizAnswer(Word word) {
    return _effectiveStudyMode == 4 ? _definitionText(word) : word.word;
  }

  String _definitionText(Word word) {
    return word.definition.trim().isNotEmpty
        ? word.definition.trim()
        : context.tr.noDefinition;
  }

  List<String> _generateQuizOptions(Word word) {
    final correct = _correctQuizAnswer(word);
    final options = <String>{correct};
    final candidates = _words
        .where((item) => item.id != word.id)
        .map(
          (item) =>
              _effectiveStudyMode == 4 ? _definitionText(item) : item.word,
        )
        .where((value) => value.trim().isNotEmpty && value != correct)
        .toList();
    candidates.shuffle(math.Random());
    for (final candidate in candidates) {
      options.add(candidate);
      if (options.length >= 4) break;
    }
    var fallbackIndex = 1;
    while (options.length < math.min(4, math.max(_words.length, 2))) {
      options.add(
        _effectiveStudyMode == 4
            ? '${context.tr.noDefinition} $fallbackIndex'
            : 'option_$fallbackIndex',
      );
      fallbackIndex++;
    }
    final result = options.toList()..shuffle(math.Random());
    return result;
  }

  bool get _handlesEnterShortcut =>
      _effectiveStudyMode >= 1 && _effectiveStudyMode <= 5;

  bool get _isTypedMode => _effectiveStudyMode == 2 || _effectiveStudyMode == 3;

  bool get _shouldUseAnimatedModeSwitcher => !_isTypedMode;

  bool get _isQuizMode => _effectiveStudyMode == 4 || _effectiveStudyMode == 5;

  void _handleEnterShortcut({bool revealAnswer = false}) {
    if (!_handlesEnterShortcut || _isSavingQuality) return;

    if (_effectiveStudyMode == 1) {
      if (!_showAnswer) {
        setState(() => _showAnswer = true);
      }
      return;
    }

    if (_isTypedMode) {
      if (revealAnswer && !_isAnswerCorrect && !_hasRevealedTypedAnswer) {
        _revealTypedAnswer();
      } else if (!_hasCheckedAnswer ||
          (!_isAnswerCorrect && !_hasRevealedTypedAnswer)) {
        _checkTypedAnswer();
      } else if (_isAnswerCorrect || _hasRevealedTypedAnswer) {
        _onPracticeNext();
      }
      return;
    }

    if (_isQuizMode && _hasCheckedAnswer) {
      _onPracticeNext();
    }
  }

  void _handleNumberShortcut(int number) {
    if (_isSavingQuality) return;
    if (_isQuizMode && !_hasCheckedAnswer) {
      final index = number - 1;
      if (index >= 0 && index < _quizOptions.length) {
        _selectQuizOption(index);
      }
      return;
    }
    if (_effectiveStudyMode == 1 && _showAnswer) {
      final qualities = [1, 2, 3, 4];
      final index = number - 1;
      if (index >= 0 && index < qualities.length) {
        _onQualitySelected(qualities[index]);
      }
    }
  }

  bool _isNumberKey(LogicalKeyboardKey key, int number) {
    return key ==
            LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + number - 1) ||
        key ==
            LogicalKeyboardKey(LogicalKeyboardKey.numpad1.keyId + number - 1);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      if (mounted) {
        Navigator.pop(context);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.space &&
        (_effectiveStudyMode == 1 || _effectiveStudyMode == 3)) {
      _playWord();
      return KeyEventResult.handled;
    }

    for (var number = 1; number <= 5; number++) {
      if (_isNumberKey(key, number)) {
        _handleNumberShortcut(number);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _handleEnterShortcut(
        revealAnswer:
            HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isAltPressed,
      );
      return _handlesEnterShortcut
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  String get _modeTitle {
    final baseMode = switch (_effectiveStudyMode) {
      2 => context.tr.spellingMode,
      3 => context.tr.listeningMode,
      4 => context.tr.quizModeEnToCn,
      5 => context.tr.quizModeCnToEn,
      _ => context.tr.recallMode,
    };
    return _isStrengtheningMode
        ? '$baseMode · ${context.tr.strengthenMode}'
        : baseMode;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    if (_initializationState != StudyInitializationState.ready) {
      return _buildInitializationScaffold(isDark, textPrimary);
    }

    return Scaffold(
      backgroundColor: FluidTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        title: Text(
          '${_currentIndex + 1} / ${_words.length} · $_modeTitle',
          style: FluidTheme.labelLarge(isDark).copyWith(color: textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (PlatformAdapt.showKeyboardShortcuts(context))
            IconButton(
              icon: Icon(Icons.keyboard, color: textPrimary),
              tooltip: context.tr.keyboardShortcuts,
              onPressed: () => _showKeyboardShortcuts(context),
            ),
        ],
      ),
      body: SafeArea(
        child: Focus(
          focusNode: _shortcutFocusNode,
          onKeyEvent: _handleKeyEvent,
          child: _buildStudyContent(),
        ),
      ),
    );
  }

  Widget _buildInitializationScaffold(bool isDark, Color textPrimary) {
    final isLoading = _initializationState == StudyInitializationState.loading;
    final isEmpty = _initializationState == StudyInitializationState.empty;
    return Scaffold(
      backgroundColor: FluidTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: isLoading
              ? FluidLoading(message: context.tr.loading)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isEmpty
                          ? context.tr.noWordsToStudy
                          : context.tr.studyInitializationFailed,
                      textAlign: TextAlign.center,
                      style: FluidTheme.headingSmall(
                        isDark,
                      ).copyWith(color: textPrimary),
                    ),
                    if (!isEmpty && _initializationError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _initializationError!,
                        textAlign: TextAlign.center,
                        style: FluidTheme.bodyMedium(isDark).copyWith(
                          color: FluidTheme.getTextSecondaryColor(isDark),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
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

  /// 左右滑评分：左=困难(2)，右=容易(4)
  void _onSwipeQuality(DragEndDetails details) {
    if (_effectiveStudyMode != 1 || !_showAnswer) return;
    final dx = details.velocity.pixelsPerSecond.dx;
    if (dx.abs() < 300) return;
    HapticFeedback.mediumImpact();
    _onQualitySelected(dx < 0 ? 2 : 4);
  }

  Widget _buildStudyContent() {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _words.length,
          backgroundColor: FluidTheme.getBorderColor(isDark),
          valueColor: AlwaysStoppedAnimation<Color>(
            FluidTheme.primaryFluidGradient[0],
          ),
        ),
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: _effectiveStudyMode == 1 && _showAnswer
                ? _onSwipeQuality
                : null,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _shouldUseAnimatedModeSwitcher
                      ? AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _buildModeContent(
                            isDark,
                            key: ValueKey(_currentIndex),
                          ),
                        )
                      : _buildModeContent(isDark, key: ValueKey(_currentIndex)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showKeyboardShortcuts(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    final shortcuts = [
      (context.tr.shortcutEnter, context.tr.shortcutEnterDesc),
      (context.tr.shortcutCtrlEnter, context.tr.shortcutCtrlEnterDesc),
      (context.tr.shortcutSpace, context.tr.shortcutSpaceDesc),
      (context.tr.shortcutNumber, context.tr.shortcutNumberDesc),
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FluidTheme.getSurfaceColor(isDark),
        title: Text(
          context.tr.keyboardShortcuts,
          style: FluidTheme.headingSmall(isDark).copyWith(color: textPrimary),
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: shortcuts.map((s) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: FluidTheme.getMutedOverlayColor(isDark),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: FluidTheme.getBorderColor(isDark),
                        ),
                      ),
                      child: Text(
                        s.$1,
                        style: FluidTheme.labelLarge(isDark).copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        s.$2,
                        style: FluidTheme.bodyMedium(
                          isDark,
                        ).copyWith(color: textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr.confirm,
              style: TextStyle(color: FluidTheme.primaryFluidGradient[0]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeContent(bool isDark, {required Key key}) {
    switch (_effectiveStudyMode) {
      case 2:
        return _buildTypedMode(isDark, key: key, isListening: false);
      case 3:
        return _buildTypedMode(isDark, key: key, isListening: true);
      case 4:
      case 5:
        return _buildQuizMode(isDark, key: key);
      default:
        return _buildRecallMode(isDark, key: key);
    }
  }

  Widget _buildRecallMode(bool isDark, {required Key key}) {
    final word = _words[_currentIndex];
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FluidCard(
          enableShimmer: false,
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                word.word,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 52,
                  height: 1.08,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              if (word.phonetic.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  word.phonetic,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, color: textSecondary),
                ),
              ],
              const SizedBox(height: 20),
              _buildPlayButton(),
              const SizedBox(height: 12),
              Text(
                _showAnswer
                    ? (PlatformAdapt.isDesktop || kIsWeb
                          ? context.tr.qualityHintDesktop
                          : context.tr.qualityHint)
                    : (PlatformAdapt.isDesktop || kIsWeb
                          ? context.tr.recallHintDesktop
                          : context.tr.recallHint),
                textAlign: TextAlign.center,
                style: FluidTheme.bodySmall(
                  isDark,
                ).copyWith(color: textSecondary, height: 1.4),
              ),
              if (_showAnswer) ...[
                const SizedBox(height: 24),
                Divider(color: FluidTheme.getBorderColor(isDark), thickness: 1),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.tr.definitionLabel,
                    style: FluidTheme.labelLarge(
                      isDark,
                    ).copyWith(color: textSecondary, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _definitionText(word),
                  textAlign: TextAlign.left,
                  style: FluidTheme.bodyMedium(isDark).copyWith(
                    color: textPrimary,
                    fontSize: 20,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!_showAnswer)
          FluidButton(
            text: context.tr.showDefinition,
            icon: Icons.visibility_outlined,
            expanded: true,
            onPressed: () => setState(() => _showAnswer = true),
          ),
        if (_showAnswer) ...[
          Text(
            PlatformAdapt.isDesktop || kIsWeb
                ? context.tr.qualitySelectHintDesktop
                : context.tr.qualitySelectHint,
            textAlign: TextAlign.center,
            style: FluidTheme.bodySmall(isDark).copyWith(color: textSecondary),
          ),
          if (PlatformAdapt.showKeyboardShortcuts(context)) ...[
            const SizedBox(height: 10),
            Text(
              context.tr.qualityKeyHint,
              textAlign: TextAlign.center,
              style: FluidTheme.bodySmall(isDark).copyWith(
                color: FluidTheme.getTextTertiaryColor(isDark),
                fontSize: 12,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              context.tr.swipeHint,
              textAlign: TextAlign.center,
              style: FluidTheme.bodySmall(isDark).copyWith(
                color: FluidTheme.getTextTertiaryColor(isDark),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _buildQualityButtons(isDark),
        ],
      ],
    );
  }

  Widget _buildTypedMode(
    bool isDark, {
    required Key key,
    required bool isListening,
  }) {
    final word = _words[_currentIndex];
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final resultColor = _isAnswerCorrect
        ? FluidTheme.success
        : FluidTheme.error;

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FluidCard(
          enableShimmer: false,
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 44),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isListening ? Icons.headphones : Icons.edit_outlined,
                size: 56,
                color: FluidTheme.primaryFluidGradient[0],
              ),
              const SizedBox(height: 18),
              Text(
                isListening
                    ? context.tr.listeningPrompt
                    : context.tr.spellingPrompt,
                textAlign: TextAlign.center,
                style: FluidTheme.headingSmall(isDark).copyWith(
                  color: textPrimary,
                  fontSize: 26,
                  height: 1.25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isListening
                    ? (PlatformAdapt.isDesktop || kIsWeb
                          ? context.tr.listeningHintDesktop
                          : context.tr.listeningHint)
                    : (PlatformAdapt.isDesktop || kIsWeb
                          ? context.tr.spellingHintDesktop
                          : context.tr.spellingHint),
                textAlign: TextAlign.center,
                style: FluidTheme.bodyMedium(
                  isDark,
                ).copyWith(color: textSecondary, fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 20),
              if (isListening)
                _buildLargePlayButton()
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: FluidTheme.getMutedOverlayColor(isDark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: FluidTheme.getBorderColor(isDark),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        context.tr.definitionLabel,
                        style: FluidTheme.labelLarge(
                          isDark,
                        ).copyWith(color: textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _definitionText(word),
                        textAlign: TextAlign.center,
                        style: FluidTheme.bodyMedium(isDark).copyWith(
                          color: textPrimary,
                          fontSize: 22,
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _answerController,
          focusNode: _answerFocusNode,
          autofocus: true,
          enabled: !_isAnswerCorrect && !_hasRevealedTypedAnswer,
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
          ],
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: FluidTheme.primaryFluidGradient[0],
          decoration: InputDecoration(
            filled: true,
            fillColor: FluidTheme.getInputFillColor(isDark),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            hintText: context.tr.enterEnglishWord,
            hintStyle: TextStyle(
              color: FluidTheme.getTextTertiaryColor(isDark),
              fontSize: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: FluidTheme.getBorderColor(isDark)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: FluidTheme.primaryFluidGradient[0]),
            ),
          ),
          onSubmitted: (_) => _handleEnterShortcut(),
        ),
        const SizedBox(height: 16),
        if (!_hasCheckedAnswer ||
            (!_isAnswerCorrect && !_hasRevealedTypedAnswer))
          FluidButton(
            text: _hasCheckedAnswer
                ? context.tr.recheck
                : context.tr.checkAnswer,
            icon: Icons.check,
            expanded: true,
            onPressed: _checkTypedAnswer,
          ),
        if (_hasCheckedAnswer &&
            !_isAnswerCorrect &&
            !_hasRevealedTypedAnswer) ...[
          const SizedBox(height: 12),
          FluidCard(
            enableShimmer: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr.answerWrong,
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: resultColor),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr.viewAnswerHint,
                  style: FluidTheme.bodyMedium(
                    isDark,
                  ).copyWith(color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FluidButton(
                  text: context.tr.clearRetry,
                  icon: Icons.refresh,
                  onPressed: _retryTypedAnswer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FluidButton(
                  text: context.tr.viewAnswer,
                  icon: Icons.visibility_outlined,
                  onPressed: _revealTypedAnswer,
                ),
              ),
            ],
          ),
        ],
        if (_hasCheckedAnswer &&
            (_isAnswerCorrect || _hasRevealedTypedAnswer)) ...[
          FluidCard(
            enableShimmer: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAnswerCorrect
                      ? context.tr.answerCorrect
                      : context.tr.answerRevealed,
                  style: FluidTheme.labelLarge(
                    isDark,
                  ).copyWith(color: resultColor),
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.tr.correctAnswer}${word.word}',
                  style: FluidTheme.bodyMedium(
                    isDark,
                  ).copyWith(color: textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  _definitionText(word),
                  style: FluidTheme.bodyMedium(
                    isDark,
                  ).copyWith(color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildNextButton(),
        ],
      ],
    );
  }

  Widget _buildQuizMode(bool isDark, {required Key key}) {
    final word = _words[_currentIndex];
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final prompt = _effectiveStudyMode == 4 ? word.word : _definitionText(word);

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          _effectiveStudyMode == 4
              ? context.tr.quizPromptEn
              : context.tr.quizPromptCn,
          textAlign: TextAlign.center,
          style: FluidTheme.headingSmall(isDark).copyWith(color: textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          PlatformAdapt.isDesktop || kIsWeb
              ? '${context.tr.quizHintDesktop}${_quizOptions.length}${context.tr.quizHintSuffixDesktop}'
              : '${context.tr.quizHint} ${_quizOptions.length}',
          textAlign: TextAlign.center,
          style: FluidTheme.bodySmall(isDark).copyWith(color: textSecondary),
        ),
        const SizedBox(height: 16),
        FluidCard(
          enableShimmer: false,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                prompt,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _effectiveStudyMode == 4 ? 30 : 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              if (_effectiveStudyMode == 4 && word.phonetic.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(word.phonetic, style: TextStyle(color: textSecondary)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(_quizOptions.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _QuizOptionButton(
              text: _quizOptions[index],
              index: index,
              isSelected: _selectedQuizOption == index,
              isCorrect: _quizOptions[index] == _correctQuizAnswer(word),
              hasAnswered: _selectedQuizOption != null,
              isDark: isDark,
              onTap: () => _selectQuizOption(index),
            ),
          );
        }),
        if (_hasCheckedAnswer) ...[
          const SizedBox(height: 8),
          _buildDefinitionCard(word, isDark),
          const SizedBox(height: 16),
          _buildNextButton(),
        ],
      ],
    );
  }

  Widget _buildPlayButton() {
    return IconButton(
      icon: Icon(
        _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
        color: FluidTheme.primaryFluidGradient[0],
        size: 36,
      ),
      onPressed: _playWord,
    );
  }

  Widget _buildLargePlayButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _playWord,
        borderRadius: BorderRadius.circular(60),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: FluidTheme.primaryFluidGradient[0].withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(
            _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
            color: FluidTheme.primaryFluidGradient[0],
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildDefinitionCard(Word word, bool isDark, {bool large = false}) {
    return FluidCard(
      enableShimmer: false,
      padding: EdgeInsets.all(large ? 22 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr.definitionLabel,
            style: FluidTheme.labelLarge(isDark).copyWith(
              color: FluidTheme.getTextPrimaryColor(isDark),
              fontSize: large ? 17 : null,
            ),
          ),
          SizedBox(height: large ? 12 : 8),
          Text(
            _definitionText(word),
            style: FluidTheme.bodyMedium(isDark).copyWith(
              color: large
                  ? FluidTheme.getTextPrimaryColor(isDark)
                  : FluidTheme.getTextSecondaryColor(isDark),
              fontSize: large ? 19 : null,
              height: large ? 1.55 : null,
              fontWeight: large ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return FluidButton(
      text: _currentIndex < _words.length - 1
          ? context.tr.nextQuestion
          : context.tr.finish,
      icon: _currentIndex < _words.length - 1
          ? Icons.arrow_forward
          : Icons.check,
      expanded: true,
      onPressed: _onPracticeNext,
    );
  }

  Widget _buildQualityButtons(bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        _QualityButton(
          label: context.tr.forget,
          color: Colors.red,
          onTap: () => _onQualitySelected(1),
          isDark: isDark,
        ),
        _QualityButton(
          label: context.tr.vague,
          color: Colors.orange,
          onTap: () => _onQualitySelected(2),
          isDark: isDark,
        ),
        _QualityButton(
          label: context.tr.remember,
          color: Colors.green,
          onTap: () => _onQualitySelected(3),
          isDark: isDark,
        ),
        _QualityButton(
          label: context.tr.familiarLabel,
          color: Colors.blue,
          onTap: () => _onQualitySelected(4),
          isDark: isDark,
        ),
      ],
    );
  }
}

class _QuizOptionButton extends StatelessWidget {
  final String text;
  final int index;
  final bool isSelected;
  final bool isCorrect;
  final bool hasAnswered;
  final bool isDark;
  final VoidCallback onTap;

  const _QuizOptionButton({
    required this.text,
    required this.index,
    required this.isSelected,
    required this.isCorrect,
    required this.hasAnswered,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final Color borderColor;
    final Color backgroundColor;
    final IconData icon;

    if (hasAnswered && isCorrect) {
      borderColor = FluidTheme.success;
      backgroundColor = FluidTheme.success.withValues(
        alpha: isDark ? 0.18 : 0.10,
      );
      icon = Icons.check_circle;
    } else if (hasAnswered && isSelected) {
      borderColor = FluidTheme.error;
      backgroundColor = FluidTheme.error.withValues(
        alpha: isDark ? 0.18 : 0.10,
      );
      icon = Icons.cancel;
    } else {
      borderColor = FluidTheme.getBorderColor(isDark);
      backgroundColor = FluidTheme.getMutedOverlayColor(isDark);
      icon = Icons.radio_button_unchecked;
    }

    return InkWell(
      onTap: hasAnswered ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: FluidTheme.primaryFluidGradient[0].withValues(
                alpha: 0.16,
              ),
              child: Text(
                String.fromCharCode(65 + index),
                style: TextStyle(
                  color: FluidTheme.primaryFluidGradient[0],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: FluidTheme.bodyMedium(
                  isDark,
                ).copyWith(color: textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(icon, color: borderColor, size: 20),
          ],
        ),
      ),
    );
  }
}

/// 学习结束总结页
class _StudySummaryScreen extends StatelessWidget {
  final bool isReview;
  final int totalWords;
  final int correctCount;
  final int wrongCount;
  final int revealedCount;
  final List<Word> wrongWords;
  final List<Word> revealedWords;
  final int wordBookId;
  final int studyMode;
  final int skippedCount; // 智能模式跳过的词数
  final StudySessionSummary sessionSummary;
  final bool enableSmartMode; // 是否启用了智能模式
  final Map<int, SessionMasteryState> masteryStates; // S-MARS状态分布
  final bool dailyTaskCompleted; // 今日学习计划任务是否完成

  const _StudySummaryScreen({
    required this.isReview,
    required this.totalWords,
    required this.correctCount,
    required this.wrongCount,
    required this.revealedCount,
    required this.wrongWords,
    required this.revealedWords,
    required this.wordBookId,
    required this.studyMode,
    required this.sessionSummary,
    this.skippedCount = 0,
    this.enableSmartMode = false,
    this.masteryStates = const {},
    this.dailyTaskCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final accuracy = sessionSummary.masteryPercent;

    return Scaffold(
      backgroundColor: FluidTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        title: Text(
          context.tr.studySummaryTitle,
          style: FluidTheme.headingSmall(isDark).copyWith(color: textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: FluidTheme.success,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isReview
                        ? context.tr.reviewComplete
                        : context.tr.studyComplete,
                    style: FluidTheme.headingMedium(
                      isDark,
                    ).copyWith(color: textPrimary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${context.tr.totalLearned}$totalWords${context.tr.wordsLearnedSuffix}',
                    style: FluidTheme.bodyLarge(
                      isDark,
                    ).copyWith(color: textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (dailyTaskCompleted) ...[
              FluidCard(
                enableShimmer: false,
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events, color: FluidTheme.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr.taskCompleted,
                            style: FluidTheme.labelLarge(
                              isDark,
                            ).copyWith(color: textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr.taskCompletedDesc,
                            style: FluidTheme.bodySmall(
                              isDark,
                            ).copyWith(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 统计卡片
            FluidCard(
              enableShimmer: false,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildStatRow(
                    Icons.check_circle,
                    FluidTheme.success,
                    context.tr.correctCount,
                    '$correctCount',
                    textPrimary,
                    textSecondary,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    Icons.cancel,
                    FluidTheme.error,
                    context.tr.wrongCount,
                    '$wrongCount',
                    textPrimary,
                    textSecondary,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    Icons.visibility,
                    FluidTheme.warning,
                    context.tr.revealedCount,
                    '$revealedCount',
                    textPrimary,
                    textSecondary,
                    isDark: isDark,
                  ),
                  // 智能模式跳过词统计
                  if (enableSmartMode && skippedCount > 0) ...[
                    const SizedBox(height: 16),
                    _buildStatRow(
                      Icons.auto_awesome,
                      FluidTheme.primaryFluidGradient[0],
                      context.tr.skippedWords,
                      '$skippedCount',
                      textPrimary,
                      textSecondary,
                      isDark: isDark,
                    ),
                  ],
                  const Divider(height: 32),
                  _buildStatRow(
                    Icons.psychology_outlined,
                    FluidTheme.success,
                    context.tr.masteredCount,
                    '${sessionSummary.masteredWords}',
                    textPrimary,
                    textSecondary,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    Icons.trending_up,
                    FluidTheme.primaryFluidGradient[0],
                    context.tr.masteryRate,
                    '$accuracy%',
                    textPrimary,
                    textSecondary,
                    isLarge: true,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // S-MARS分数分布图表
            if (masteryStates.isNotEmpty) ...[
              _buildScoreDistributionChart(
                context,
                masteryStates,
                textPrimary,
                textSecondary,
                isDark,
              ),
              const SizedBox(height: 24),
              _buildMasteryPieChart(
                context,
                masteryStates,
                textPrimary,
                textSecondary,
                isDark,
              ),
              const SizedBox(height: 24),
            ],

            // 错词列表
            if (wrongWords.isNotEmpty) ...[
              Text(
                context.tr.wrongWordsList,
                style: FluidTheme.labelLarge(
                  isDark,
                ).copyWith(color: textPrimary),
              ),
              const SizedBox(height: 12),
              FluidCard(
                enableShimmer: false,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: wrongWords.map((word) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.cancel, size: 16, color: FluidTheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              word.word,
                              style: FluidTheme.bodyMedium(isDark).copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            word.phonetic,
                            style: FluidTheme.bodySmall(
                              isDark,
                            ).copyWith(color: textSecondary),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 查看答案列表
            if (revealedWords.isNotEmpty) ...[
              Text(
                context.tr.revealedWordsList,
                style: FluidTheme.labelLarge(
                  isDark,
                ).copyWith(color: textPrimary),
              ),
              const SizedBox(height: 12),
              FluidCard(
                enableShimmer: false,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: revealedWords.map((word) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 16,
                            color: FluidTheme.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              word.word,
                              style: FluidTheme.bodyMedium(isDark).copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            word.phonetic,
                            style: FluidTheme.bodySmall(
                              isDark,
                            ).copyWith(color: textSecondary),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 操作按钮
            FluidButton(
              text: context.tr.backToHome,
              icon: Icons.home,
              expanded: true,
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            const SizedBox(height: 12),
            if (wrongWords.isNotEmpty)
              FluidButton(
                text: context.tr.reviewWrongWords,
                icon: Icons.refresh,
                expanded: true,
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    PageTransitions.fade(
                      page: PreStudyScreen.continueStudy(
                        wordBookId: wordBookId,
                        words: wrongWords,
                        studyMode: studyMode,
                        isReview: true,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 构建分数分布柱状图
  Widget _buildScoreDistributionChart(
    BuildContext context,
    Map<int, SessionMasteryState> states,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    // 计算分数段分布（每10分一段：0-9, 10-19, ..., 90-100）
    final scoreBuckets = List<int>.filled(10, 0);
    for (final state in states.values) {
      final score = state.sessionScore.round();
      // 100分放在索引9（90-100桶），0-9分放在索引0
      final bucketIndex = (score ~/ 10).clamp(0, 9);
      scoreBuckets[bucketIndex]++;
    }

    // 保护：如果所有桶都是0（无数据），显示空图表
    final maxBucketValue = scoreBuckets.isEmpty
        ? 1.0
        : scoreBuckets.reduce(math.max).toDouble();
    final maxY = maxBucketValue > 0 ? maxBucketValue + 2 : 2.0;

    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: FluidTheme.primaryFluidGradient[0]),
              const SizedBox(width: 8),
              Text(
                context.tr.scoreDistribution,
                style: FluidTheme.labelLarge(
                  isDark,
                ).copyWith(color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${index * 10}',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(color: textSecondary, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? Colors.white24 : Colors.black12,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(10, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: scoreBuckets[index].toDouble(),
                        color: _getBucketColor(index),
                        width: 16,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建掌握状态饼图
  Widget _buildMasteryPieChart(
    BuildContext context,
    Map<int, SessionMasteryState> states,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    // 统计各状态数量（互斥分类：强掌握 > 已掌握 > 薄弱 > 学习中）
    int strongMastered = 0;
    int mastered = 0;
    int learning = 0;
    int weak = 0;

    for (final state in states.values) {
      // 按优先级判断，确保每个词只计入一个状态
      if (state.isStrongMastered) {
        strongMastered++; // 强掌握：sessionScore >= 82 && bestModeWeight >= 0.92
      } else if (state.isMastered) {
        mastered++; // 已掌握：sessionScore >= 76 && wrongCount == 0 && revealCount == 0
      } else if (state.isWeak) {
        weak++; // 薄弱词：sessionScore < 55 || wrongCount >= 2 || revealCount > 0
      } else {
        learning++; // 学习中：其他情况
      }
    }

    final total = states.length;
    if (total == 0) return const SizedBox.shrink();

    final sections = <PieChartSectionData>[];

    // 强掌握
    if (strongMastered > 0) {
      sections.add(
        PieChartSectionData(
          value: strongMastered.toDouble(),
          title: '${(strongMastered / total * 100).round()}%',
          color: FluidTheme.success,
          radius: 60,
          titleStyle: FluidTheme.numberStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 0.7,
          ),
        ),
      );
    }

    // 已掌握
    if (mastered > 0) {
      sections.add(
        PieChartSectionData(
          value: mastered.toDouble(),
          title: '${(mastered / total * 100).round()}%',
          color: FluidTheme.primaryFluidGradient[0],
          radius: 60,
          titleStyle: FluidTheme.numberStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 0.7,
          ),
        ),
      );
    }

    // 学习中
    if (learning > 0) {
      sections.add(
        PieChartSectionData(
          value: learning.toDouble(),
          title: '${(learning / total * 100).round()}%',
          color: FluidTheme.warning,
          radius: 60,
          titleStyle: FluidTheme.numberStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 0.7,
          ),
        ),
      );
    }

    // 薄弱词
    if (weak > 0) {
      sections.add(
        PieChartSectionData(
          value: weak.toDouble(),
          title: '${(weak / total * 100).round()}%',
          color: FluidTheme.error,
          radius: 60,
          titleStyle: FluidTheme.numberStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 0.7,
          ),
        ),
      );
    }

    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: FluidTheme.primaryFluidGradient[0]),
              const SizedBox(width: 8),
              Text(
                context.tr.masteryStatus,
                style: FluidTheme.labelLarge(
                  isDark,
                ).copyWith(color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 图例
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (strongMastered > 0)
                _buildLegendItem(
                  context.tr.strongMastered,
                  FluidTheme.success,
                  strongMastered,
                  textSecondary,
                ),
              if (mastered > 0)
                _buildLegendItem(
                  context.tr.mastered,
                  FluidTheme.primaryFluidGradient[0],
                  mastered,
                  textSecondary,
                ),
              if (learning > 0)
                _buildLegendItem(
                  context.tr.learning,
                  FluidTheme.warning,
                  learning,
                  textSecondary,
                ),
              if (weak > 0)
                _buildLegendItem(
                  context.tr.weakWords,
                  FluidTheme.error,
                  weak,
                  textSecondary,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建图例项
  Widget _buildLegendItem(
    String label,
    Color color,
    int count,
    Color textSecondary,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  /// 获取分数段颜色
  Color _getBucketColor(int bucketIndex) {
    // 从低分到高分：红→橙→黄→绿→蓝
    final colors = [
      const Color(0xFFE74C3C), // 0-10: 红
      const Color(0xFFE67E22), // 10-20: 橙
      const Color(0xFFF39C12), // 20-30: 黄橙
      const Color(0xFFF1C40F), // 30-40: 黄
      const Color(0xFF2ECC71), // 40-50: 绿
      const Color(0xFF1ABC9C), // 50-60: 青绿
      const Color(0xFF3498DB), // 60-70: 蓝
      const Color(0xFF2980B9), // 70-80: 深蓝
      const Color(0xFF8E44AD), // 80-90: 紫
      const Color(0xFF9B59B6), // 90-100: 浅紫
    ];
    return colors[bucketIndex.clamp(0, 9)];
  }

  Widget _buildStatRow(
    IconData icon,
    Color color,
    String label,
    String value,
    Color textPrimary,
    Color textSecondary, {
    bool isLarge = false,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: isLarge ? 28 : 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: isLarge
                ? FluidTheme.bodyLarge(isDark).copyWith(color: textSecondary)
                : FluidTheme.bodyMedium(isDark).copyWith(color: textSecondary),
          ),
        ),
        Text(
          value,
          style: isLarge
              ? FluidTheme.numberMedium(isDark, color: textPrimary)
              : FluidTheme.numberSmall(isDark, color: textPrimary),
        ),
      ],
    );
  }
}

/// 评分按钮
class _QualityButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _QualityButton({
    required this.label,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.55 : 0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
