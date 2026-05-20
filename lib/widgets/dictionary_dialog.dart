import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 词典查询弹窗
class DictionaryDialog extends StatefulWidget {
  final String word;

  const DictionaryDialog({
    super.key,
    required this.word,
  });

  @override
  State<DictionaryDialog> createState() => _DictionaryDialogState();
}

class _DictionaryDialogState extends State<DictionaryDialog> {
  String? _definition;
  String? _phonetic;
  String? _example;
  String? _partOfSpeech;
  bool _loading = false;
  String? _error;

  Future<void> _fetchDefinition() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 使用 Free Dictionary API
      final response = await http.get(
        Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/${widget.word}'),
      );

      if (response.statusCode != 200) {
        setState(() {
          _error = '未找到该单词的释义';
          _loading = false;
        });
        return;
      }

      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) {
        setState(() {
          _error = '未找到该单词的释义';
          _loading = false;
        });
        return;
      }

      final entry = data[0] as Map<String, dynamic>;
      
      // 提取音标
      String? phonetic;
      if (entry.containsKey('phonetic')) {
        phonetic = entry['phonetic'] as String?;
      }
      if (phonetic == null && entry.containsKey('phonetics')) {
        final phonetics = entry['phonetics'] as List<dynamic>;
        for (var p in phonetics) {
          final pMap = p as Map<String, dynamic>;
          if (pMap['text'] != null && (pMap['text'] as String).isNotEmpty) {
            phonetic = pMap['text'] as String;
            break;
          }
        }
      }

      // 提取词性、释义和例句
      String? partOfSpeech;
      String? definition;
      String? example;

      if (entry.containsKey('meanings')) {
        final meanings = entry['meanings'] as List<dynamic>;
        if (meanings.isNotEmpty) {
          final firstMeaning = meanings[0] as Map<String, dynamic>;
          partOfSpeech = firstMeaning['partOfSpeech'] as String?;

          if (firstMeaning.containsKey('definitions')) {
            final defs = firstMeaning['definitions'] as List<dynamic>;
            if (defs.isNotEmpty) {
              final firstDef = defs[0] as Map<String, dynamic>;
              definition = firstDef['definition'] as String?;
              example = firstDef['example'] as String?;
            }
          }
        }
      }

      setState(() {
        _phonetic = phonetic ?? '无音标';
        _partOfSpeech = partOfSpeech ?? '未知词性';
        _definition = definition ?? '无释义';
        _example = example;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '查询失败：$e';
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
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.word,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
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
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ),

                        // 词性
                        if (_partOfSpeech?.isNotEmpty == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _partOfSpeech!,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),

                        const SizedBox(height: 16),

                        // 释义
                        Text(
                          _definition ?? '',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                height: 1.5,
                              ),
                        ),

                        // 例句
                        if (_example != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.format_quote,
                                      size: 14,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Example',
                                      style:
                                          Theme.of(context).textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _example!,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium?.copyWith(
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
      ),
      actions: [
        TextButton(
          onPressed: _fetchDefinition,
          child: const Text('重新查询'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
