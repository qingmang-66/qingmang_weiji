import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 从资产文件读取内置词库（不使用网络，完全离线）
/// 注意：下面的词库清单是内置词库的唯一来源，修改时必须与 assets 下的实际文件同步
class AssetWordBookService {
  ///预定义的词库列表（唯一来源，其他模块不应再维护同名清单）
  static const List<Map<String, String>> _bookDefinitions = [
    {
      'name': '初中英语词汇',
      'description': '初中英语必背词汇（含音标、释义、短语、例句）',
      'file': 'chuzhong.json',
    },
    {
      'name': '初中英语词汇（乱序）',
      'description': '初中英语必背词汇（含音标、释义、短语、例句）（单词顺序已打乱）',
      'file': 'chuzhong_shuffled.json',
    },
    {
      'name': '高中英语词汇',
      'description': '高中英语必背词汇（含音标、释义、短语、例句）',
      'file': 'gaozhong.json',
    },
    {
      'name': '高中英语词汇（乱序）',
      'description': '高中英语必背词汇（含音标、释义、短语、例句）（单词顺序已打乱）',
      'file': 'gaozhong_shuffled.json',
    },
    {
      'name': '大学英语四级',
      'description': '大学英语四级考试核心词汇（含音标、释义、短语、例句）',
      'file': 'cet4.json',
    },
    {
      'name': '大学英语四级（乱序）',
      'description': '大学英语四级考试核心词汇（含音标、释义、短语、例句）（单词顺序已打乱）',
      'file': 'cet4_shuffled.json',
    },
    {
      'name': '大学英语六级',
      'description': '大学英语六级考试核心词汇（含音标、释义、短语、例句）',
      'file': 'cet6.json',
    },
    {
      'name': '大学英语六级（乱序）',
      'description': '大学英语六级考试核心词汇（含音标、释义、短语、例句）（单词顺序已打乱）',
      'file': 'cet6_shuffled.json',
    },
    {
      'name': '考研英语词汇',
      'description': '研究生入学考试英语词汇（含音标、释义、短语、例句）',
      'file': 'kaoyan.json',
    },
    {
      'name': '考研英语词汇（乱序）',
      'description': '研究生入学考试英语词汇（含音标、释义、短语、例句）（单词顺序已打乱）',
      'file': 'kaoyan_shuffled.json',
    },
    {
      'name': '托福词汇',
      'description': '托福考试核心词汇（含音标、释义、短语、例句）',
      'file': 'toefl.json',
    },
    {
      'name': '托福词汇（乱序）',
      'description': '托福考试核心词汇（含音标、释义、短语、例句）（单词顺序已打乱）',
      'file': 'toefl_shuffled.json',
    },
    {
      'name': 'SAT词汇',
      'description': 'SAT 考试核心词汇（含音标、释义、短语、例句）',
      'file': 'sat.json',
    },
    {
      'name': 'SAT词汇（乱序）',
      'description': 'SAT 考试核心词汇（含音标、释义、短语、例句）（单词顺序已打乱）',
      'file': 'sat_shuffled.json',
    },
  ];

  static const Map<String, int> _wordCounts = {
    'chuzhong.json': 1989,
    'chuzhong_shuffled.json': 1989,
    'gaozhong.json': 3749,
    'gaozhong_shuffled.json': 3749,
    'cet4.json': 4543,
    'cet4_shuffled.json': 4543,
    'cet6.json': 3991,
    'cet6_shuffled.json': 3991,
    'kaoyan.json': 5052,
    'kaoyan_shuffled.json': 5052,
    'toefl.json': 10284,
    'toefl_shuffled.json': 10284,
    'sat.json': 4451,
    'sat_shuffled.json': 4451,
  };
  static const int _maxCachedBooks = 2;
  //完整词库仅保留最近 2 本；元数据缓存可长期保留
  static final Map<String, List<Map<String, String>>> _wordsCache = {};
  static final List<String> _wordsCacheOrder = [];
  static List<Map<String, dynamic>>? _metaCache;

  /// 名字是否为「（乱序）」变体词库。
  ///
  /// 乱序版与正序版是同一批词、同一数量，只是 json 里的单词顺序不同。
  /// 现在排序方式改为每本词库自己的开关（见 WordBookProvider.setShuffledOrder），
  /// 乱序版不再作为独立词库对外提供 —— 不在导入面板/词库列表里出现。
  static bool isShuffledVariantName(String name) {
    final lower = name.toLowerCase();
    return name.contains('乱序') || lower.contains('shuffled');
  }

  /// 获取所有内置词库元信息（不读取词库内容）
  static Future<List<Map<String, dynamic>>> getAllBuiltInBooks() async {
    if (_metaCache != null) return _metaCache!;
    _metaCache = _bookDefinitions
        //乱序变体不再作为独立词库提供（学习顺序由词库的排序开关决定）
        .where((book) => !isShuffledVariantName(book['name']!))
        .map(
          (book) => <String, dynamic>{
            'name': book['name'],
            'description': book['description'],
            'file': book['file'],
            'wordCount': _wordCounts[book['file']] ?? 0,
          },
        )
        .toList(growable: false);
    return _metaCache!;
  }

  //同一本词书的并发加载共享同一个 Future：toefl.json 有 3.6MB，
  //并发触发时重复 compute 会白付两遍解析成本
  static final Map<String, Future<List<Map<String, String>>>> _inflight = {};

  /// 按文件名按需加载单词（Isolate解析 + 缓存）
  /// Web 端不走 compute：大 JSON 在 worker 中易失败并静默返回空列表
  static Future<List<Map<String, String>>> loadBookWords(String fileName) {
    final cached = _wordsCache[fileName];
    if (cached != null) {
      _touchWordsCache(fileName);
      return Future.value(cached);
    }
    final pending = _inflight[fileName];
    if (pending != null) return pending;
    final future = _loadBookWordsInner(fileName);
    _inflight[fileName] = future;
    return future.whenComplete(() {
      if (identical(_inflight[fileName], future)) {
        _inflight.remove(fileName);
      }
    });
  }

  static Future<List<Map<String, String>>> _loadBookWordsInner(
    String fileName,
  ) async {
    try {
      final raw = await rootBundle.loadString('assets/wordbooks/$fileName');
      final List<Map<String, String>> words;
      if (kIsWeb) {
        words = _parseWordsIsolate(raw);
      } else {
        words = await compute(_parseWordsIsolate, raw);
      }
      if (words.isEmpty) {
        debugPrint('词库 $fileName 解析结果为空');
        //不缓存空结果：一次失败/空文件会让本进程内一直命中空缓存（须重启）
        return words;
      }
      debugPrint('词库 $fileName 加载成功：${words.length} 词');
      _putWordsCache(fileName, words);
      return words;
    } catch (e, st) {
      debugPrint('Error loading word list $fileName: $e\n$st');
      return [];
    }
  }

  /// 按词库名称加载单词
  static Future<List<Map<String, String>>> loadBookWordsByName(
    String name,
  ) async {
    for (final book in _bookDefinitions) {
      if (book['name'] == name) return loadBookWords(book['file']!);
    }
    return [];
  }

  static void _touchWordsCache(String fileName) {
    _wordsCacheOrder.remove(fileName);
    _wordsCacheOrder.add(fileName);
  }

  static void _putWordsCache(String fileName, List<Map<String, String>> words) {
    _wordsCache[fileName] = words;
    _touchWordsCache(fileName);
    while (_wordsCacheOrder.length > _maxCachedBooks) {
      final evicted = _wordsCacheOrder.removeAt(0);
      _wordsCache.remove(evicted);
    }
  }

  @visibleForTesting
  static void clearWordsCacheForTesting() {
    _wordsCache.clear();
    _wordsCacheOrder.clear();
  }

  @visibleForTesting
  static void cacheWordsForTesting(
    String fileName,
    List<Map<String, String>> words,
  ) {
    _putWordsCache(fileName, words);
  }

  @visibleForTesting
  static List<String> get cachedBookNamesForTesting =>
      List<String>.unmodifiable(_wordsCacheOrder);
}

/// Isolate入口：解析词库 JSON
List<Map<String, String>> _parseWordsIsolate(String raw) {
  final jsonData = jsonDecode(raw) as Map<String, dynamic>;
  final wordsList = jsonData['words'] as List<dynamic>? ?? const [];
  return wordsList
      .map((wordData) {
        final wordMap = wordData as Map<String, dynamic>;
        return <String, String>{
          'word': wordMap['word'] as String? ?? '',
          'phonetic': wordMap['phonetic'] as String? ?? '',
          'definition': wordMap['definition'] as String? ?? '',
          'phrases': wordMap['phrases'] as String? ?? '',
          'example': wordMap['example'] as String? ?? '',
          'exampleTranslation': wordMap['exampleTranslation'] as String? ?? '',
        };
      })
      .toList(growable: false);
}
