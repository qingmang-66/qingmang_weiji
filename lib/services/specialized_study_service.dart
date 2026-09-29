import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../models/models.dart';
import 'wrong_word_service.dart';

class SpecializedStudyService {
  final WrongWordService wrongWordService;

  const SpecializedStudyService({required this.wrongWordService});

  Future<SpecializedStudyRequest?> buildWrongWordsRequest({
    required int? wordBookId,
    required List<int> selectedWordIds,
    required int studyMode,
  }) async {
    final words = selectedWordIds.isEmpty
        ? await wrongWordService.getWrongWords()
        : await wrongWordService.getWrongWordsByIds(selectedWordIds);
    final wordIds = words.map((word) => word.id).whereType<int>().toList();
    if (wordIds.isEmpty) return null;

    return SpecializedStudyRequest(
      source: StudySource.wrongWords,
      title: selectedWordIds.isEmpty ? '错词专项复习' : '选中错词复习',
      wordBookId: wordBookId,
      wordIds: wordIds,
      studyMode: studyMode,
      isReview: true,
      explicitProgressKey: selectedWordIds.isEmpty
          ? null
          : 'wrongWords:selected:${wordIds.join('-')}',
    );
  }

  /// 构建「收藏夹专项复习」请求
  ///
  /// [wordIds] 由调用方从收藏夹取出后传入（收藏是跨词库的，故 wordBookId 为 null）。
  /// [isSubset] 表示只复习选中的一部分：此时 progressKey 带上具体 id，
  /// 避免与"全部收藏词"的复习进度互相覆盖。
  Future<SpecializedStudyRequest?> buildFavoritesRequest({
    required List<int> wordIds,
    required int studyMode,
    bool isSubset = false,
    String? title,
  }) async {
    if (wordIds.isEmpty) return null;
    return SpecializedStudyRequest(
      source: StudySource.favorites,
      title: title ?? '收藏词专项复习',
      wordBookId: null,
      wordIds: wordIds,
      studyMode: studyMode,
      isReview: true,
      explicitProgressKey: isSubset
          ? 'favorites:selected:${wordIds.join('-')}'
          : null,
    );
  }

  /// 构建「搜索结果临时学习」请求
  ///
  /// [wordIds] 来自当前搜索结果；[query] 用于标题展示和 progressKey。
  /// 同一 query 复用同一 progressKey，便于「继续上次学习」恢复。
  Future<SpecializedStudyRequest?> buildSearchResultsRequest({
    required List<int> wordIds,
    required String query,
    required int? wordBookId,
    required int studyMode,
  }) async {
    if (wordIds.isEmpty) return null;
    return SpecializedStudyRequest(
      source: StudySource.searchResults,
      title: '搜索结果临时学习：$query',
      wordBookId: wordBookId,
      wordIds: wordIds,
      studyMode: studyMode,
      isReview: true,
      explicitProgressKey: 'searchResults:${await _stableQueryDigest(query)}',
    );
  }

  /// 搜索词摘要：SHA-1 的前 16 个 hex 字符。
  ///
  /// 该键会被持久化用于"继续上次学习"。此前的 String.hashCode 不保证跨 SDK
  /// 版本稳定、且 32 位哈希可碰撞（升级后对不上 / 不同 query 串味）。改用稳定
  /// 摘要后旧进度会一次性失效（可接受）。
  static Future<String> _stableQueryDigest(String query) async {
    final hash = await Sha1().hash(utf8.encode(query.trim()));
    final hex = hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return hex.substring(0, 16);
  }
}
