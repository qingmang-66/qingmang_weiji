import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/models.dart';
import 'package:qingmang_weiji/services/specialized_study_service.dart';
import 'package:qingmang_weiji/services/wrong_word_service.dart';

// buildSearchResultsRequest 纯逻辑测试
//
// 备注：buildSearchResultsRequest 内部不调用 wrongWordService，
// 所以这里使用 noSuchMethod 桩件即可。
void main() {
  final service = SpecializedStudyService(
    wrongWordService: _StubWrongWordService(),
  );

  group('SpecializedStudyService.buildSearchResultsRequest', () {
    test('空 wordIds 返回 null', () async {
      final request = await service.buildSearchResultsRequest(
        wordIds: const [],
        query: 'apple',
        wordBookId: 1,
        studyMode: 1,
      );
      expect(request, isNull);
    });

    test('正常 wordIds 返回 searchResults 类型的 request', () async {
      final request = await service.buildSearchResultsRequest(
        wordIds: const [1, 2, 3],
        query: 'apple',
        wordBookId: 1,
        studyMode: 2,
      );
      expect(request, isNotNull);
      expect(request!.source, StudySource.searchResults);
      expect(request.title, contains('apple'));
      expect(request.wordIds, [1, 2, 3]);
      expect(request.wordBookId, 1);
      expect(request.studyMode, 2);
      expect(request.isReview, isTrue);
      expect(request.hasWords, isTrue);
    });

    test('相同 query 复用同一 progressKey', () async {
      final r1 = await service.buildSearchResultsRequest(
        wordIds: const [1, 2, 3],
        query: 'apple',
        wordBookId: 1,
        studyMode: 1,
      );
      final r2 = await service.buildSearchResultsRequest(
        wordIds: const [4, 5],
        query: 'apple',
        wordBookId: null,
        studyMode: 1,
      );
      expect(r1!.progressKey, isNotEmpty);
      expect(r2!.progressKey, equals(r1.progressKey));
      expect(r1.progressKey, startsWith('searchResults:'));
    });

    test('不同 query 产生不同 progressKey', () async {
      final r1 = await service.buildSearchResultsRequest(
        wordIds: const [1, 2, 3],
        query: 'apple',
        wordBookId: 1,
        studyMode: 1,
      );
      final r2 = await service.buildSearchResultsRequest(
        wordIds: const [1, 2, 3],
        query: 'banana',
        wordBookId: 1,
        studyMode: 1,
      );
      expect(r1!.progressKey, isNot(equals(r2!.progressKey)));
    });

    test('标题包含 query 原文与搜索结果临时学习前缀', () async {
      final request = await service.buildSearchResultsRequest(
        wordIds: const [1],
        query: 'hello world',
        wordBookId: null,
        studyMode: 1,
      );
      expect(request!.title, contains('hello world'));
      expect(request.title, contains('搜索结果临时学习'));
    });

    test('空字符串 query 仍生成有效 request', () async {
      final request = await service.buildSearchResultsRequest(
        wordIds: const [1, 2, 3],
        query: '',
        wordBookId: null,
        studyMode: 1,
      );
      expect(request, isNotNull);
      expect(request!.progressKey, startsWith('searchResults:'));
    });
  });
}

// 空实现桩件。buildSearchResultsRequest 不会调用这些方法。
// 利用 noSuchMethod 兜底，让 analyzer 不报"必须实现所有方法"。
// ignore: avoid_implementing_value_types
class _StubWrongWordService implements WrongWordService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
