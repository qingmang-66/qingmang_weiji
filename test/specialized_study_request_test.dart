import 'package:qingmang_weiji/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('SpecializedStudyRequest', () {
    test('为错词专项复习生成稳定进度键', () {
      const request = SpecializedStudyRequest(
        source: StudySource.wrongWords,
        title: '错词专项复习',
        wordBookId: 1,
        wordIds: [3, 2, 1],
        studyMode: 2,
        isReview: true,
        allowProgressSave: true,
      );

      expect(request.progressKey, 'wrongWords:1');
      expect(request.hasWords, isTrue);
    });

    test('空单词列表不可开始学习', () {
      const request = SpecializedStudyRequest(
        source: StudySource.wrongWords,
        title: '错词专项复习',
        wordBookId: null,
        wordIds: [],
        studyMode: 1,
        isReview: true,
      );

      expect(request.hasWords, isFalse);
    });

    test('显式进度键优先于默认进度键', () {
      const request = SpecializedStudyRequest(
        source: StudySource.wrongWords,
        title: '选中错词复习',
        wordBookId: 1,
        wordIds: [8, 9],
        studyMode: 3,
        isReview: true,
        explicitProgressKey: 'wrongWords:selected',
      );

      expect(request.progressKey, 'wrongWords:selected');
    });

    test('wordBookId 为空时进度键回退为 source:global', () {
      const request = SpecializedStudyRequest(
        source: StudySource.searchResults,
        title: '搜索结果临时学习',
        wordBookId: null,
        wordIds: [10, 20, 30],
        studyMode: 1,
        isReview: true,
      );

      expect(request.progressKey, 'searchResults:global');
    });

    test('搜索结果专项学习显式进度键优先', () {
      const request = SpecializedStudyRequest(
        source: StudySource.searchResults,
        title: '搜索结果临时学习',
        wordBookId: null,
        wordIds: [10, 20, 30],
        studyMode: 1,
        isReview: true,
        explicitProgressKey: 'searchResults:123',
      );

      expect(request.progressKey, 'searchResults:123');
    });
  });
}
