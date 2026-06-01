import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dictionary_api_service.dart';
import '../services/providers/theme_provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';
import 'fluid_button.dart';
import 'fluid_dialog.dart';

/// 词典查询弹窗（基于 FluidDialog）
class DictionaryDialog extends StatefulWidget {
  final String word;

  const DictionaryDialog({super.key, required this.word});

  @override
  State<DictionaryDialog> createState() => _DictionaryDialogState();
}

class _DictionaryDialogState extends State<DictionaryDialog> {
  String? _definition;
  String? _phonetic;
  String? _example;
  bool _hasDefinition = false;
  bool _loading = false;
  String? _error;

  Future<void> _fetchDefinition() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
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
        _hasDefinition = result.definition != null;
        _definition = result.definition;
        _example = result.example;
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
  void initState() {
    super.initState();
    _fetchDefinition();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final textTertiary = FluidTheme.getTextTertiaryColor(isDark);
    final borderColor = FluidTheme.getBorderColor(isDark);

    return FluidDialog(
      title: widget.word,
      content: _loading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(
                  color: FluidTheme.primaryFluidGradient[0],
                ),
              ),
            )
          : _error != null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 48, color: textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: FluidTheme.bodyMedium(
                      isDark,
                    ).copyWith(color: textSecondary),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 音标
                  if (_phonetic?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '/$_phonetic/',
                        style: FluidTheme.headingSmall(isDark).copyWith(
                          color: textSecondary,
                          fontStyle: FontStyle.italic,
                          fontSize: 18,
                        ),
                      ),
                    ),

                  // 词性标签
                  if (_hasDefinition)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: FluidTheme.primaryFluidGradient,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        context.tr.dictDefinition,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 释义
                  Text(
                    _definition ?? context.tr.noDefinition,
                    style: FluidTheme.bodyLarge(isDark).copyWith(height: 1.5),
                  ),

                  // 例句
                  if (_example != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FluidTheme.getMutedOverlayColor(isDark),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.format_quote,
                                size: 14,
                                color: FluidTheme.primaryFluidGradient[0],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.tr.exampleSection,
                                style: FluidTheme.labelMedium(isDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _example!,
                            style: FluidTheme.bodyMedium(isDark).copyWith(
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _fetchDefinition,
          style: TextButton.styleFrom(
            foregroundColor: FluidTheme.primaryFluidGradient[0],
          ),
          child: Text(context.tr.retry),
        ),
        FluidButton(
          text: context.tr.close,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

/// 显示词典查询弹窗的辅助函数
Future<void> showDictionaryDialog({
  required BuildContext context,
  required String word,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (context) => DictionaryDialog(word: word),
  );
}
