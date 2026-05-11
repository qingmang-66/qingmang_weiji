import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

/// 单词卡片组件 - 谷歌风格优化版
class WordCard extends StatelessWidget {
  final Word word;
  final VoidCallback? onTap;
  final bool showDefinition;
  final Function(String)? onDictionaryQuery;

  const WordCard({
    super.key,
    required this.word,
    this.onTap,
    this.showDefinition = false,
    this.onDictionaryQuery,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 单词主体 - 更突出
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 单词 - 放大加粗
                        Text(
                          word.word,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                        ),
                        if (word.phonetic.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          // 音标 - 斜体淡色
                          Text(
                            word.phonetic,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                          const SizedBox(height: 8),
                          // 词典查询按钮
                          if (onDictionaryQuery != null)
                            TextButton.icon(
                              onPressed: () => onDictionaryQuery!(word.word),
                              icon: Icon(Icons.book_outlined, size: 16),
                              label: Text('查词典'),
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.primary,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AudioButton(word: word.word),
                ],
              ),

              // 释义区域 - 渐显动画
              if (showDefinition && word.definition.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.3),
                        colorScheme.outlineVariant.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 释义标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '释义',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                // 释义内容
                Text(
                  word.definition,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                        height: 1.5,
                      ),
                ),

                // 例句区域
                if (word.example != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.format_quote,
                              size: 16,
                              color: colorScheme.primary.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '例句',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          word.example!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: colorScheme.onSurface,
                                height: 1.5,
                              ),
                        ),
                        if (word.exampleTranslation != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            word.exampleTranslation!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 发音按钮 - 优化的圆形按钮
class _AudioButton extends StatefulWidget {
  final String word;

  const _AudioButton({required this.word});

  @override
  State<_AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends State<_AudioButton> with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    setState(() => _isPlaying = true);
    _animController.forward();

    try {
      final cachedPath = await DictionaryApiService.getCachedAudioPath(widget.word);
      if (cachedPath != null) {
        await DictionaryApiService.playCachedAudio(cachedPath);
        setState(() => _isPlaying = false);
        _animController.reverse();
        return;
      }

      final result = await DictionaryApiService.fetchWord(widget.word);
      if (result?.audioUrl != null) {
        final path = await DictionaryApiService.downloadAndCacheAudio(
          result!.audioUrl!,
          widget.word,
        );
        if (path != null) {
          await DictionaryApiService.playCachedAudio(path);
          setState(() => _isPlaying = false);
          _animController.reverse();
          return;
        }
      }

      await TtsService().playWord(widget.word);
    } catch (e) {
      await TtsService().playWord(widget.word);
    }

    setState(() => _isPlaying = false);
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: _isPlaying
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                )
              : Icon(
                  Icons.volume_up_rounded,
                  color: colorScheme.primary,
                ),
          onPressed: _isPlaying ? null : _play,
          tooltip: '播放发音',
        ),
      ),
    );
  }
}
