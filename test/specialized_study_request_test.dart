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

    test('未注入 onCompleted 时字段为 null', () {
      const request = SpecializedStudyRequest(
        source: StudySource.wrongWords,
        title: '错词专项复习',
        wordBookId: 1,
        wordIds: [1, 2, 3],
        studyMode: 1,
        isReview: true,
      );

      expect(request.onCompleted, isNull);
    });

    test('注入 onCompleted 闭包后可被调用', () async {
      var invoked = 0;
      final request = SpecializedStudyRequest(
        source: StudySource.favorites,
        title: '收藏夹专项学习',
        wordBookId: null,
        wordIds: [1, 2, 3],
        studyMode: 1,
        isReview: true,
        onCompleted: () async {
          invoked += 1;
        },
      );

      expect(request.onCompleted, isNotNull);
      await request.onCompleted!.call();
      await request.onCompleted!.call();
      expect(invoked, 2);
    });

    test('onCompleted 闭包抛错时不破坏调用方', () async {
      final request = SpecializedStudyRequest(
        source: StudySource.favorites,
        title: '收藏夹专项学习',
        wordBookId: null,
        wordIds: [1, 2, 3],
        studyMode: 1,
        isReview: true,
        onCompleted: () async {
          throw StateError('模拟回写失败');
        },
      );

      expect(() => request.onCompleted!.call(), throwsA(isA<StateError>()));
    });

    test('收藏夹专项学习携带 customWordSetId 与 onCompleted 互不干扰', () {
      final request = SpecializedStudyRequest(
        source: StudySource.customWordSet,
        title: '词集专项学习',
        wordBookId: null,
        wordIds: [10, 20, 30],
        studyMode: 1,
        isReview: true,
        customWordSetId: 7,
        onCompleted: () async {},
      );

      expect(request.customWordSetId, 7);
      expect(request.onCompleted, isNotNull);
      // 无 explicitProgressKey 且 wordBookId 为 null 时，进度键回退为 source:global
      expect(request.progressKey, 'customWordSet:global');
    });

    test('词集专项学习显式进度键优先', () {
      final request = SpecializedStudyRequest(
        source: StudySource.customWordSet,
        title: '词集专项学习',
        wordBookId: null,
        wordIds: [10, 20, 30],
        studyMode: 1,
        isReview: true,
        customWordSetId: 7,
        explicitProgressKey: 'customWordSet:7',
        onCompleted: () async {},
      );

      expect(request.progressKey, 'customWordSet:7');
    });
  });
}
