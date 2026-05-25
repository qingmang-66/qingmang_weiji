import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/review_scheduler.dart';
import '../services/tts_service.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/fluid_loading.dart';

/// 学习前置选词界面 - 流体渐变风格
class PreStudyScreen extends StatefulWidget {
  final bool isReview;
  final int wordBookId;
  final List<Word>? presetWords;
  final int? presetStudyMode;

  const PreStudyScreen({
    super.key,
    required this.isReview,
    required this.wordBookId,
    this.presetWords,
    this.presetStudyMode,
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

  @override
  State<PreStudyScreen> createState() => _PreStudyScreenState();
}

class _PreStudyScreenState extends State<PreStudyScreen> {
  List<Word> _allWords = [];
  Set<int> _selectedIds = {};
  bool _isLoading = true;
  int _selectedStudyMode = 1;

  @override
  void initState() {
    super.initState();
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (ctx) => _DirectStudyScreen(
          isReview: widget.isReview,
          wordBookId: widget.wordBookId,
          presetWords: widget.presetWords!,
          studyMode: _selectedStudyMode,
        ),
      ),
    );
  }

  Future<void> _loadWords() async {
    final di = context.read<DIContainer>();
    _allWords = await di.wordRepository.getWordsByBook(widget.wordBookId);
    _selectedIds = _allWords.map((w) => w.id!).toSet();
    setState(() => _isLoading = false);
  }

  void _startStudy() {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少选择一个单词'),
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
        const SnackBar(
          content: Text('没有选中的单词'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (ctx) => _DirectStudyScreen(
          isReview: widget.isReview,
          wordBookId: widget.wordBookId,
          presetWords: selectedList,
          studyMode: _selectedStudyMode,
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
          widget.isReview ? '复习' : '学习',
          style: FluidTheme.headingSmall.copyWith(color: textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: FluidLoading(message: '加载中...'))
          : _allWords.isEmpty
          ? Center(
              child: Text(
                '词库为空，请先添加单词',
                style: FluidTheme.bodyMedium.copyWith(color: textSecondary),
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
            '选择学习模式',
            style: FluidTheme.headingSmall.copyWith(color: textPrimary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StudyModeChip(
                icon: Icons.visibility_outlined,
                label: '回忆模式',
                isSelected: _selectedStudyMode == 1,
                onTap: () => setState(() => _selectedStudyMode = 1),
              ),
              _StudyModeChip(
                icon: Icons.edit_outlined,
                label: '拼写模式',
                isSelected: _selectedStudyMode == 2,
                onTap: () => setState(() => _selectedStudyMode = 2),
              ),
              _StudyModeChip(
                icon: Icons.headphones_outlined,
                label: '听力模式',
                isSelected: _selectedStudyMode == 3,
                onTap: () => setState(() => _selectedStudyMode = 3),
              ),
              _StudyModeChip(
                icon: Icons.quiz_outlined,
                label: '测验模式(英选中)',
                isSelected: _selectedStudyMode == 4,
                onTap: () => setState(() => _selectedStudyMode = 4),
              ),
              _StudyModeChip(
                icon: Icons.translate,
                label: '测验模式(中选英)',
                isSelected: _selectedStudyMode == 5,
                onTap: () => setState(() => _selectedStudyMode = 5),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 单词数量信息
          FluidCard(
            enableShimmer: false,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FluidGradientContainer(
                  colors: FluidTheme.primaryFluidGradient,
                  borderRadius: 10,
                  padding: const EdgeInsets.all(10),
                  child: const Icon(
                    Icons.library_books,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isReview ? '复习单词' : '学习新词',
                      style: FluidTheme.labelLarge.copyWith(color: textPrimary),
                    ),
                    Text(
                      '共 ${_selectedIds.length} 个单词',
                      style: FluidTheme.bodySmall.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // 开始学习按钮
          FluidButton(
            text: '开始学习',
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
class _StudyModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StudyModeChip({
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
class _DirectStudyScreen extends StatefulWidget {
  final bool isReview;
  final int wordBookId;
  final List<Word> presetWords;
  final int studyMode;

  const _DirectStudyScreen({
    required this.isReview,
    required this.wordBookId,
    required this.presetWords,
    required this.studyMode,
  });

  @override
  State<_DirectStudyScreen> createState() => _DirectStudyScreenState();
}

class _DirectStudyScreenState extends State<_DirectStudyScreen> {
  late List<Word> _words;
  final TextEditingController _answerController = TextEditingController();
  final Map<int, ReviewRecord?> _cachedRecords = {};
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isPlaying = false;
  bool _isSavingQuality = false;
  bool _hasCheckedAnswer = false;
  bool _isAnswerCorrect = false;
  int? _selectedQuizOption;
  List<String> _quizOptions = [];

  @override
  void initState() {
    super.initState();
    _words = widget.presetWords;
    _prepareModeState(playListeningAudio: true);
    _preloadRecords();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _preloadRecords() async {
    final reviewRepository = context.read<DIContainer>().reviewRepository;
    final Map<int, ReviewRecord?> loaded = {};
    for (final word in _words) {
      loaded[word.id!] = await reviewRepository.getReviewRecord(word.id!);
    }
    if (mounted) {
      setState(() {
        _cachedRecords.addAll(loaded);
      });
    }
  }

  void _prepareModeState({bool playListeningAudio = false}) {
    _showAnswer = false;
    _hasCheckedAnswer = false;
    _isAnswerCorrect = false;
    _selectedQuizOption = null;
    _answerController.clear();
    if (widget.studyMode == 4 || widget.studyMode == 5) {
      _quizOptions = _generateQuizOptions(_words[_currentIndex]);
    } else {
      _quizOptions = [];
    }
    if (playListeningAudio && widget.studyMode == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _playWord());
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
    } catch (e) {
      debugPrint('保存复习记录失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存学习记录失败，请重试')));
      }
      _isSavingQuality = false;
      return;
    }

    _isSavingQuality = false;
    if (!mounted) return;

    if (_currentIndex < _words.length - 1) {
      setState(() {
        _currentIndex++;
        _prepareModeState(playListeningAudio: true);
      });
    } else {
      _finishStudy();
    }
  }

  void _finishStudy() {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    showFluidDialog(
      context: context,
      barrierDismissible: false,
      content: Text(
        '共学习了 ${_words.length} 个单词',
        style: FluidTheme.bodyMedium.copyWith(
          color: FluidTheme.getTextSecondaryColor(isDark),
        ),
      ),
      title: widget.isReview ? '复习完成！' : '学习完成！',
      actions: [
        FluidButton(
          text: '返回',
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
      ],
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
    setState(() {
      _hasCheckedAnswer = true;
      _isAnswerCorrect =
          _normalizeAnswer(_answerController.text) ==
          _normalizeAnswer(word.word);
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
    });
  }

  String _normalizeAnswer(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _correctQuizAnswer(Word word) {
    return widget.studyMode == 4 ? _definitionText(word) : word.word;
  }

  String _definitionText(Word word) {
    return word.definition.trim().isNotEmpty ? word.definition.trim() : '暂无释义';
  }

  List<String> _generateQuizOptions(Word word) {
    final correct = _correctQuizAnswer(word);
    final options = <String>{correct};
    final candidates = _words
        .where((item) => item.id != word.id)
        .map(
          (item) => widget.studyMode == 4 ? _definitionText(item) : item.word,
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
        widget.studyMode == 4 ? '干扰释义 $fallbackIndex' : 'option_$fallbackIndex',
      );
      fallbackIndex++;
    }
    final result = options.toList()..shuffle(math.Random());
    return result;
  }

  String get _modeTitle {
    switch (widget.studyMode) {
      case 2:
        return '拼写模式';
      case 3:
        return '听力模式';
      case 4:
        return '测验模式 · 英选中';
      case 5:
        return '测验模式 · 中选英';
      default:
        return '回忆模式';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);

    return Scaffold(
      backgroundColor: FluidTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        title: Text(
          '${_currentIndex + 1} / ${_words.length} · $_modeTitle',
          style: FluidTheme.labelLarge.copyWith(color: textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildStudyContent(),
    );
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _buildModeContent(isDark, key: ValueKey(_currentIndex)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeContent(bool isDark, {required Key key}) {
    switch (widget.studyMode) {
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
      children: [
        const SizedBox(height: 32),
        Text(
          word.word,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        if (word.phonetic.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            word.phonetic,
            style: TextStyle(fontSize: 16, color: textSecondary),
          ),
        ],
        const SizedBox(height: 16),
        _buildPlayButton(),
        const SizedBox(height: 32),
        if (!_showAnswer)
          FluidButton(
            text: '显示释义',
            icon: Icons.visibility_outlined,
            expanded: true,
            onPressed: () => setState(() => _showAnswer = true),
          ),
        if (_showAnswer) ...[
          _buildDefinitionCard(word, isDark),
          const SizedBox(height: 16),
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
        const SizedBox(height: 24),
        Icon(
          isListening ? Icons.headphones : Icons.edit_outlined,
          size: 48,
          color: FluidTheme.primaryFluidGradient[0],
        ),
        const SizedBox(height: 16),
        Text(
          isListening ? '听发音，拼写单词' : '根据释义，拼写单词',
          textAlign: TextAlign.center,
          style: FluidTheme.headingSmall.copyWith(color: textPrimary),
        ),
        const SizedBox(height: 12),
        if (isListening)
          _buildPlayButton()
        else
          FluidCard(
            enableShimmer: false,
            padding: const EdgeInsets.all(16),
            child: Text(
              _definitionText(word),
              textAlign: TextAlign.center,
              style: FluidTheme.bodyMedium.copyWith(color: textSecondary),
            ),
          ),
        const SizedBox(height: 20),
        TextField(
          controller: _answerController,
          enabled: !_hasCheckedAnswer,
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          cursorColor: FluidTheme.primaryFluidGradient[0],
          decoration: InputDecoration(
            filled: true,
            fillColor: FluidTheme.getInputFillColor(isDark),
            hintText: '请输入英文单词',
            hintStyle: TextStyle(
              color: FluidTheme.getTextTertiaryColor(isDark),
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
          onSubmitted: (_) {
            if (!_hasCheckedAnswer) _checkTypedAnswer();
          },
        ),
        const SizedBox(height: 16),
        if (!_hasCheckedAnswer)
          FluidButton(
            text: '检查答案',
            icon: Icons.check,
            expanded: true,
            onPressed: _checkTypedAnswer,
          ),
        if (_hasCheckedAnswer) ...[
          FluidCard(
            enableShimmer: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAnswerCorrect ? '回答正确' : '回答错误',
                  style: FluidTheme.labelLarge.copyWith(color: resultColor),
                ),
                const SizedBox(height: 8),
                Text(
                  '正确答案：${word.word}',
                  style: FluidTheme.bodyMedium.copyWith(color: textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  _definitionText(word),
                  style: FluidTheme.bodyMedium.copyWith(color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildQualityButtons(isDark),
        ],
      ],
    );
  }

  Widget _buildQuizMode(bool isDark, {required Key key}) {
    final word = _words[_currentIndex];
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final prompt = widget.studyMode == 4 ? word.word : _definitionText(word);

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          widget.studyMode == 4 ? '请选择正确中文释义' : '请选择正确英文单词',
          textAlign: TextAlign.center,
          style: FluidTheme.headingSmall.copyWith(color: textPrimary),
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
                  fontSize: widget.studyMode == 4 ? 30 : 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              if (widget.studyMode == 4 && word.phonetic.isNotEmpty) ...[
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
          _buildQualityButtons(isDark),
        ],
      ],
    );
  }

  Widget _buildPlayButton() {
    return IconButton(
      icon: Icon(
        _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
        color: FluidTheme.primaryFluidGradient[0],
        size: 32,
      ),
      onPressed: _playWord,
    );
  }

  Widget _buildDefinitionCard(Word word, bool isDark) {
    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '释义',
            style: FluidTheme.labelLarge.copyWith(
              color: FluidTheme.getTextPrimaryColor(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _definitionText(word),
            style: FluidTheme.bodyMedium.copyWith(
              color: FluidTheme.getTextSecondaryColor(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityButtons(bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        _QualityButton(
          label: '忘记',
          color: Colors.red,
          onTap: () => _onQualitySelected(1),
          isDark: isDark,
        ),
        _QualityButton(
          label: '模糊',
          color: Colors.orange,
          onTap: () => _onQualitySelected(2),
          isDark: isDark,
        ),
        _QualityButton(
          label: '记住',
          color: Colors.green,
          onTap: () => _onQualitySelected(3),
          isDark: isDark,
        ),
        _QualityButton(
          label: '熟悉',
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
                style: FluidTheme.bodyMedium.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(icon, color: borderColor, size: 20),
          ],
        ),
      ),
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
