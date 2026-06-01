import 'package:qingmang_weiji/services/study_progress_logic.dart';
import 'package:test/test.dart';

void main() {
  group('继续学习进度逻辑', () {
    test('恢复学习时从保存的当前索引开始裁剪待学单词', () {
      final remaining = StudyProgressLogic.remainingWordIds(
        wordIds: [1, 2, 3, 4, 5],
        currentIndex: 2,
      );

      expect(remaining, [3, 4, 5]);
    });

    test('当前索引小于0时从第一个单词恢复', () {
      final remaining = StudyProgressLogic.remainingWordIds(
        wordIds: [1, 2, 3],
        currentIndex: -2,
      );

      expect(remaining, [1, 2, 3]);
    });

    test('当前索引超过词表长度时返回空列表', () {
      final remaining = StudyProgressLogic.remainingWordIds(
        wordIds: [1, 2, 3],
        currentIndex: 5,
      );

      expect(remaining, isEmpty);
    });

    test('保存下一题进度时使用下一题索引', () {
      final nextIndex = StudyProgressLogic.nextProgressIndex(
        currentIndex: 2,
        totalWords: 5,
      );

      expect(nextIndex, 3);
    });

    test('最后一题之后没有可保存进度', () {
      final nextIndex = StudyProgressLogic.nextProgressIndex(
        currentIndex: 4,
        totalWords: 5,
      );

      expect(nextIndex, isNull);
    });

    test('普通学习进度使用稳定默认来源键', () {
      final key = StudyProgressLogic.defaultProgressKey(
        source: 'normal',
        wordBookId: 7,
      );

      expect(key, 'normal:7');
    });

    test('空标题回退为继续学习', () {
      final title = StudyProgressLogic.safeProgressTitle('');

      expect(title, '继续学习');
    });
  });
}
