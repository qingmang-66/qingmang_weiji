import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/providers/providers.dart';
import '../services/di_container.dart';
import '../services/review_scheduler.dart';
import '../services/definition_service.dart';
import '../services/wrong_word_service.dart';
import '../services/tts_service.dart';
import '../widgets/study_components.dart';
import '../widgets/dictionary_dialog.dart';

/// 学习/复习页面 - 优化的动效和体验
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

class _StudyScreenState extends State<StudyScreen> with TickerProviderStateMixin {
  List<Word> _words = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isLoading = true;

  late AnimationController _cardAnimController;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;

  final Map<int, ReviewRecord?> _cachedRecords = {};
  final List<Future<void>> _pendingSaves = [];

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
      words = await wordRepository.getDueWords(widget.wordBookId);
    } else {
      final dailyLimit = Provider.of<StudySettingsProvider>(context, listen: false).dailyNewWords;
      words = await wordRepository.getNewWords(widget.wordBookId, dailyLimit);
    }

    final Map<int, ReviewRecord?> records = {};
    for (final w in words) {
      records[w.id!] = await reviewRepository.getReviewRecord(w.id!);
    }

    // 如果启用了在线释义，异步补充释义（但不阻塞显示）
    if (mounted) {
      final provider = Provider.of<StudySettingsProvider>(context, listen: false);
      if (provider.useOnlineDefinition) {
        // 限制预加载数量，避免卡顿
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

  void _onQualitySelected(int quality) {
    final word = _words[_currentIndex];

    final record = _cachedRecords.containsKey(word.id!)
        ? (_cachedRecords[word.id!] ?? ReviewScheduler.createInitialRecord(word.id!))
        : ReviewScheduler.createInitialRecord(word.id!);

    final nextRecord = ReviewScheduler.scheduleNextReview(record, quality);
    _cachedRecords[word.id!] = nextRecord;
    _pendingSaves.add(context.read<DIContainer>().reviewRepository.saveReviewRecord(nextRecord));

    // 如果质量低于 3（忘记/模糊），加入错词本
    if (quality < 3 && word.id != null) {
      _pendingSaves.add(_addToWrongWords(word.id!));
    }

    if (_currentIndex < _words.length - 1) {
      _cardAnimController.reset();
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
      // 翻页后预加载下个单词的释义（后台静默）
      _preloadNextWordDefinition();
      _cardAnimController.forward();
      // 切换到新单词时自动发音
      _playCurrentWord();
    } else {
      _finishStudy();
    }
  }

  /// 添加到错词本
  Future<void> _addToWrongWords(int wordId) async {
    try {
      final service = WrongWordService();
      await service.init();
      await service.addWrongWord(wordId);
    } catch (e) {
      // 添加失败则忽略，不影响学习流程
      debugPrint('添加错词失败：$e');
    }
  }

  /// 播放当前单词发音
  void _playCurrentWord() {
    if (_words.isEmpty || _currentIndex >= _words.length) return;
    
    final word = _words[_currentIndex];
    final ttsService = Provider.of<TtsService>(context, listen: false);
    ttsService.playWord(word.word);
  }

  /// 确保当前单词有有效释义
  /// 如果释义为空或占位符，且启用了在线释义，则异步获取并更新
  Future<void> _ensureCurrentWordDefinition() async {
    final word = _words[_currentIndex];
    final definition = word.definition.trim();
    final hasValidDef = definition.isNotEmpty &&
        !definition.contains('释义待补充') &&
        !definition.contains('[释义');

    if (!hasValidDef) {
      final provider = Provider.of<StudySettingsProvider>(context, listen: false);
      if (provider.useOnlineDefinition) {
        final updated = await DefinitionService.getWordWithDefinition(word);
        // 更新列表中的单词（如果发生了更新）
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

  /// 预加载下个单词的释义（后台静默进行）
  Future<void> _preloadNextWordDefinition() async {
    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _words.length) return;

    final nextWord = _words[nextIndex];
    final definition = nextWord.definition.trim();
    final hasValidDef = definition.isNotEmpty &&
        !definition.contains('释义待补充') &&
        !definition.contains('[释义');

    if (!hasValidDef) {
      final provider = Provider.of<StudySettingsProvider>(context, listen: false);
      if (provider.useOnlineDefinition) {
        // 静默获取，不更新 UI
        await DefinitionService.getWordWithDefinition(nextWord);
      }
    }
  }

  Future<void> _finishStudy() async {
    await Future.wait(_pendingSaves);
    // 更新打卡
    if (!mounted) return;
    final provider = Provider.of<StudySettingsProvider>(context, listen: false);
    await provider.updateStreak();
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: Icon(
                widget.isReview ? Icons.celebration : Icons.school,
                size: 56,
                color: Theme.of(ctx).colorScheme.primary,
              ),
            ),
          ),
          title: Text(widget.isReview ? '复习完成！' : '学习完成！'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('今天${widget.isReview ? '复习' : '学习'}了 ${_words.length} 个单词'),
              const SizedBox(height: 8),
              if (provider.streak > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text(
                      '已连续学习 ${provider.streak} 天',
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                )
              else
                Text(
                  '继续保持，每天进步一点点',
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
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${_words.length}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? _buildEmptyState(colorScheme)
              : _buildStudyCard(colorScheme),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.isReview ? '没有待复习的单词！' : '没有新单词了！',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '太棒了，继续保持！',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyCard(ColorScheme colorScheme) {
    final word = _words[_currentIndex];

    return Column(
      children: [
        StudyCard(
          word: word,
          currentIndex: _currentIndex,
          totalWords: _words.length,
          showAnswer: _showAnswer,
          animController: _cardAnimController,
          slideAnimation: _cardSlideAnimation,
          fadeAnimation: _cardFadeAnimation,
          onShowAnswer: () async {
            final provider = Provider.of<StudySettingsProvider>(context, listen: false);
            if (provider.useOnlineDefinition) {
              final word = _words[_currentIndex];
              final definition = word.definition.trim();
              final hasValidDef = definition.isNotEmpty &&
                  !definition.contains('释义待补充') &&
                  !definition.contains('[释义');
              if (!hasValidDef) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('正在获取释义...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                await _ensureCurrentWordDefinition();
              }
            }
            if (mounted) {
              setState(() => _showAnswer = true);
            }
          },
          onDictionaryQuery: (wordText) {
            showDialog(
              context: context,
              builder: (ctx) => DictionaryDialog(word: wordText),
            );
          },
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
                    Icon(Icons.swipe_left, size: 14, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      '左滑困难 · 右滑容易',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.swipe_right, size: 14, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  ],
                ),
              ),
              if (_showAnswer) QualityPanel(
                isReview: widget.isReview,
                onQualitySelected: _onQualitySelected,
              ),
            ],
          ),
          crossFadeState: _showAnswer ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }
}
