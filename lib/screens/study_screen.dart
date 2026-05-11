import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../widgets/word_card.dart';
import '../widgets/dictionary_dialog.dart';
import '../utils/constants.dart';

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
    List<Word> words;
    if (widget.isReview) {
      words = await DatabaseService.getDueWords(widget.wordBookId);
    } else {
      final dailyLimit = Provider.of<AppProvider>(context, listen: false).dailyNewWords;
      words = await DatabaseService.getNewWords(widget.wordBookId, dailyLimit);
    }

    final Map<int, ReviewRecord?> records = {};
    for (final w in words) {
      records[w.id!] = await DatabaseService.getReviewRecord(w.id!);
    }

    // 如果启用了在线释义，异步补充释义（但不阻塞显示）
    if (mounted) {
      final provider = Provider.of<AppProvider>(context, listen: false);
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
    _pendingSaves.add(DatabaseService.saveReviewRecord(nextRecord));

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

  /// 确保当前单词有有效释义
  /// 如果释义为空或占位符，且启用了在线释义，则异步获取并更新
  Future<void> _ensureCurrentWordDefinition() async {
    final word = _words[_currentIndex];
    final definition = word.definition.trim();
    final hasValidDef = definition.isNotEmpty &&
        !definition.contains('释义待补充') &&
        !definition.contains('[释义');

    if (!hasValidDef) {
      final provider = Provider.of<AppProvider>(context, listen: false);
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
      final provider = Provider.of<AppProvider>(context, listen: false);
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
    final provider = Provider.of<AppProvider>(context, listen: false);
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
        // 优化的进度条
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (_currentIndex + 1) / _words.length),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return LinearProgressIndicator(
              value: value,
              backgroundColor: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
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
                      if (velocity > 0) {
                        _onQualitySelected(4); // 右滑=容易
                      } else {
                        _onQualitySelected(2); // 左滑=困难
                      }
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

                    // 单词卡片
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

                      // 显示答案按钮 - 优化样式
                      if (!_showAnswer)
                        FilledButton.icon(
                          onPressed: () async {
                            // 如果启用了在线释义且当前释义缺失，先获取释义
                            final provider = Provider.of<AppProvider>(context, listen: false);
                            if (provider.useOnlineDefinition) {
                              final word = _words[_currentIndex];
                              final definition = word.definition.trim();
                              final hasValidDef = definition.isNotEmpty &&
                                  !definition.contains('释义待补充') &&
                                  !definition.contains('[释义');
                            if (!hasValidDef) {
                              // 显示加载提示
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
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('显示释义'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 评分按钮区域 - 优化的底部面板
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 滑动提示
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
              _buildQualityPanel(colorScheme),
            ],
          ),
          crossFadeState: _showAnswer ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }

  Widget _buildQualityPanel(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动条提示
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '回忆质量如何？',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isReview ? '根据本次复习的记忆程度选择' : '根据本次学习的记忆程度选择',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _QualityButton(
                  label: '忘记',
                  color: Color(AppConstants.qualityColors[1]!),
                  onTap: () => _onQualitySelected(1),
                ),
                const SizedBox(width: 6),
                _QualityButton(
                  label: '困难',
                  color: Color(AppConstants.qualityColors[2]!),
                  onTap: () => _onQualitySelected(2),
                ),
                const SizedBox(width: 6),
                _QualityButton(
                  label: '模糊',
                  color: Color(AppConstants.qualityColors[3]!),
                  onTap: () => _onQualitySelected(3),
                ),
                const SizedBox(width: 6),
                _QualityButton(
                  label: '容易',
                  color: Color(AppConstants.qualityColors[4]!),
                  onTap: () => _onQualitySelected(4),
                ),
                const SizedBox(width: 6),
                _QualityButton(
                  label: '简单',
                  color: Color(AppConstants.qualityColors[5]!),
                  onTap: () => _onQualitySelected(5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QualityButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QualityButton> createState() => _QualityButtonState();
}

class _QualityButtonState extends State<_QualityButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ElevatedButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            _controller.forward().then((_) {
              _controller.reverse();
              widget.onTap();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color.withValues(alpha: 0.15),
            foregroundColor: widget.color,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
