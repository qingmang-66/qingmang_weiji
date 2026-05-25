import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/dictionary_api_service.dart';
import '../services/providers/providers.dart';
import '../services/tts_service.dart';
import '../theme/fluid_theme.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_card.dart';

class WordDetailScreen extends StatelessWidget {
  final Word word;

  const WordDetailScreen({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return FluidBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textPrimary),
          title: Text(
            '单词详情',
            style: FluidTheme.headingMedium.copyWith(color: textPrimary),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: FluidTheme.getSurfaceGradientColors(isDark),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FluidTheme.getBorderColor(isDark)),
                  boxShadow: [
                    BoxShadow(
                      color: FluidTheme.primaryFluidGradient[0].withValues(
                        alpha: isDark ? 0.14 : 0.08,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      word.word,
                      textAlign: TextAlign.center,
                      style: FluidTheme.headingLarge.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (word.phonetic.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        word.phonetic,
                        style: FluidTheme.headingSmall.copyWith(
                          color: FluidTheme.primaryFluidGradient[0],
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
              if (word.definition.isNotEmpty) ...[
                const _SectionTitle(title: '释义', icon: Icons.menu_book),
                const SizedBox(height: 12),
                _DetailBlock(
                  child: Text(
                    word.definition,
                    style: FluidTheme.bodyMedium.copyWith(
                      color: textPrimary,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (word.example != null) ...[
                const _SectionTitle(title: '例句', icon: Icons.format_quote),
                const SizedBox(height: 12),
                _DetailBlock(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word.example!,
                        style: FluidTheme.bodyMedium.copyWith(
                          color: textPrimary,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                      if (word.exampleTranslation != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          word.exampleTranslation!,
                          style: FluidTheme.bodyMedium.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (word.root != null || word.suffix != null) ...[
                const _SectionTitle(title: '词根词缀', icon: Icons.account_tree),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (word.root != null)
                      _InfoChip(
                        label: '词根',
                        value: word.root!,
                        color: FluidTheme.primaryFluidGradient[0],
                      ),
                    if (word.suffix != null)
                      _InfoChip(
                        label: '词缀',
                        value: word.suffix!,
                        color: FluidTheme.secondaryFluidGradient[0],
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              if (word.synonym != null) ...[
                const _SectionTitle(title: '同义词', icon: Icons.sync_alt),
                const SizedBox(height: 12),
                _InfoChips(text: word.synonym!, color: FluidTheme.success),
                const SizedBox(height: 20),
              ],
              if (word.antonym != null) ...[
                const _SectionTitle(title: '反义词', icon: Icons.swap_horiz),
                const SizedBox(height: 12),
                _InfoChips(text: word.antonym!, color: FluidTheme.error),
                const SizedBox(height: 20),
              ],
              if (word.derivative != null) ...[
                const _SectionTitle(title: '派生词', icon: Icons.call_split),
                const SizedBox(height: 12),
                _InfoChips(
                  text: word.derivative!,
                  color: FluidTheme.warningFluidGradient[0],
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final Widget child;

  const _DetailBlock({required this.child});

  @override
  Widget build(BuildContext context) {
    return FluidCard(
      enableShimmer: false,
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: FluidTheme.primaryFluidGradient[0]),
        const SizedBox(width: 8),
        Text(
          title,
          style: FluidTheme.labelLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: FluidTheme.primaryFluidGradient[0],
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

  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.30 : 0.22),
        ),
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
            child: Text(value, style: TextStyle(color: color, fontSize: 13)),
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final words = text
        .split(',')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: words
          .map(
            (w) => Chip(
              label: Text(
                w,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              backgroundColor: color.withValues(alpha: isDark ? 0.16 : 0.10),
              side: BorderSide(
                color: color.withValues(alpha: isDark ? 0.30 : 0.22),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
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
      final cachedPath = await DictionaryApiService.getCachedAudioPath(
        widget.word,
      );
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

    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: FluidTheme.primaryFluidGradient),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: FluidTheme.primaryFluidGradient[0].withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        onPressed: _isPlaying ? null : _play,
        icon: _isPlaying
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.volume_up, color: Colors.white),
      ),
    );
  }
}
