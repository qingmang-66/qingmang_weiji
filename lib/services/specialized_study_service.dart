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
    );
  }

  Future<void> markFavoritesStudied(List<int> wordIds) async {
    await favoriteRepository.updateLastStudiedAt(wordIds, DateTime.now());
  }
}
