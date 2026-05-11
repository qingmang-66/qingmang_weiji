import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/constants.dart';

/// 学习前置选词界面：选择从哪个词开始、跳过哪些词
class PreStudyScreen extends StatefulWidget {
  final bool isReview;
  final int wordBookId;

  const PreStudyScreen({
    super.key,
    required this.isReview,
    required this.wordBookId,
  });

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
    _loadWords();
  }

  Future<void> _loadWords() async {
    _allWords = await DatabaseService.getWordsByBook(widget.wordBookId);

    // 默认全选
    _selectedIds = _allWords.map((w) => w.id!).toSet();

    // 如果是学习模式，筛掉已学过的词（只看未学的或今日新学的）
    if (!widget.isReview) {
      final todayNew = await DatabaseService.getTodayNewWordCount(widget.wordBookId);
      final unlearnedCount =
          await DatabaseService.getUnlearnedWordCount(widget.wordBookId);
      final effectiveCount = todayNew > 0 ? todayNew : unlearnedCount;

      if (effectiveCount > 0 && effectiveCount < _allWords.length) {
        final wordsToInclude =
            _allWords.take(effectiveCount).map((w) => w.id!).toSet();
        _selectedIds = wordsToInclude;
      }
    }

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

  /// 预加载的复习记录缓存（key = word.id）
  final Map<int, ReviewRecord?> _cachedRecords = {};
  final List<Future<void>> _pendingSaves = [];
  bool _recordsPreloaded = false;

  @override
  void initState() {
    super.initState();
    _words = widget.presetWords;
    _preloadRecords();
  }

  @override
  void dispose() {
    _spellController.dispose();
    super.dispose();
  }

  Future<void> _preloadRecords() async {
    final Map<int, ReviewRecord?> loaded = {};
    for (final word in _words) {
      loaded[word.id!] = await DatabaseService.getReviewRecord(word.id!);
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
    _pendingSaves.add(DatabaseService.saveReviewRecord(nextRecord));

    if (_currentIndex < _words.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    } else {
      _finishStudy();
    }
  }

  Future<void> _finishStudy() async {
    await Future.wait(_pendingSaves);
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
                // 进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / _words.length,
                    minHeight: 3,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 32),

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
      default:
        return _buildRecallMode(word, colorScheme);
    }
  }

  /// 回忆模式
  Widget _buildRecallMode(Word word, ColorScheme colorScheme) {
    return Column(
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
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                  ),
                  if (word.phonetic.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      word.phonetic,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
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
        const SizedBox(height: 32),

        if (!_showAnswer) ...[
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => setState(() => _showAnswer = true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
              foregroundColor: colorScheme.onSurface,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility, size: 20),
                SizedBox(width: 8),
                Text('显示释义'),
              ],
            ),
          ),
        ],

        if (_showAnswer) ...[
          const SizedBox(height: 8),
          _DefinitionSection(word: word, colorScheme: colorScheme),
        ],
      ],
    );
  }

  /// 拼写模式
  Widget _buildSpellMode(Word word, ColorScheme colorScheme) {
    return Column(
      children: [
        // 显示中文含义
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                word.definition.isNotEmpty ? word.definition : '请拼写单词',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                textAlign: TextAlign.center,
              ),
              if (word.example != null) ...[
                const SizedBox(height: 16),
                Text(
                  word.example!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 输入框
        if (!_showAnswer) ...[
          TextField(
            controller: _spellController,
            decoration: InputDecoration(
              hintText: '请输入英文单词',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _spellController.clear();
                },
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _checkSpell(word),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => _checkSpell(word),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('检查拼写'),
          ),
        ] else ...[
          // 显示结果
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _spellCorrect
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _spellCorrect
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _spellCorrect ? Icons.check_circle : Icons.cancel,
                  color: _spellCorrect ? Colors.green : Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _spellCorrect ? '拼写正确！' : '拼写错误',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _spellCorrect ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (!_spellCorrect) ...[
                  const SizedBox(height: 8),
                  Text(
                    '正确答案: ${word.word}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 听力模式
  Widget _buildListenMode(Word word, ColorScheme colorScheme) {
    return Column(
      children: [
        // 显示中文含义
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                word.definition.isNotEmpty ? word.definition : '请听发音',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (word.example != null) ...[
                const SizedBox(height: 16),
                Text(
                  word.example!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 40),

        // 播放按钮
        GestureDetector(
          onTap: _isPlaying ? null : () => _playAudio(word.word),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: _isPlaying
                  ? SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.volume_up,
                      size: 48,
                      color: colorScheme.primary,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isPlaying ? '正在播放...' : '点击播放发音',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 32),

        if (!_showAnswer) ...[
          FilledButton(
            onPressed: () => setState(() => _showAnswer = true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('显示答案'),
          ),
        ],
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
  }

  Future<void> _playAudio(String word) async {
    setState(() => _isPlaying = true);
    try {
      final cachedPath = await DictionaryApiService.getCachedAudioPath(word);
      if (cachedPath != null) {
        await DictionaryApiService.playCachedAudio(cachedPath);
      } else {
        final result = await DictionaryApiService.fetchWord(word);
        if (result?.audioUrl != null) {
          final path = await DictionaryApiService.downloadAndCacheAudio(
            result!.audioUrl!,
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

  /// 底部操作区
  Widget _buildBottomControls(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentIndex > 0
                        ? () => setState(() {
                              _currentIndex--;
                              _showAnswer = false;
                              _spellController.clear();
                            })
                        : null,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_left, size: 18),
                        SizedBox(width: 4),
                        Text('上一题'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentIndex < _words.length - 1
                        ? () => setState(() {
                              _currentIndex++;
                              _showAnswer = false;
                              _spellController.clear();
                            })
                        : null,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('下一题'),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (_showAnswer && widget.studyMode == 1) ...[
              const SizedBox(height: 16),
              _QualityRatingBar(onSelected: _onQualitySelected),
            ],

            // 拼写模式和听力模式显示完成按钮
            if (_showAnswer && (widget.studyMode == 2 || widget.studyMode == 3)) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _onQualitySelected(3), // 模糊
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.withValues(alpha: 0.8),
                      ),
                      child: const Text('没记住'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _onQualitySelected(4), // 容易
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('记住了'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
        if (result?.audioUrl != null) {
          final path =
              await DictionaryApiService.downloadAndCacheAudio(
                result!.audioUrl!,
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
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton.filled(
      onPressed: _isPlaying ? null : _play,
      icon: _isPlaying
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onPrimary,
              ),
            )
          : Icon(Icons.volume_up, size: 22),
      tooltip: '播放发音',
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 释义标签
        Text(
          '释义',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          word.definition,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.6,
              ),
        ),

        // 例句
        if (word.example != null) ...[
          const SizedBox(height: 20),
          Text(
            '例句',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: colorScheme.primary,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.example!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                ),
                if (word.exampleTranslation != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    word.exampleTranslation!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: colorScheme.onSurfaceVariant,
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
}

/// 回忆质量评分条（Google 风格的 5 级评分）
class _QualityRatingBar extends StatelessWidget {
  final void Function(int quality) onSelected;

  const _QualityRatingBar({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '回忆质量如何？',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _RatingChip(
              label: '忘记',
              color: Color(AppConstants.qualityColors[1]!),
              onTap: () => onSelected(1),
            ),
            const SizedBox(width: 6),
            _RatingChip(
              label: '困难',
              color: Color(AppConstants.qualityColors[2]!),
              onTap: () => onSelected(2),
            ),
            const SizedBox(width: 6),
            _RatingChip(
              label: '模糊',
              color: Color(AppConstants.qualityColors[3]!),
              onTap: () => onSelected(3),
            ),
            const SizedBox(width: 6),
            _RatingChip(
              label: '容易',
              color: Color(AppConstants.qualityColors[4]!),
              onTap: () => onSelected(4),
            ),
            const SizedBox(width: 6),
            _RatingChip(
              label: '简单',
              color: Color(AppConstants.qualityColors[5]!),
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
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
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