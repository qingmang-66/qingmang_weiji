import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/app_initialization_service.dart';
import '../services/di_container.dart';
import '../services/dictionary_api_service.dart';
import '../services/providers/providers.dart';
import '../services/tts_service.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import '../widgets/dictionary_dialog.dart';
import '../widgets/fluid_card.dart';
import '../widgets/liquid_glass.dart';

class WordDetailScreen extends StatefulWidget {
  final Word word;

  /// 收藏来源标签：从词库页进来算「学习」，从搜索链路进来算「首页搜索」。
  /// 只影响收藏夹里的来源标签，不参与任何去重逻辑。
  final FavoriteSource favoriteSource;

  const WordDetailScreen({
    super.key,
    required this.word,
    this.favoriteSource = FavoriteSource.study,
  });

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  Word get word => widget.word;

  /// 当前词的收藏状态（与学习页、阅读器、收藏夹共用同一份数据）
  bool _isFavorite = false;

  /// 收藏请求进行中，避免连点产生重复写入
  bool _favoriteBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFavoriteState());
  }

  Future<void> _loadFavoriteState() async {
    final wordId = word.id;
    if (wordId == null) return;
    try {
      final favorite = await DIContainer.instance.favoriteService.isFavorite(
        wordId,
      );
      if (!mounted) return;
      setState(() => _isFavorite = favorite);
    } catch (e) {
      debugPrint('读取收藏状态失败：$e');
    }
  }

  /// 顶栏星标：收藏 / 取消收藏当前单词。
  ///
  /// 收藏是单词级、跨词库全局唯一的，所以这里切完，收藏夹、学习页、
  /// 阅读器会同步看到同一条记录。
  Future<void> _toggleFavorite() async {
    final wordId = word.id;
    if (wordId == null || _favoriteBusy) return;
    setState(() => _favoriteBusy = true);
    try {
      final nowFavorite = await DIContainer.instance.favoriteService.toggleWord(
        wordId,
        source: widget.favoriteSource,
      );
      if (!mounted) return;
      setState(() {
        _isFavorite = nowFavorite;
        _favoriteBusy = false;
      });
      AppInitializationService.notifyDatabaseRefreshed();
      ErrorHandler.showSuccess(
        context,
        nowFavorite ? context.tr.favoriteAdded : context.tr.favoriteRemoved,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _favoriteBusy = false);
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: context.tr.operationFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final isGlass = context.isLiquidGlass;
    //单词主卡内容：玻璃模式与经典模式共用
    final wordHeroContent = Column(
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
              //音标用主色在浅色玻璃上仅 1.91:1，改用可读版主色
              color: FluidTheme.primaryAccessible(isDark),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _AudioButton(word: word.word),
      ],
    );

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
            //本页展示的是词书里存下来的词条信息；想深挖音标/双语例句，
            //从这里直接接上词典（本地词典 + 在线补全）
            IconButton(
              icon: Icon(Icons.menu_book_outlined, color: textPrimary),
              tooltip: context.tr.lookupDictionary,
              onPressed: () =>
                  showDictionaryLookupDialog(context: context, word: word.word),
            ),
            //收藏：与学习页、阅读器写同一张表，收藏夹里立刻能看到
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.star : Icons.star_border,
                color: _isFavorite ? FluidTheme.favorite : textPrimary,
              ),
              tooltip: _isFavorite
                  ? context.tr.removeFromFavorites
                  : context.tr.addToFavorites,
              onPressed: word.id == null || _favoriteBusy
                  ? null
                  : _toggleFavorite,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //玻璃模式单词主卡换玻璃容器，经典模式保留渐变描边卡
              if (isGlass)
                GlassSurface(
                  width: double.infinity,
                  borderRadius: 20,
                  padding: const EdgeInsets.all(24),
                  child: wordHeroContent,
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.12),
                        isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.white.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.28),
                    ),
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
                  child: wordHeroContent,
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
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
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
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);

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
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
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
      //只播已缓存的真人音：未缓存时不再串行等 dictionaryapi.dev → gstatic
      //两段网络（大陆网络基本不可达，点一次要等十几秒甚至超时没声），
      //直接走学习页同款快路径（有道在线/本地TTS+回退），并后台预热缓存
      final cachedPath = await DictionaryApiService.getCachedAudioPath(
        widget.word,
      );
      var played = false;
      if (cachedPath != null) {
        played = await DictionaryApiService.playCachedAudio(cachedPath);
      } else {
        DictionaryApiService.prefetchAudio(widget.word);
      }
      if (!played) await TtsService().playWord(widget.word);
    } catch (e) {
      await TtsService().playWord(widget.word);
    }

    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final accent = FluidTheme.primaryFluidGradient[0];
    //玻璃模式用强调玻璃承托发音按钮，经典模式保留渐变方块
    final icon = _isPlaying
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.isLiquidGlass ? accent : Colors.white,
            ),
          )
        : Icon(
            Icons.volume_up,
            color: context.isLiquidGlass
                ? FluidTheme.getTextPrimaryColor(isDark)
                : Colors.white,
          );
    if (context.isLiquidGlass) {
      return GlassSurface(
        borderRadius: 18,
        emphasized: true,
        glowColor: accent,
        child: IconButton(onPressed: _isPlaying ? null : _play, icon: icon),
      );
    }
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
      child: IconButton(onPressed: _isPlaying ? null : _play, icon: icon),
    );
  }
}
