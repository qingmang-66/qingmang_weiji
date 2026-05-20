import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/review_scheduler.dart';
import '../services/dictionary_api_service.dart';
import '../services/tts_service.dart';
import '../services/database_service.dart';
import '../services/local_dictionary_service.dart';

/// iOS 风格颜色常量
class _IOSColors {
  static const Color systemGreen = Color(0xFF34C759);
  static const Color systemRed = Color(0xFFFF3B30);
  static const Color systemBlue = Color(0xFF007AFF);
  static const Color systemOrange = Color(0xFFFF9500);
  static const Color systemPurple = Color(0xFFAF52DE);
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemGray2 = Color(0xFFAEAEB2);
  static const Color systemGray5 = Color(0xFFF2F2F7);
  static const Color systemGray6 = Color(0xFFF8F8FA);
}

/// iOS 风格阴影
final BoxShadow _iosShadow = BoxShadow(
  color: Colors.black.withValues(alpha: 0.08),
  blurRadius: 12,
  offset: const Offset(0, 4),
);

/// 学习前置选词界面：选择从哪个词开始、跳过哪些词
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

  /// 工厂方法：继续上次未完成的学��
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
  final int _startIndex = 0;
  bool _isLoading = true;
  int _selectedStudyMode = 1; // 默认回忆模式

  @override
  void initState() {
    super.initState();
    // 如果有预设单词列表（继续学习），直接跳转到学习界面
    if (widget.presetWords != null && widget.presetWords!.isNotEmpty) {
      _selectedStudyMode = widget.presetStudyMode ?? 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startDirectStudy();
      });
    } else {
      _loadWords();
    }
  }

  /// 直接开始学��（用于继续上次进度）
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

    // 默认全选所有单词
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
    for (int i = _startIndex; i < _allWords.length; i++) {
      if (_selectedIds.contains(_allWords[i].id)) {
        selectedList.add(_allWords[i]);
      }
    }
    if (_startIndex > 0) {
      for (int i = 0; i < _startIndex; i++) {
        if (_selectedIds.contains(_allWords[i].id)) {
          selectedList.add(_allWords[i]);
        }
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isReview ? '复习' : '学习'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allWords.isEmpty
              ? Center(
                  child: Text(
                    '词库为空，请先添加单词',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 学习模式选择
                      Text(
                        '选择学习模式',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
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
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.library_books, color: colorScheme.primary),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.isReview ? '复习单词' : '学习新词',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  '共 ${_selectedIds.length} 个单词',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      // 开始学习按钮
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _selectedIds.isEmpty ? null : _startStudy,
                          icon: const Icon(Icons.play_arrow),
                          label: Text('开始学习'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// 直接进入学习（使用预设词列表，批量预取复习记录）
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
  int _currentIndex = 0;
  bool _showAnswer = false;

  // 拼写模式相关
  final TextEditingController _spellController = TextEditingController();
  bool _spellCorrect = false;

  // 听力模式相关
  bool _isPlaying = false;

  // 测验模式相关
  int? _selectedQuizOption;
  int? _correctQuizOption;
  List<String> _quizOptions = [];
  bool _quizOptionsLoading = false;

  // 字典查询相关
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedWordDetail;
  Timer? _searchDebounce;

  /// 预加载的复习记录缓存（key = word.id）
  final Map<int, ReviewRecord?> _cachedRecords = {};
  final List<Future<void>> _pendingSaves = [];
  bool _recordsPreloaded = false;

  @override
  void initState() {
    super.initState();
    _words = widget.presetWords;
    // 监听拼写输入变化，触发UI重建（更新按钮状态和边框颜色）
    _spellController.addListener(() => setState(() {}));
    _preloadRecords();
  }

  @override
  void dispose() {
    _spellController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
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
        _recordsPreloaded = true;
      });
    }
  }

  void _onQualitySelected(int quality) {
    final word = _words[_currentIndex];

    final record = _cachedRecords.containsKey(word.id!)
        ? (_cachedRecords[word.id!] ??
            ReviewScheduler.createInitialRecord(word.id!))
        : ReviewScheduler.createInitialRecord(word.id!);

    final nextRecord = ReviewScheduler.scheduleNextReview(record, quality);
    _cachedRecords[word.id!] = nextRecord;
    _pendingSaves.add(context.read<DIContainer>().reviewRepository.saveReviewRecord(nextRecord));

    if (_currentIndex < _words.length - 1) {
      // 保存进度
      _saveProgress();
      setState(() {
        _currentIndex++;
        _showAnswer = false;
        // 重置所有模式的状态
        _spellController.clear();
        _spellCorrect = false;
        _quizOptions = [];
        _selectedQuizOption = null;
        _correctQuizOption = null;
        _quizOptionsLoading = false;
      });
    } else {
      _finishStudy();
    }
  }

  /// 保存当前学习进度到数据库
  Future<void> _saveProgress() async {
    try {
      await DatabaseService.saveStudyProgress(
        wordBookId: widget.wordBookId,
        studyMode: widget.studyMode,
        isReview: widget.isReview,
        currentIndex: _currentIndex + 1,
        wordIds: _words.map((w) => w.id!).toList(),
      );
    } catch (e) {
      debugPrint('保存学习进度失败: $e');
    }
  }

  Future<void> _finishStudy() async {
    await Future.wait(_pendingSaves);
    // 学习完成，清除进度
    await DatabaseService.clearStudyProgress();
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            widget.isReview ? Icons.celebration : Icons.school,
            size: 48,
            color: Theme.of(ctx).colorScheme.primary,
          ),
          title: Text(
              widget.isReview ? '复习完成！' : '学习完成！'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '今天${widget.isReview ? '复习' : '学习'}了'
                ' ${_words.length} 个单词',
              ),
              const SizedBox(height: 8),
              Text(
                '继续保持，每天进步一点点 💪',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('返回首页'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isReview ? '复习单词' : '学习新词'),
        actions: [
          // 字典查询按钮
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '查询字典',
            onPressed: _showDictionarySearch,
          ),
          if (_words.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${_words.length}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
      body: _words.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle,
                      size: 64, color: colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    '没有选中任何单词',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : _recordsPreloaded
              ? _buildStudyCard(colorScheme)
              : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildStudyCard(ColorScheme colorScheme) {
    final word = _words[_currentIndex];

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              children: [
                // 进度条 - iOS风格
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: _IOSColors.systemGray5,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (_currentIndex + 1) / _words.length,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _IOSColors.systemBlue,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 根据学习模式显示不同内容
                _buildModeContent(word, colorScheme),
              ],
            ),
          ),
        ),

        // 底部操作区
        _buildBottomControls(colorScheme),
      ],
    );
  }

  /// 根据学习模式构建内容
  Widget _buildModeContent(Word word, ColorScheme colorScheme) {
    switch (widget.studyMode) {
      case 1: // 回忆模式 (默认)
        return _buildRecallMode(word, colorScheme);
      case 2: // 拼写模式
        return _buildSpellMode(word, colorScheme);
      case 3: // 听力模式
        return _buildListenMode(word, colorScheme);
      case 4: // 测验模式 - 看英文选中文
        return _buildQuizModeEnToCn(word, colorScheme);
      case 5: // 测验模式 - 看中文选英文
        return _buildQuizModeCnToEn(word, colorScheme);
      default:
        return _buildRecallMode(word, colorScheme);
    }
  }

  /// 回忆模式 - iOS风格
  Widget _buildRecallMode(Word word, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 单词卡片
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _IOSColors.systemGray6,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [_iosShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.word,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            color: Colors.black87,
                          ),
                        ),
                        if (word.phonetic.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            word.phonetic,
                            style: const TextStyle(
                              fontSize: 18,
                              color: _IOSColors.systemBlue,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _StudyAudioButton(word: word.word),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 显示释义按钮
        if (!_showAnswer) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => setState(() => _showAnswer = true),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _IOSColors.systemBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '显示释义',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // 释义区域
        if (_showAnswer) ...[
          const SizedBox(height: 8),
          _DefinitionSection(word: word, colorScheme: colorScheme),
        ],
      ],
    );
  }

  /// 拼写模式 - iOS风格
  Widget _buildSpellMode(Word word, ColorScheme colorScheme) {
    return Column(
      children: [
        // 中文提示卡片
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _IOSColors.systemGray6,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [_iosShadow],
          ),
          child: Column(
            children: [
              const Text(
                '请拼写以下单词',
                style: TextStyle(
                  fontSize: 15,
                  color: _IOSColors.systemGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                word.definition.isNotEmpty ? word.definition : '请拼写单词',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 输入框
        if (!_showAnswer) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _spellController.text.isNotEmpty
                    ? _IOSColors.systemBlue
                    : _IOSColors.systemGray2,
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _spellController,
              keyboardType: TextInputType.visiblePassword,
              enableSuggestions: false,
              autocorrect: false,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                hintText: '输入英文单词...',
                hintStyle: const TextStyle(
                  color: _IOSColors.systemGray2,
                  fontSize: 17,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                suffixIcon: _spellController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: _IOSColors.systemGray),
                        onPressed: () => setState(() => _spellController.clear()),
                      )
                    : null,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _checkSpell(word),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _spellController.text.trim().isNotEmpty
                  ? () => _checkSpell(word)
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _IOSColors.systemBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '提交',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ] else ...[
          // 显示结果
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _spellCorrect
                  ? _IOSColors.systemGreen.withValues(alpha: 0.1)
                  : _IOSColors.systemRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _spellCorrect
                    ? _IOSColors.systemGreen.withValues(alpha: 0.3)
                    : _IOSColors.systemRed.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _spellCorrect ? Icons.check_circle : Icons.cancel,
                  color: _spellCorrect ? _IOSColors.systemGreen : _IOSColors.systemRed,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _spellCorrect ? '拼写正确！' : '拼写错误',
                  style: TextStyle(
                    fontSize: 20,
                    color: _spellCorrect ? _IOSColors.systemGreen : _IOSColors.systemRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!_spellCorrect) ...[
                  const SizedBox(height: 8),
                  Text(
                    '正确答案: ${word.word}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 听力模式 - iOS风格
  Widget _buildListenMode(Word word, ColorScheme colorScheme) {
    return Column(
      children: [
        // 播放按钮区域
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: _IOSColors.systemGray6,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [_iosShadow],
          ),
          child: Column(
            children: [
              const Text(
                '听发音，猜单词',
                style: TextStyle(
                  fontSize: 15,
                  color: _IOSColors.systemGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              // 大圆形播放按钮
              GestureDetector(
                onTap: _isPlaying ? null : () => _playAudio(word.word),
                child: AnimatedScale(
                  scale: _isPlaying ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: _IOSColors.systemBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _IOSColors.systemBlue.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isPlaying
                          ? const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.play_arrow,
                              size: 56,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isPlaying ? '正在播放...' : '点击播放发音',
                style: const TextStyle(
                  fontSize: 15,
                  color: _IOSColors.systemGray,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        if (!_showAnswer) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => setState(() => _showAnswer = true),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _IOSColors.systemBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '显示答案',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          // 显示答案区域
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _IOSColors.systemGray6,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [_iosShadow],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      word.word,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StudyAudioButton(word: word.word),
                  ],
                ),
                if (word.phonetic.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    word.phonetic,
                    style: const TextStyle(
                      fontSize: 16,
                      color: _IOSColors.systemBlue,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text(
                  word.definition.isNotEmpty ? word.definition : '暂无释义',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 测验模式 - 看中文选英文
  Widget _buildQuizModeCnToEn(Word word, ColorScheme colorScheme) {
    // 异步生成英文单词选项（首次或切题后）
    if (_quizOptions.isEmpty && !_quizOptionsLoading) {
      _quizOptionsLoading = true;
      _loadQuizOptionsForWord(word, isEnToCn: false);
    }

    // 加载中显示指示器
    if (_quizOptions.isEmpty && _quizOptionsLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在生成选项...', style: TextStyle(color: _IOSColors.systemGray)),
          ],
        ),
      );
    }

    // 选项未准备好时显示空状态
    if (_quizOptions.isEmpty) {
      return const Center(child: Text('选项生成失败'));
    }

    return _buildQuizMode(
      word: word,
      colorScheme: colorScheme,
      questionText: word.definition.isNotEmpty ? word.definition : '暂无释义',
      questionLabel: '请选择正确的英文单词',
      options: _quizOptions,
      correctAnswer: word.word,
    );
  }

  /// 测验模式 - 看英文选中文
  Widget _buildQuizModeEnToCn(Word word, ColorScheme colorScheme) {
    // 异步生成中文释义选项（首次或切题后）
    if (_quizOptions.isEmpty && !_quizOptionsLoading) {
      _quizOptionsLoading = true;
      _loadQuizOptionsForWord(word, isEnToCn: true);
    }

    // 加载中显示指示器
    if (_quizOptions.isEmpty && _quizOptionsLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在生成选项...', style: TextStyle(color: _IOSColors.systemGray)),
          ],
        ),
      );
    }

    // 选项未准备好时显示空状态
    if (_quizOptions.isEmpty) {
      return const Center(child: Text('选项生成失败'));
    }
    
    return _buildQuizMode(
      word: word,
      colorScheme: colorScheme,
      questionText: word.word,
      questionLabel: '请选择正确的中文释义',
      options: _quizOptions,
      correctAnswer: word.definition.isNotEmpty ? word.definition : '暂无释义',
      isEnToCn: true,
    );
  }

  /// 异步加载测验选项
  Future<void> _loadQuizOptionsForWord(Word word, {required bool isEnToCn}) async {
    try {
      final options = isEnToCn
          ? await _generateCnQuizOptions(word)
          : await _generateQuizOptions(word);

      if (mounted) {
        setState(() {
          _quizOptions = options;
          _correctQuizOption = isEnToCn
              ? options.indexOf(word.definition.isNotEmpty ? word.definition : '暂无释义')
              : options.indexOf(word.word);
          _selectedQuizOption = null;
          _quizOptionsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('生成测验选项失败: $e');
      if (mounted) {
        setState(() => _quizOptionsLoading = false);
      }
    }
  }

  /// 生成中文测验选项（异步，可从词典补充干扰项）
  Future<List<String>> _generateCnQuizOptions(Word correctWord) async {
    final correctDef = correctWord.definition.isNotEmpty ? correctWord.definition : '暂无释义';
    final options = <String>[correctDef];

    // 从当前词库中随机选择干扰项
    final otherWords = _words.where((w) => w.id != correctWord.id).toList();
    otherWords.shuffle();

    final neededFromList = otherWords.length >= 3 ? 3 : otherWords.length;
    for (var i = 0; i < neededFromList; i++) {
      options.add(otherWords[i].definition.isNotEmpty ? otherWords[i].definition : '暂无释义');
    }

    // 如果词库中干扰项不足3个，从本地词典补充
    if (options.length < 4) {
      final needed = 4 - options.length;
      final excludeWords = _words.map((w) => w.word).toList();
      final randomWords = await LocalDictionaryService.getRandomWords(
        count: needed,
        excludeWords: excludeWords,
      );
      for (final rw in randomWords) {
        final translation = rw['translation'] as String?;
        if (translation != null && translation.isNotEmpty) {
          // 取第一个释义（多义词用分号分隔）
          final firstDef = translation.split(';').first.trim();
          if (firstDef.isNotEmpty && !options.contains(firstDef)) {
            options.add(firstDef);
          }
        }
        if (options.length >= 4) break;
      }
    }

    // 最终兜底：仍然不足4个时用编号占位
    while (options.length < 4) {
      options.add('释义${options.length}');
    }

    options.shuffle();
    return options;
  }

  /// 通用测验模式UI - iOS风格
  Widget _buildQuizMode({
    required Word word,
    required ColorScheme colorScheme,
    required String questionText,
    required String questionLabel,
    required List<String> options,
    required String correctAnswer,
    bool isEnToCn = false,
  }) {
    // 选项字母标签
    const optionLabels = ['A', 'B', 'C', 'D'];

    return Column(
      children: [
        // 题目卡片
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _IOSColors.systemBlue,
                _IOSColors.systemBlue.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _IOSColors.systemBlue.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                questionLabel,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                questionText,
                style: TextStyle(
                  fontSize: isEnToCn ? 32 : 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: isEnToCn ? -0.5 : 0,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 选项列表
        ...List.generate(_quizOptions.length, (index) {
          final option = _quizOptions[index];
          final isSelected = _selectedQuizOption == index;
          final isCorrect = index == _correctQuizOption;

          // 计算选项样式
          Color backgroundColor = Colors.white;
          Color borderColor = _IOSColors.systemGray5;
          Color labelColor = _IOSColors.systemGray;
          Color textColor = Colors.black87;
          IconData? trailingIcon;
          Color? trailingIconColor;

          if (_showAnswer) {
            if (isCorrect) {
              backgroundColor = _IOSColors.systemGreen.withValues(alpha: 0.1);
              borderColor = _IOSColors.systemGreen;
              labelColor = _IOSColors.systemGreen;
              textColor = _IOSColors.systemGreen;
              trailingIcon = Icons.check_circle;
              trailingIconColor = _IOSColors.systemGreen;
            } else if (isSelected && !isCorrect) {
              backgroundColor = _IOSColors.systemRed.withValues(alpha: 0.1);
              borderColor = _IOSColors.systemRed;
              labelColor = _IOSColors.systemRed;
              textColor = _IOSColors.systemRed;
              trailingIcon = Icons.cancel;
              trailingIconColor = _IOSColors.systemRed;
            } else {
              backgroundColor = _IOSColors.systemGray5;
              textColor = _IOSColors.systemGray;
            }
          } else if (isSelected) {
            backgroundColor = _IOSColors.systemBlue.withValues(alpha: 0.1);
            borderColor = _IOSColors.systemBlue;
            labelColor = _IOSColors.systemBlue;
            textColor = _IOSColors.systemBlue;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showAnswer ? null : () => _checkQuizAnswer(index),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: borderColor,
                      width: isSelected || (_showAnswer && (isCorrect || (isSelected && !isCorrect))) ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // 选项字母标签
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: labelColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            optionLabels[index],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: labelColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 选项文本
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: isSelected || (_showAnswer && isCorrect)
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: textColor,
                          ),
                        ),
                      ),
                      // 右侧状态图标
                      if (trailingIcon != null)
                        Icon(
                          trailingIcon,
                          color: trailingIconColor,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  void _checkSpell(Word word) {
    final input = _spellController.text.trim().toLowerCase();
    final correct = word.word.toLowerCase();
    setState(() {
      _showAnswer = true;
      _spellCorrect = input == correct;
    });
    
    // 弹出反馈卡片
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _showSpellFeedback(word, input);
      }
    });
  }

  /// 拼写模式反馈卡片
  void _showSpellFeedback(Word word, String userAnswer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AnswerFeedbackSheet(
        isCorrect: _spellCorrect,
        correctAnswer: word.word,
        userAnswer: userAnswer,
        word: word,
        onNext: () {
          Navigator.pop(ctx);
          _onSpellNext();
        },
        onExit: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
      ),
    );
  }

  /// 生成英文测验选项（异步，可从词典补充干扰项）
  Future<List<String>> _generateQuizOptions(Word correctWord) async {
    final options = <String>[correctWord.word];

    // 从当前词库中随机选择干扰项
    final otherWords = _words.where((w) => w.id != correctWord.id).toList();
    otherWords.shuffle();

    final neededFromList = otherWords.length >= 3 ? 3 : otherWords.length;
    for (var i = 0; i < neededFromList; i++) {
      options.add(otherWords[i].word);
    }

    // 如果词库中干扰项不足3个，从本地词典补充
    if (options.length < 4) {
      final needed = 4 - options.length;
      final excludeWords = options.toList();
      final randomWords = await LocalDictionaryService.getRandomWords(
        count: needed,
        excludeWords: excludeWords,
      );
      for (final rw in randomWords) {
        options.add(rw['word'] as String);
        if (options.length >= 4) break;
      }
    }

    // 最终兜底：仍然不足4个时用编号占位
    while (options.length < 4) {
      options.add('单词${options.length}');
    }

    options.shuffle();
    return options;
  }

  /// 检查测验答案
  void _checkQuizAnswer(int selectedIndex) {
    setState(() {
      _showAnswer = true;
      _selectedQuizOption = selectedIndex;
    });
    
    // 延迟弹出反馈卡片，等待UI更新
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _showQuizFeedback();
      }
    });
  }

  /// 测验模式：显示反馈卡片
  void _showQuizFeedback() {
    final word = _words[_currentIndex];
    final isCorrect = _selectedQuizOption == _correctQuizOption;
    final userAnswer = _selectedQuizOption != null ? _quizOptions[_selectedQuizOption!] : null;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AnswerFeedbackSheet(
        isCorrect: isCorrect,
        correctAnswer: widget.studyMode == 4
            ? word.word
            : (word.definition.isNotEmpty ? word.definition : '暂无释义'),
        userAnswer: userAnswer,
        word: word,
        onNext: () {
          Navigator.pop(ctx);
          _onQuizNext();
        },
        onExit: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
      ),
    );
  }

  /// 测验模式：进入下一个单词
  void _onQuizNext() {
    // 根据选择正误评分：正确=4（容易），错误=2（困难）
    final isCorrect = _selectedQuizOption == _correctQuizOption;
    final quality = isCorrect ? 4 : 2;

    // 重置测验状态
    _quizOptions = [];
    _selectedQuizOption = null;
    _correctQuizOption = null;
    _quizOptionsLoading = false;

    _onQualitySelected(quality);
  }
  
  /// 拼写模式：进入下一个单词
  void _onSpellNext() {
    // 根据拼写正误选择质量评分：正确=4（容易），错误=1（忘记）
    final quality = _spellCorrect ? 4 : 1;
    _onQualitySelected(quality);
  }

  Future<void> _playAudio(String word) async {
    setState(() => _isPlaying = true);
    try {
      final cachedPath = await DictionaryApiService.getCachedAudioPath(word);
      if (cachedPath != null) {
        await DictionaryApiService.playCachedAudio(cachedPath);
      } else {
        final result = await DictionaryApiService.fetchWord(word);
        final audioUrl = result?.audioUrl;
        if (audioUrl != null) {
          final path = await DictionaryApiService.downloadAndCacheAudio(
            audioUrl,
            word,
          );
          if (path != null) {
            await DictionaryApiService.playCachedAudio(path);
          }
        }
      }
    } catch (e) {
      await TtsService().playWord(word);
    }
    setState(() => _isPlaying = false);
  }

  /// 显示字典查询弹窗
  void _showDictionarySearch() {
    _searchController.clear();
    _searchResults = [];
    _selectedWordDetail = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => _buildDictionarySheet(setModalState),
      ),
    );
  }

  /// 构建字典查询界面
  Widget _buildDictionarySheet(StateSetter setModalState) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 搜索栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: _IOSColors.systemGray),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '输入单词查询...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: _IOSColors.systemGray2,
                        fontSize: 17,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.black87,
                    ),
                    onChanged: (value) {
                      if (value.length >= 2) {
                        _performSearch(value, setModalState);
                      }
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, color: _IOSColors.systemGray),
                    onPressed: () {
                      _searchController.clear();
                      setModalState(() {
                        _searchResults = [];
                        _selectedWordDetail = null;
                      });
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 搜索结果或详情
          Expanded(
            child: _selectedWordDetail != null
                ? _buildWordDetail(_selectedWordDetail!)
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_book,
                              size: 64,
                              color: _IOSColors.systemGray2,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '输入单词开始查询',
                              style: TextStyle(
                                fontSize: 17,
                                color: _IOSColors.systemGray,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return ListTile(
                            title: Text(
                              result['word'] ?? '',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              result['translation'] ?? result['definition'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _IOSColors.systemGray,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right, color: _IOSColors.systemGray2),
                            onTap: () async {
                              final detail = await LocalDictionaryService.lookup(result['word']);
                              setModalState(() {
                                _selectedWordDetail = detail;
                              });
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// 执行搜索
  void _performSearch(String query, StateSetter setModalState) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await LocalDictionaryService.search(query, limit: 20);

      setModalState(() {
        _searchResults = results;
      });
    });
  }

  /// 构建单词详情
  Widget _buildWordDetail(Map<String, dynamic> detail) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 单词和音标
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail['word'] ?? '',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (detail['phonetic'] != null && detail['phonetic'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail['phonetic'],
                        style: const TextStyle(
                          fontSize: 16,
                          color: _IOSColors.systemBlue,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 发音按钮
              IconButton.filled(
                onPressed: () => TtsService().playWord(detail['word']),
                icon: const Icon(Icons.volume_up, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: _IOSColors.systemBlue.withValues(alpha: 0.1),
                  foregroundColor: _IOSColors.systemBlue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // 释义
          if (detail['translation'] != null) ...[
            const Text(
              '释义',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _IOSColors.systemGray,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail['translation'],
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Collins 星级
          if (detail['collins'] != null) ...[
            Row(
              children: [
                const Text(
                  'Collins: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: _IOSColors.systemGray,
                  ),
                ),
                ...List.generate(5, (index) {
                  return Icon(
                    index < (detail['collins'] as int) ? Icons.star : Icons.star_border,
                    size: 18,
                    color: _IOSColors.systemOrange,
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 底部操作区 - iOS风格
  Widget _buildBottomControls(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: _IOSColors.systemGray5,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上一题/下一题按钮（非测验模式）
            if (!_showAnswer || (widget.studyMode != 4 && widget.studyMode != 5)) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _currentIndex > 0
                          ? () {
                              setState(() {
                                _currentIndex--;
                                _showAnswer = false;
                                _spellController.clear();
                                _spellCorrect = false;
                                _quizOptions = [];
                                _selectedQuizOption = null;
                                _correctQuizOption = null;
                                _quizOptionsLoading = false;
                              });
                            }
                          : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: _IOSColors.systemGray2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_left, size: 18),
                          SizedBox(width: 4),
                          Text(
                            '上一题',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _currentIndex < _words.length - 1
                          ? () {
                              setState(() {
                                _currentIndex++;
                                _showAnswer = false;
                                _spellController.clear();
                                _spellCorrect = false;
                                _quizOptions = [];
                                _selectedQuizOption = null;
                                _correctQuizOption = null;
                                _quizOptionsLoading = false;
                              });
                            }
                          : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: _IOSColors.systemGray2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '下一题',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // 回忆模式评分条
            if (_showAnswer && widget.studyMode == 1) ...[
              const SizedBox(height: 16),
              _QualityRatingBar(onSelected: _onQualitySelected),
            ],

            // 拼写模式下一个按钮
            if (_showAnswer && widget.studyMode == 2) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _onSpellNext(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: _IOSColors.systemBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_forward, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '下一题',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // 听力模式评分条
            if (_showAnswer && widget.studyMode == 3) ...[
              const SizedBox(height: 16),
              _QualityRatingBar(onSelected: _onQualitySelected),
            ],
          ],
        ),
      ),
    );
  }
}

/// 答题反馈卡片 - iOS风格底部弹出式
class _AnswerFeedbackSheet extends StatelessWidget {
  final bool isCorrect;
  final String correctAnswer;
  final String? userAnswer;
  final Word word;
  final VoidCallback onNext;
  final VoidCallback onExit;

  const _AnswerFeedbackSheet({
    required this.isCorrect,
    required this.correctAnswer,
    this.userAnswer,
    required this.word,
    required this.onNext,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 状态栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: isCorrect ? _IOSColors.systemGreen : _IOSColors.systemRed,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.error_outline,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  isCorrect ? '回答正确！' : '回答错误',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 正确答案
                Row(
                  children: [
                    const Text(
                      '正确答案：',
                      style: TextStyle(
                        fontSize: 15,
                        color: _IOSColors.systemGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        correctAnswer,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),

                // 用户答案（错误时显示）
                if (!isCorrect && userAnswer != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        '你的答案：',
                        style: TextStyle(
                          fontSize: 15,
                          color: _IOSColors.systemGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          userAnswer!,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _IOSColors.systemRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),

                // 单词详情
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            word.word,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          if (word.phonetic.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              word.phonetic,
                              style: const TextStyle(
                                fontSize: 16,
                                color: _IOSColors.systemBlue,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            word.definition,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 发音按钮
                    _StudyAudioButton(word: word.word),
                  ],
                ),

                const SizedBox(height: 24),

                // 操作按钮
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onExit,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: _IOSColors.systemGray2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '退出学习',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _IOSColors.systemGray,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: onNext,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: _IOSColors.systemBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_forward, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '下一题',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 发音按钮（Google 风格的 FAB 小圆按钮）
class _StudyAudioButton extends StatefulWidget {
  final String word;

  const _StudyAudioButton({required this.word});

  @override
  State<_StudyAudioButton> createState() => _StudyAudioButtonState();
}

class _StudyAudioButtonState extends State<_StudyAudioButton> {
  bool _isPlaying = false;

  Future<void> _play() async {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);

    try {
      // 先检查本地缓存
      final cachedPath =
          await DictionaryApiService.getCachedAudioPath(widget.word);
      if (cachedPath != null) {
        await DictionaryApiService.playCachedAudio(cachedPath);
      } else {
        // 尝试在线获取并缓存
        final result =
            await DictionaryApiService.fetchWord(widget.word);
        final audioUrl = result?.audioUrl;
        if (audioUrl != null) {
          final path =
              await DictionaryApiService.downloadAndCacheAudio(
                audioUrl,
                widget.word,
              );
          if (path != null) {
            await DictionaryApiService.playCachedAudio(path);
          } else {
            await TtsService().playWord(widget.word);
          }
        } else {
          // 离线 fallback
          await TtsService().playWord(widget.word);
        }
      }
    } catch (e) {
      // 出错降级到 TTS
      await TtsService().playWord(widget.word);
    }

    if (mounted) setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: _isPlaying ? null : _play,
      icon: _isPlaying
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.volume_up, size: 22),
      tooltip: '播放发音',
      style: IconButton.styleFrom(
        backgroundColor: _IOSColors.systemBlue.withValues(alpha: 0.1),
        foregroundColor: _IOSColors.systemBlue,
      ),
    );
  }
}

/// 释义详情区
class _DefinitionSection extends StatelessWidget {
  final Word word;
  final ColorScheme colorScheme;

  const _DefinitionSection({
    required this.word,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _IOSColors.systemGray6,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: _IOSColors.systemBlue,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 释义标签
          const Text(
            '释义',
            style: TextStyle(
              fontSize: 13,
              color: _IOSColors.systemGray,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            word.definition,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.6,
            ),
          ),

          // 例句
          if (word.example != null) ...[
            const SizedBox(height: 20),
            const Text(
              '例句',
              style: TextStyle(
                fontSize: 13,
                color: _IOSColors.systemGray,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.example!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                  if (word.exampleTranslation != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      word.exampleTranslation!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _IOSColors.systemGray,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 回忆质量评分条（Google 风格的 5 级评分）
class _QualityRatingBar extends StatelessWidget {
  final void Function(int quality) onSelected;

  const _QualityRatingBar({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '回忆质量如何？',
          style: TextStyle(
            fontSize: 15,
            color: _IOSColors.systemGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _RatingChip(
              label: '忘记',
              color: _IOSColors.systemRed,
              onTap: () => onSelected(1),
            ),
            const SizedBox(width: 8),
            _RatingChip(
              label: '困难',
              color: _IOSColors.systemOrange,
              onTap: () => onSelected(2),
            ),
            const SizedBox(width: 8),
            _RatingChip(
              label: '模糊',
              color: _IOSColors.systemPurple,
              onTap: () => onSelected(3),
            ),
            const SizedBox(width: 8),
            _RatingChip(
              label: '容易',
              color: _IOSColors.systemGreen,
              onTap: () => onSelected(4),
            ),
            const SizedBox(width: 8),
            _RatingChip(
              label: '简单',
              color: _IOSColors.systemBlue,
              onTap: () => onSelected(5),
            ),
          ],
        ),
      ],
    );
  }
}

class _RatingChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RatingChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}