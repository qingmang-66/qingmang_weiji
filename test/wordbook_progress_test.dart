import 'package:qingmang_weiji/models/wordbook_progress.dart';
import 'package:test/test.dart';

void main() {
  group('词库进度模型', () {
    test('根据总词数和未学词数计算已学词数', () {
      final progress = WordBookProgress(
        bookId: 1,
        totalWords: 100,
        unlearnedWords: 25,
        dueWords: 8,
      );

      expect(progress.learnedWords, 75);
    });

    test('根据已学词数计算完成率', () {
      final progress = WordBookProgress(
        bookId: 1,
        totalWords: 200,
        unlearnedWords: 50,
        dueWords: 12,
      );

      expect(progress.learnedRatio, 0.75);
      expect(progress.learnedPercent, 75);
    });

    test('总词数为0时完成率为0', () {
      final progress = WordBookProgress(
        bookId: 1,
        totalWords: 0,
        unlearnedWords: 0,
        dueWords: 0,
      );

      expect(progress.learnedRatio, 0);
      expect(progress.learnedPercent, 0);
    });

    test('未学词数异常大于总词数时已学词数不小于0', () {
      final progress = WordBookProgress(
        bookId: 1,
        totalWords: 10,
        unlearnedWords: 20,
        dueWords: 0,
      );

      expect(progress.learnedWords, 0);
      expect(progress.learnedRatio, 0);
    });
  });
}
