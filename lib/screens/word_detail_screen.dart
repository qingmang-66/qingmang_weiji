import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/dictionary_api_service.dart';
import '../services/providers/providers.dart';
import '../services/tts_service.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../widgets/favorite_sheet.dart';
import '../widgets/fluid_card.dart';
import '../widgets/fluid_dialog.dart';
import '../widgets/word_set_picker_sheet.dart';

class WordDetailScreen extends StatefulWidget {
  final Word word;

  const WordDetailScreen({super.key, required this.word});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;

  Word get word => widget.word;

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    final wordId = word.id;
    if (wordId == null) return;
    final isFavorite = await DIContainer.instance.favoriteRepository.isFavorite(
      wordId,
    );
    if (!mounted) return;
    setState(() {
      _isFavorite = isFavorite;
      _isLoadingFavorite = false;
    });
  }

  Future<void> _toggleFavorite() async {
    final wordId = word.id;
    if (wordId == null) return;
    final repo = DIContainer.instance.favoriteRepository;
    if (_isFavorite) {
      // 已收藏：弹出居中菜单（编辑 / 取消收藏）
      final action = await showFluidDialog<_DetailFavAction>(
        context: context,
        title: context.tr.favoriteActionTitle,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(context.tr.editFavorite),
              onTap: () => Navigator.pop(context, _DetailFavAction.edit),
            ),
            ListTile(
              leading: Icon(Icons.bookmark_remove, color: FluidTheme.error),
              title: Text(context.tr.removeFromFavorites),
              onTap: () => Navigator.pop(context, _DetailFavAction.remove),
            ),
          ],
        ),
      );
      if (!mounted || action == null) return;
      if (action == _DetailFavAction.edit) {
        final result = await showFavoriteSheet(
          context,
          wordId: wordId,
          edit: true,
        );
        if (result == null || !mounted) return;
        try {
          await repo.updateGroup(wordId, result.groupName);
          if (result.note != null) {
            await repo.updateNote(wordId, result.note);
          } else {
            await repo.updateNote(wordId, null);
          }
          if (!mounted) return;
          ErrorHandler.showSuccess(context, context.tr.favoriteUpdated);
        } catch (e) {
          if (!mounted) return;
          ErrorHandler.handleException(context, e, fallbackMessage: '更新收藏失败');
        }
      } else {
        // 取消收藏
        try {
          await repo.removeFavorite(wordId);
          if (!mounted) return;
          setState(() => _isFavorite = false);
          ErrorHandler.showSuccess(context, context.tr.removedFromFavorites);
        } catch (e) {
          if (!mounted) return;
          ErrorHandler.handleException(context, e, fallbackMessage: '取消收藏失败');
        }
      }
    } else {
      // 未收藏：弹 sheet 选分组 + 备注
      final result = await showFavoriteSheet(context, wordId: wordId);
      if (result == null || !mounted) return;
      try {
        await repo.addFavorite(
          wordId: wordId,
          groupName: result.groupName,
          note: result.note,
        );
        if (!mounted) return;
        setState(() => _isFavorite = true);
        ErrorHandler.showSuccess(context, context.tr.addedToFavorites);
      } catch (e) {
        if (!mounted) return;
        ErrorHandler.handleException(context, e, fallbackMessage: '收藏失败');
      }
    }
  }

  Future<void> _addToCustomSet() async {
    final wordId = word.id;
    if (wordId == null) return;
    // 阶段三：复用通用组件
    await showWordSetPickerSheet(context, wordId: wordId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return FluidPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textPrimary),
          title: Text(
            context.tr.wordDetailTitle,
            style: FluidTheme.headingMedium(
              isDark,
            ).copyWith(color: textPrimary),
          ),
          actions: [
            IconButton(
              tooltip: _isFavorite
                  ? context.tr.removeFromFavorites
                  : context.tr.addToFavorites,
              icon: Icon(
                _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                color: _isLoadingFavorite
                    ? textSecondary
                    : FluidTheme.primaryFluidGradient[0],
              ),
              onPressed: _isLoadingFavorite ? null : _toggleFavorite,
            ),
            IconButton(
              tooltip: context.tr.addToSet,
              icon: Icon(Icons.playlist_add, color: textPrimary),
              onPressed: _addToCustomSet,
            ),
          ],
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
                      style: FluidTheme.headingLarge(isDark).copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (word.phonetic.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        word.phonetic,
                        style: FluidTheme.headingSmall(isDark).copyWith(
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
                _SectionTitle(
                  title: context.tr.definitionSection,
                  icon: Icons.menu_book,
                ),
                const SizedBox(height: 12),
                _DetailBlock(
                  child: Text(
                    word.definition,
                    style: FluidTheme.bodyMedium(
                      isDark,
                    ).copyWith(color: textPrimary, height: 1.6),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (word.example != null) ...[
                _SectionTitle(
                  title: context.tr.exampleSection,
                  icon: Icons.format_quote,
                ),
                const SizedBox(height: 12),
                _DetailBlock(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word.example!,
                        style: FluidTheme.bodyMedium(isDark).copyWith(
                          color: textPrimary,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                      if (word.exampleTranslation != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          word.exampleTranslation!,
                          style: FluidTheme.bodyMedium(
                            isDark,
                          ).copyWith(color: textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (word.root != null || word.suffix != null) ...[
                _SectionTitle(
                  title: context.tr.rootAffixSection,
                  icon: Icons.account_tree,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (word.root != null)
                      _InfoChip(
                        label: context.tr.rootLabel,
                        value: word.root!,
                        color: FluidTheme.primaryFluidGradient[0],
                      ),
                    if (word.suffix != null)
                      _InfoChip(
                        label: context.tr.affixLabel,
                        value: word.suffix!,
                        color: FluidTheme.secondaryFluidGradient[0],
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              if (word.synonym != null) ...[
                _SectionTitle(
                  title: context.tr.synonymSection,
                  icon: Icons.sync_alt,
                ),
                const SizedBox(height: 12),
                _InfoChips(text: word.synonym!, color: FluidTheme.success),
                const SizedBox(height: 20),
              ],
              if (word.antonym != null) ...[
                _SectionTitle(
                  title: context.tr.antonymSection,
                  icon: Icons.swap_horiz,
                ),
                const SizedBox(height: 12),
                _InfoChips(text: word.antonym!, color: FluidTheme.error),
                const SizedBox(height: 20),
              ],
              if (word.derivative != null) ...[
                _SectionTitle(
                  title: context.tr.derivativeSection,
                  icon: Icons.call_split,
                ),
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return Row(
      children: [
        Icon(icon, size: 20, color: FluidTheme.primaryFluidGradient[0]),
        const SizedBox(width: 8),
        Text(
          title,
          style: FluidTheme.labelLarge(isDark).copyWith(
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

/// 收藏按钮弹出菜单动作
enum _DetailFavAction { edit, remove }
