import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../theme/fluid_theme.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import 'liquid_glass.dart';

/// 单词记忆卡片：液态玻璃风格与经典流体风格双适配
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
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final isGlass = context.select<ThemeProvider, bool>((p) => p.isLiquidGlass);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final textTertiary = FluidTheme.getTextTertiaryColor(isDark);
    final accent = FluidTheme.primaryFluidGradient[0];

    final cardContent = Padding(
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
                    ],
                    // 查词典入口不再依赖音标：此前嵌在 phonetic 非空分支里，
                    // 无音标的词条整个入口消失（词典本身不依赖音标查询）
                    if (onDictionaryQuery != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => onDictionaryQuery!(word.word),
                        icon: const Icon(Icons.book_outlined, size: 16),
                        label: Text(context.tr.queryDict),
                        style: TextButton.styleFrom(
                          foregroundColor: accent,
                          // 桌面端靠鼠标，压扁成"文字链接"的样子更贴合设计；
                          // 移动端手指点不准，保留最小命中区（Material 规定 48dp）
                          padding: PlatformAdapt.isMobile
                              ? const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                )
                              : EdgeInsets.zero,
                          minimumSize: PlatformAdapt.isMobile
                              ? const Size(48, 40)
                              : Size.zero,
                          tapTargetSize: PlatformAdapt.isMobile
                              ? MaterialTapTargetSize.padded
                              : MaterialTapTargetSize.shrinkWrap,
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
                  colors: isGlass
                      ? [
                          Colors.white.withValues(alpha: isDark ? 0.5 : 0.85),
                          Colors.white.withValues(alpha: 0),
                        ]
                      : [
                          accent.withValues(alpha: isDark ? 0.35 : 0.28),
                          FluidTheme.getBorderColor(isDark),
                        ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isGlass)
              GlowCapsule(
                color: accent,
                child: Text(
                  context.tr.definitionLabel,
                  style: FluidTheme.labelMedium(isDark).copyWith(
                    //胶囊底在浅色下接近白色，主色字几乎不可读，改用可读版主色
                    color: FluidTheme.primaryAccessible(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  context.tr.definitionLabel,
                  style: FluidTheme.labelMedium(
                    isDark,
                  ).copyWith(color: accent, fontWeight: FontWeight.w600),
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
              if (isGlass)
                GlassSurface(
                  borderRadius: 14,
                  child: _exampleBody(
                    context,
                    isDark,
                    textPrimary,
                    textTertiary,
                    accent,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FluidTheme.getMutedOverlayColor(isDark),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: FluidTheme.getBorderColor(isDark),
                    ),
                  ),
                  child: _exampleBody(
                    context,
                    isDark,
                    textPrimary,
                    textTertiary,
                    accent,
                  ),
                ),
            ],
          ],
        ],
      ),
    );

    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: isGlass
          ? GlassSurface(
              borderRadius: 24,
              emphasized: true,
              grain: true,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(24),
                child: cardContent,
              ),
            )
          : Container(
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
                child: cardContent,
              ),
            ),
    );
  }

  Widget _exampleBody(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color textTertiary,
    Color accent,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote,
                size: 16,
                color: accent.withValues(alpha: isDark ? 0.75 : 0.85),
              ),
              const SizedBox(width: 4),
              Text(
                context.tr.exampleLabel,
                style: FluidTheme.labelMedium(
                  isDark,
                ).copyWith(color: accent, fontWeight: FontWeight.w600),
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
    );
  }
}

/// 发音按钮：玻璃模式为液态圆钮，经典模式为描边圆钮
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
        final played = await DictionaryApiService.playCachedAudio(cachedPath);
        if (!mounted) return;
        if (played) {
          setState(() => _isPlaying = false);
          _animController.reverse();
          return;
        }
        //播放失败则继续往下走 TTS 兜底（不再静默返回导致"点了没反应"）
      } else {
        //未缓存时不再串行等 dictionaryapi.dev → gstatic 两段网络
        //（大陆网络基本不可达，点一次要等十几秒甚至超时没声），
        //直接走学习页同款快路径，后台预热真人音缓存
        DictionaryApiService.prefetchAudio(widget.word);
      }

      await TtsService().playWord(widget.word);
      if (!mounted) return;
    } catch (_) {
      //playWord 内部已重试 3 次，失败会经 errorStream 由 TtsErrorHandler 提示，
      //这里再调一次会让单次点击变成「3 次重试 × 2 轮」，最坏要等数十秒
      if (!mounted) return;
    }

    setState(() => _isPlaying = false);
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final isGlass = context.select<ThemeProvider, bool>((p) => p.isLiquidGlass);
    final accentColor = FluidTheme.primaryFluidGradient[0];

    final icon = _isPlaying
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: accentColor,
            ),
          )
        : Icon(Icons.volume_up_rounded, color: accentColor);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: isGlass
            ? GlassSurface(
                width: 46,
                height: 46,
                borderRadius: 23,
                emphasized: true,
                tint: LiquidGlass.accentTint(accentColor, isDark),
                glowColor: accentColor,
                child: Center(child: icon),
              )
            : Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  border: Border.all(
                    color: accentColor.withValues(alpha: isDark ? 0.28 : 0.2),
                  ),
                  shape: BoxShape.circle,
                ),
                child: icon,
              ),
        onPressed: _isPlaying ? null : _play,
        tooltip: context.tr.playPronunciation,
      ),
    );
  }
}
