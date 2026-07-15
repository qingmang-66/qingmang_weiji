import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../theme/fluid_theme.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';

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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final textTertiary = FluidTheme.getTextTertiaryColor(isDark);

    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: FluidTheme.getSurfaceGradientColors(isDark),
          ),
          border: Border.all(color: FluidTheme.getBorderColor(isDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                            style: FluidTheme.headingLarge(isDark).copyWith(
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (word.phonetic.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              word.phonetic,
                              style: FluidTheme.headingSmall(isDark).copyWith(
                                color: textSecondary,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (onDictionaryQuery != null)
                              TextButton.icon(
                                onPressed: () => onDictionaryQuery!(word.word),
                                icon: const Icon(Icons.book_outlined, size: 16),
                                label: Text(context.tr.queryDict),
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      FluidTheme.primaryFluidGradient[0],
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
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
                if (showDefinition && word.definition.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          FluidTheme.primaryFluidGradient[0].withValues(
                            alpha: isDark ? 0.35 : 0.28,
                          ),
                          FluidTheme.getBorderColor(isDark),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: FluidTheme.primaryFluidGradient[0].withValues(
                        alpha: isDark ? 0.18 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      context.tr.definitionLabel,
                      style: FluidTheme.labelMedium(isDark).copyWith(
                        color: FluidTheme.primaryFluidGradient[0],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    word.definition,
                    style: FluidTheme.bodyLarge(
                      isDark,
                    ).copyWith(color: textPrimary, height: 1.5),
                  ),
                  if (word.example != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FluidTheme.getMutedOverlayColor(isDark),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: FluidTheme.getBorderColor(isDark),
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
                                color: FluidTheme.primaryFluidGradient[0]
                                    .withValues(alpha: isDark ? 0.75 : 0.85),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.tr.exampleLabel,
                                style: FluidTheme.labelMedium(isDark).copyWith(
                                  color: FluidTheme.primaryFluidGradient[0],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            word.example!,
                            style: FluidTheme.bodyMedium(isDark).copyWith(
                              fontStyle: FontStyle.italic,
                              color: textPrimary,
                              height: 1.5,
                            ),
                          ),
                          if (word.exampleTranslation != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              word.exampleTranslation!,
                              style: FluidTheme.bodySmall(
                                isDark,
                              ).copyWith(color: textTertiary, height: 1.4),
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

class _AudioButtonState extends State<_AudioButton>
    with SingleTickerProviderStateMixin {
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
    if (PlatformAdapt.isMobile) {
      HapticFeedback.selectionClick();
    }
    setState(() => _isPlaying = true);
    _animController.forward();

    try {
      final cachedPath = await DictionaryApiService.getCachedAudioPath(
        widget.word,
      );
      if (!mounted) return;
      if (cachedPath != null) {
        await DictionaryApiService.playCachedAudio(cachedPath);
        if (!mounted) return;
        setState(() => _isPlaying = false);
        _animController.reverse();
        return;
      }

      final result = await DictionaryApiService.fetchWord(widget.word);
      if (!mounted) return;
      final audioUrl = result?.audioUrl;
      if (audioUrl != null) {
        final path = await DictionaryApiService.downloadAndCacheAudio(
          audioUrl,
          widget.word,
        );
        if (!mounted) return;
        if (path != null) {
          await DictionaryApiService.playCachedAudio(path);
          if (!mounted) return;
          setState(() => _isPlaying = false);
          _animController.reverse();
          return;
        }
      }

      await TtsService().playWord(widget.word);
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      await TtsService().playWord(widget.word);
      if (!mounted) return;
    }

    setState(() => _isPlaying = false);
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final accentColor = FluidTheme.primaryFluidGradient[0];

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.28 : 0.2),
          ),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: _isPlaying
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accentColor,
                  ),
                )
              : Icon(Icons.volume_up_rounded, color: accentColor),
          onPressed: _isPlaying ? null : _play,
          tooltip: context.tr.playPronunciation,
        ),
      ),
    );
  }
}
