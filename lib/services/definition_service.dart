import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'dictionary_api_service.dart';
import 'youdao_service.dart';
import '../utils/constants.dart';
import '../models/word.dart';

/// 词典查询接口 - 实现此接口可以扩展新的词典源
abstract class DictionaryProvider {
  /// 查询单词释义
  Future<DictionaryQueryResult?> fetchWordDefinition(String word);
  
  /// 获取词典名称（用于日志）
  String get providerName;
}

/// 词典查询结果统一格式
class DictionaryQueryResult {
  final String word;
  final String? phonetic;
  final String? definition;
  final String? example;
  final String? exampleTranslation;
  final String? audioUrl;

  DictionaryQueryResult({
    required this.word,
    this.phonetic,
    this.definition,
    this.example,
    this.exampleTranslation,
    this.audioUrl,
  });
}

/// Free Dictionary API 适配器
class FreeDictionaryProvider implements DictionaryProvider {
  @override
  String get providerName => 'Free Dictionary API';

  @override
  Future<DictionaryQueryResult?> fetchWordDefinition(String word) async {
    final result = await DictionaryApiService.fetchWord(word);
    if (result == null) return null;
    
    return DictionaryQueryResult(
      word: result.word,
      phonetic: result.phonetic,
      definition: result.definition,
      example: result.example,
      audioUrl: result.audioUrl,
    );
  }
}

/// 有道词典 API 适配器
class YoudaoDictionaryProvider implements DictionaryProvider {
  @override
  String get providerName => '有道词典';

  @override
  Future<DictionaryQueryResult?> fetchWordDefinition(String word) async {
    final result = await YoudaoService.fetchWord(word);
    if (result == null) return null;
    
    return DictionaryQueryResult(
      word: result.word,
      phonetic: result.phonetic,
      definition: result.definition,
      example: result.example,
      exampleTranslation: result.exampleTranslation,
    );
  }
}

/// 智能释义服务 - 混合本地 + 在线
/// 
/// 使用策略模式管理词典源，支持扩展
class DefinitionService {
  // 词典源映射
  static final Map<DictionarySource, DictionaryProvider> _providers = {
    DictionarySource.freeDictionary: FreeDictionaryProvider(),
    DictionarySource.youdao: YoudaoDictionaryProvider(),
  };
  
  static DictionarySource _source = DictionarySource.freeDictionary;

  static void setDictionarySource(DictionarySource source) {
    _source = source;
    debugPrint('📚 词典源切换为：${_providers[source]?.providerName ?? source.name}');
  }
  
  /// 获取当前词典源提供商（若指定源未注册，退回 FreeDictionary 作为默认值）
  static DictionaryProvider get _currentProvider =>
      _providers[_source] ?? FreeDictionaryProvider();

  static Future<Word> getWordWithDefinition(Word word, {bool forceOnline = false}) async {
    try {
      final localDefinition = word.definition.trim();
      final hasValidDefinition = localDefinition.isNotEmpty &&
          !localDefinition.contains('释义待补充') &&
          !localDefinition.contains('[释义');

      if (hasValidDefinition && !forceOnline) {
        debugPrint('✓ 使用本地释义：${word.word}');
        return word;
      }

      debugPrint('🌐 查询在线释义（${_currentProvider.providerName}）：${word.word}');
      final result = await _currentProvider.fetchWordDefinition(word.word);

      if (result == null) {
        debugPrint('⚠ API 无结果：${word.word}');
        return word;
      }

      final updatedWord = Word(
        id: word.id,
        word: word.word,
        phonetic: result.phonetic?.isNotEmpty == true ? result.phonetic! : word.phonetic,
        definition: result.definition?.isNotEmpty == true ? result.definition! : word.definition,
        example: result.example?.isNotEmpty == true ? result.example! : word.example,
        exampleTranslation: result.exampleTranslation?.isNotEmpty == true ? result.exampleTranslation! : word.exampleTranslation,
        wordBookId: word.wordBookId,
        root: word.root,
        suffix: word.suffix,
        synonym: word.synonym,
        antonym: word.antonym,
        derivative: word.derivative,
      );

      if (word.id != null) {
        await DatabaseService.updateWordDefinition(
          wordId: word.id!,
          phonetic: updatedWord.phonetic,
          definition: updatedWord.definition,
          example: updatedWord.example,
        );
        debugPrint('✓ 已更新数据库：${word.word}');
      }

      // 如果有音频 URL，下载并缓存
      if (result.audioUrl != null) {
        await DictionaryApiService.downloadAndCacheAudio(result.audioUrl!, word.word);
      }

      return updatedWord;
    } catch (e) {
      debugPrint('❌ 查询释义失败 ${word.word}: $e');
      return word;
    }
  }

  static Future<void> prefetchDefinitions(List<Word> words, {int max = 50, int batchSize = 5}) async {
    debugPrint('🔧 预加载释义：${words.length} 个单词（最多 $max 个，批量大小 $batchSize）');
    
    final wordsToProcess = words.where((word) {
      final hasValidDef = word.definition.isNotEmpty
          && !word.definition.contains('释义待补充')
          && !word.definition.contains('[释义');
      return !hasValidDef;
    }).take(max).toList();

    int processed = 0;
    for (int i = 0; i < wordsToProcess.length; i += batchSize) {
      final batch = wordsToProcess.skip(i).take(batchSize).toList();
      await Future.wait(
        batch.map((word) => getWordWithDefinition(word)),
        eagerError: false,
      );
      processed += batch.length;
      debugPrint('📝 已处理 $processed/${wordsToProcess.length} 个单词');
    }
    
    debugPrint('✅ 预加载完成：$processed 个单词');
  }
}
