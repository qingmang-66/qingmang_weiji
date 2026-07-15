import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'repositories/custom_word_set_repository.dart';
import 'repositories/favorite_repository.dart';
import 'wrong_word_service.dart';

class SpecializedStudyService {
  final WrongWordService wrongWordService;
  final FavoriteRepository favoriteRepository;
  final CustomWordSetRepository customWordSetRepository;

  const SpecializedStudyService({
    required this.wrongWordService,
    required this.favoriteRepository,
    required this.customWordSetRepository,
  });

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

  Future<SpecializedStudyRequest?> buildFavoritesRequest({
    required int? wordBookId,
    required String? groupName,
    required int studyMode,
  }) async {
    final words = await favoriteRepository.getFavoriteWords(
      groupName: groupName,
    );
    final wordIds = words.map((word) => word.id).whereType<int>().toList();
    if (wordIds.isEmpty) return null;
    final groupTitle = groupName == null || groupName.isEmpty
        ? ''
        : '（$groupName）';
    return SpecializedStudyRequest(
      source: StudySource.favorites,
      title: '收藏夹专项学习$groupTitle',
      wordBookId: wordBookId,
      wordIds: wordIds,
      studyMode: studyMode,
      isReview: true,
      explicitProgressKey: groupName == null || groupName.isEmpty
          ? 'favorites:all'
          : 'favorites:group:$groupName',
      // 阶段三：专项学习完成回调 - 收藏夹专项学习完成后回写 last_studied_at
      onCompleted: () => markFavoritesStudied(wordIds),
    );
  }

  Future<SpecializedStudyRequest?> buildCustomWordSetRequest({
    required int setId,
    required int studyMode,
  }) async {
    final set = await customWordSetRepository.getSet(setId);
    if (set == null) return null;
    final words = await customWordSetRepository.getWordsInSet(setId);
    final wordIds = words.map((word) => word.id).whereType<int>().toList();
    if (wordIds.isEmpty) return null;
    return SpecializedStudyRequest(
      source: StudySource.customWordSet,
      title: '${set.name} 专项学习',
      wordBookId: null,
      wordIds: wordIds,
      studyMode: studyMode,
      isReview: true,
      explicitProgressKey: 'customWordSet:$setId',
      // 阶段三：专项学习完成回调 - 词集专项学习完成后回写 last_studied_at
      onCompleted: () => markCustomWordSetStudied(setId),
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
      explicitProgressKey:
          'searchResults:${query.trim().hashCode.toUnsigned(20)}',
    );
  }

  Future<void> markFavoritesStudied(List<int> wordIds) async {
    await favoriteRepository.updateLastStudiedAt(wordIds, DateTime.now());
  }

  /// 阶段三：自定义词集增强 - 词集专项学习完成后回写 last_studied_at
  ///
  /// 由 PreStudyScreen 在 source == customWordSet 时调用。
  /// 失败时仅日志，不影响主流程。
  Future<void> markCustomWordSetStudied(int setId) async {
    try {
      await customWordSetRepository.updateLastStudiedAt(setId, DateTime.now());
    } catch (e) {
      debugPrint('SpecializedStudyService.markCustomWordSetStudied error: $e');
      rethrow;
    }
  }
}
