import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/definition_service.dart';
import '../services/dictionary_api_service.dart';
import '../services/providers/theme_provider.dart';
import '../services/tts_service.dart';
import '../theme/fluid_theme.dart';
import '../utils/platform_adapt.dart';
import '../utils/translations.dart';
import 'fluid_button.dart';
import 'fluid_dialog.dart';
import 'liquid_glass.dart';

/// 词典查询弹窗
/// 深度适配 FluidTheme 与 LiquidGlass 风格
class DictionaryDialog extends StatefulWidget {
  final String word;
  final DictionaryQueryResult? preset;
  final bool lookupFull;

  const DictionaryDialog({
    super.key,
    required this.word,
    this.preset,
    this.lookupFull = true,
  });

  @override
  State<DictionaryDialog> createState() => _DictionaryDialogState();
}

class _DictionaryDialogState extends State<DictionaryDialog> {
  String? _definition;
  String? _phonetic;
  String? _example;
  String? _exampleTranslation;
  bool _hasDefinition = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    if (p != null) {
      _apply(p);
      //若预设缺少例句则异步后台补全
      if (p.example == null && widget.lookupFull) {
        _supplementExample();
      }
    } else {
      _fetchDefinition();
    }
  }

  void _apply(DictionaryQueryResult r) {
    setState(() {
      _phonetic = r.phonetic;
      _hasDefinition = r.definition != null && r.definition!.trim().isNotEmpty;
      _definition = r.definition;
      _example = r.example;
      _exampleTranslation = r.exampleTranslation;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _supplementExample() async {
    try {
      final full = await DefinitionService.lookupFull(widget.word);
      if (!mounted || full == null) return;
      if (full.example != null && mounted) {
        setState(() {
          _example ??= full.example;
          _exampleTranslation ??= full.exampleTranslation;
          if (_phonetic == null || _phonetic!.isEmpty) {
            _phonetic = full.phonetic;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchDefinition() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (widget.lookupFull) {
        final full = await DefinitionService.lookupFull(widget.word);
        if (!mounted) return;
        if (full != null &&
            (full.definition != null ||
                full.example != null ||
                full.phonetic != null)) {
          _apply(full);
          return;
        }
      }

      //网络源兜底
      final result = await DictionaryApiService.fetchWord(widget.word);
      if (!mounted) return;

      if (result == null) {
        setState(() {
          _error = context.tr.noDefinitionFound;
          _loading = false;
        });
        return;
      }

      setState(() {
        _phonetic = result.phonetic;
        _hasDefinition =
            result.definition != null && result.definition!.trim().isNotEmpty;
        _definition = result.definition;
        _example = result.example;
        _exampleTranslation = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${context.tr.queryFailed}：$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final isGlass = context.select<ThemeProvider, bool>((p) => p.isLiquidGlass);
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final textTertiary = FluidTheme.getTextTertiaryColor(isDark);
    final borderColor = FluidTheme.getBorderColor(isDark);
    final accent = FluidTheme.primaryFluidGradient[0];

    final emptyState =
        !_loading &&
        _definition == null &&
        _example == null &&
        _phonetic == null;

    return FluidDialog(
      content: _loading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr.loading,
                      style: FluidTheme.bodySmall(
                        isDark,
                      ).copyWith(color: textSecondary),
                    ),
                  ],
                ),
              ),
            )
          : (_error != null || emptyState)
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 48,
                    color: textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? context.tr.noDefinitionFound,
                    textAlign: TextAlign.center,
                    style: FluidTheme.bodyMedium(
                      isDark,
                    ).copyWith(color: textSecondary),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                //顶部单词、音标与发音按钮
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            widget.word,
                            //弹窗内没有其他长按手势，直接用系统文本选择：
                            //长按单词即可弹出复制工具栏
                            style: FluidTheme.headingLarge(isDark).copyWith(
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (_phonetic?.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            _JellyBadge(
                              isGlass: isGlass,
                              isDark: isDark,
                              accent: accent,
                              child: Text(
                                _phonetic!.startsWith('/')
                                    ? _phonetic!
                                    : '/$_phonetic/',
                                style: FluidTheme.bodySmall(isDark).copyWith(
                                  //音标是文字，主色在浅色玻璃上仅 1.91:1，改用可读版主色
                                  color: FluidTheme.primaryAccessible(isDark),
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _DictAudioButton(word: widget.word, isGlass: isGlass),
                  ],
                ),

                const SizedBox(height: 16),
                //果冻受光分割线：玻璃模式用亮白衰减，流体模式用主色衰减
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isGlass
                          ? [
                              Colors.white.withValues(
                                alpha: isDark ? 0.5 : 0.85,
                              ),
                              Colors.white.withValues(
                                alpha: isDark ? 0.12 : 0.3,
                              ),
                              Colors.white.withValues(alpha: 0),
                            ]
                          : [
                              accent.withValues(alpha: isDark ? 0.4 : 0.3),
                              borderColor,
                              borderColor.withValues(alpha: 0),
                            ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                //释义模块
                if (_hasDefinition) ...[
                  _JellyBadge(
                    isGlass: isGlass,
                    isDark: isDark,
                    accent: accent,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.translate_rounded, size: 13, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          context.tr.dictDefinition,
                          style: FluidTheme.labelMedium(isDark).copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _definition!,
                    style: FluidTheme.bodyLarge(
                      isDark,
                    ).copyWith(color: textPrimary, height: 1.6),
                  ),
                ],

                //双语例句模块
                if (_example?.isNotEmpty == true) ...[
                  const SizedBox(height: 18),
                  _ExampleCard(
                    isGlass: isGlass,
                    isDark: isDark,
                    accent: accent,
                    borderColor: borderColor,
                    example: _example!,
                    translation: _exampleTranslation,
                    label: context.tr.bilingualExample,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ],
              ],
            ),
      actions: [
        //用 Row+Expanded 让重试/关闭等宽：Wrap 不支持 Expanded，
        //两个按钮宽度由文字长度决定，重试带图标更宽，关闭只有两字更窄，
        //视觉上长短不一很别扭。
        Row(
          children: [
            if (widget.preset == null)
              Expanded(
                child: _DictGhostButton(
                  icon: Icons.refresh_rounded,
                  label: context.tr.retry,
                  isGlass: isGlass,
                  isDark: isDark,
                  accent: accent,
                  onPressed: _loading ? null : _fetchDefinition,
                ),
              ),
            if (widget.preset == null) const SizedBox(width: 12),
            Expanded(
              child: FluidButton(
                text: context.tr.close,
                expanded: true,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 词典弹窗的次级按钮：与 [FluidButton] 同高的描边胶囊
class _DictGhostButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isGlass;
  final bool isDark;
  final Color accent;
  final VoidCallback? onPressed;

  const _DictGhostButton({
    required this.icon,
    required this.label,
    required this.isGlass,
    required this.isDark,
    required this.accent,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fg = FluidTheme.primaryAccessible(isDark);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ],
    );

    // 与 FluidButton 同高的描边胶囊：原来的裸文字按钮和渐变主按钮
    // 并排时一边"重"一边"轻"，视觉重心失衡也看不出是可点的按钮
    final Widget pill;
    if (isGlass) {
      pill = GlassSurface(
        height: 54,
        borderRadius: 27,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        tint: enabled
            ? LiquidGlass.accentTint(accent, isDark)
            : LiquidGlass.tint(isDark),
        child: Center(child: content),
      );
    } else {
      pill = Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
          border: Border.all(
            color: accent.withValues(alpha: isDark ? 0.55 : 0.35),
          ),
        ),
        child: Center(child: content),
      );
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 160),
          child: pill,
        ),
      ),
    );
  }
}

/// 果冻小徽章：玻璃模式为嵌套果冻片，流体模式为主色薄底
class _JellyBadge extends StatelessWidget {
  final bool isGlass;
  final bool isDark;
  final Color accent;
  final Widget child;

  const _JellyBadge({
    required this.isGlass,
    required this.isDark,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (isGlass) {
      //高透发光胶囊：薄 accent 底 + 品牌色外发光
      return GlowCapsule(
        color: accent,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: child,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.25 : 0.18),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}

/// 双语例句卡片：玻璃模式为带亮边的果冻片，流体模式为半透明磨砂底
class _ExampleCard extends StatelessWidget {
  final bool isGlass;
  final bool isDark;
  final Color accent;
  final Color borderColor;
  final String example;
  final String? translation;
  final String label;
  final Color textPrimary;
  final Color textSecondary;

  const _ExampleCard({
    required this.isGlass,
    required this.isDark,
    required this.accent,
    required this.borderColor,
    required this.example,
    required this.translation,
    required this.label,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 16,
                color: accent.withValues(alpha: isDark ? 0.85 : 0.95),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: FluidTheme.labelMedium(
                  isDark,
                ).copyWith(color: accent, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          //英文例句
          Text(
            example,
            style: FluidTheme.bodyMedium(isDark).copyWith(
              fontStyle: FontStyle.italic,
              color: textPrimary,
              height: 1.5,
            ),
          ),
          //中文例句翻译
          if (translation?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              translation!,
              style: FluidTheme.bodySmall(
                isDark,
              ).copyWith(color: textSecondary, height: 1.45),
            ),
          ],
        ],
      ),
    );

    if (isGlass) {
      //嵌套果冻片：白纱顶光 + 亮白描边，不再灰蒙蒙
      return GlassSurface(borderRadius: 14, child: body);
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FluidTheme.getMutedOverlayColor(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: body,
    );
  }
}

/// 发音播放按钮
class _DictAudioButton extends StatefulWidget {
  final String word;
  final bool isGlass;

  const _DictAudioButton({required this.word, required this.isGlass});

  @override
  State<_DictAudioButton> createState() => _DictAudioButtonState();
}

class _DictAudioButtonState extends State<_DictAudioButton>
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
      //playWord 内部已重试并走 errorStream 统一提示，此处不再重复播放
      if (!mounted) return;
    }

    setState(() => _isPlaying = false);
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDarkMode);
    final accent = FluidTheme.primaryFluidGradient[0];

    final icon = _isPlaying
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          )
        : Icon(Icons.volume_up_rounded, color: accent, size: 22);

    final button = widget.isGlass
        ? GlassSurface(
            width: 46,
            height: 46,
            borderRadius: 23,
            emphasized: true,
            tint: LiquidGlass.accentTint(accent, isDark),
            glowColor: accent,
            child: Center(child: icon),
          )
        : Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
              border: Border.all(
                color: accent.withValues(alpha: isDark ? 0.28 : 0.2),
              ),
              shape: BoxShape.circle,
            ),
            child: icon,
          );

    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 46, minHeight: 46),
        icon: button,
        onPressed: _isPlaying ? null : _play,
        tooltip: context.tr.playPronunciation,
      ),
    );
  }
}

/// 显示词典查询弹窗的辅助函数
Future<void> showDictionaryDialog({
  required BuildContext context,
  required String word,
}) {
  final isGlass = context.read<ThemeProvider>().isLiquidGlass;
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: isGlass ? 0.2 : 0.5),
    builder: (context) => DictionaryDialog(word: word, lookupFull: true),
  );
}

/// 字典查询弹窗（本地优先 + 联网补全），弹窗内自带 loading
Future<void> showDictionaryLookupDialog({
  required BuildContext context,
  required String word,
}) {
  final isGlass = context.read<ThemeProvider>().isLiquidGlass;
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: isGlass ? 0.2 : 0.5),
    builder: (context) => DictionaryDialog(word: word, lookupFull: true),
  );
}
