import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/dictionary_api_service.dart';
import '../services/tts_service.dart';

class WordDetailScreen extends StatelessWidget {
  final Word word;

  const WordDetailScreen({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('单词详情'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 单词头部
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer.withValues(alpha: 0.5),
                    colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    word.word,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                  ),
                  if (word.phonetic.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      word.phonetic,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _AudioButton(word: word.word),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 释义
            if (word.definition.isNotEmpty) ...[
              _SectionTitle(title: '释义', icon: Icons.menu_book),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  word.definition,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 例句
            if (word.example != null) ...[
              _SectionTitle(title: '例句', icon: Icons.format_quote),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.example!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                    ),
                    if (word.exampleTranslation != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        word.exampleTranslation!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 词根词缀
            if (word.root != null || word.suffix != null) ...[
              _SectionTitle(title: '词根词缀', icon: Icons.account_tree),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (word.root != null)
                    _InfoChip(label: '词根', value: word.root!, color: colorScheme.primary),
                  if (word.suffix != null)
                    _InfoChip(label: '词缀', value: word.suffix!, color: colorScheme.tertiary),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // 同义词
            if (word.synonym != null) ...[
              _SectionTitle(title: '同义词', icon: Icons.sync_alt),
              const SizedBox(height: 12),
              _InfoChips(text: word.synonym!, color: Colors.green),
              const SizedBox(height: 20),
            ],

            // 反义词
            if (word.antonym != null) ...[
              _SectionTitle(title: '反义词', icon: Icons.swap_horiz),
              const SizedBox(height: 12),
              _InfoChips(text: word.antonym!, color: Colors.red),
              const SizedBox(height: 20),
            ],

            // 派生词
            if (word.derivative != null) ...[
              _SectionTitle(title: '派生词', icon: Icons.call_split),
              const SizedBox(height: 12),
              _InfoChips(text: word.derivative!, color: colorScheme.secondary),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChips extends StatelessWidget {
  final String text;
  final Color color;

  const _InfoChips({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final words = text.split(',').map((w) => w.trim()).where((w) => w.isNotEmpty).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: words
          .map((w) => Chip(
                label: Text(w),
                backgroundColor: color.withValues(alpha: 0.1),
                side: BorderSide(color: color.withValues(alpha: 0.3)),
              ))
          .toList(),
    );
  }
}

class _AudioButton extends StatefulWidget {
  final String word;

  const _AudioButton({required this.word});

  @override
  State<_AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends State<_AudioButton> {
  bool _isPlaying = false;

  Future<void> _play() async {
    setState(() => _isPlaying = true);
    try {
      final cachedPath = await DictionaryApiService.getCachedAudioPath(widget.word);
      if (cachedPath != null) {
        await DictionaryApiService.playCachedAudio(cachedPath);
      } else {
        final result = await DictionaryApiService.fetchWord(widget.word);
        final audioUrl = result?.audioUrl;
        if (audioUrl != null) {
          final path = await DictionaryApiService.downloadAndCacheAudio(
            audioUrl,
            widget.word,
          );
          if (path != null) {
            await DictionaryApiService.playCachedAudio(path);
          }
        }
      }
    } catch (e) {
      await TtsService().playWord(widget.word);
    }
    setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton.filled(
      onPressed: _isPlaying ? null : _play,
      icon: _isPlaying
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
            )
          : const Icon(Icons.volume_up),
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }
}