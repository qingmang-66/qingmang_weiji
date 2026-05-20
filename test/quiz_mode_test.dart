import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/models.dart';

/// 测验模式单元测试 - 验证干扰项生成和评分逻辑
/// 测试 _generateQuizOptions 和 _onQuizNext 的核心逻辑

void main() {
  group('测验模式测试', () {
    // 模拟单词列表
    final words = [
      Word(id: 1, word: 'apple', definition: '苹果', wordBookId: 1),
      Word(id: 2, word: 'banana', definition: '香蕉', wordBookId: 1),
      Word(id: 3, word: 'cherry', definition: '樱桃', wordBookId: 1),
      Word(id: 4, word: 'date', definition: '日期', wordBookId: 1),
      Word(id: 5, word: 'elderberry', definition: '接骨木果', wordBookId: 1),
      Word(id: 6, word: 'fig', definition: '无花果', wordBookId: 1),
      Word(id: 7, word: 'grape', definition: '葡萄', wordBookId: 1),
      Word(id: 8, word: 'honeydew', definition: '哈密瓜', wordBookId: 1),
    ];

    group('干扰项生成测试', () {
      test('应该生成4个选项', () {
        final correctWord = words[0];
        final options = generateQuizOptions(correctWord, words);

        expect(options.length, equals(4));
      });

      test('必须包含正确答案', () {
        final correctWord = words[0];
        final options = generateQuizOptions(correctWord, words);

        expect(options.contains(correctWord.word), isTrue);
      });

      test('选项不能重复', () {
        final correctWord = words[0];
        final options = generateQuizOptions(correctWord, words);
        final uniqueOptions = options.toSet();

        expect(uniqueOptions.length, equals(4));
      });

      test('干扰项应该从其他单词中选取', () {
        final correctWord = words[0];
        final options = generateQuizOptions(correctWord, words);

        // 除了正确答案，其他3个应该都是来自单词列表
        final otherWords = words.where((w) => w.id != correctWord.id).map((w) => w.word).toList();
        final distractors = options.where((o) => o != correctWord.word).toList();

        for (final distractor in distractors) {
          expect(otherWords.contains(distractor), isTrue,
              reason: '干扰项 $distractor 应该来自单词列表');
        }
      });

      test('单词不足4个时应该用占位符填充', () {
        final shortList = [
          Word(id: 1, word: 'apple', definition: '苹果', wordBookId: 1),
          Word(id: 2, word: 'banana', definition: '香蕉', wordBookId: 1),
        ];
        final correctWord = shortList[0];
        final options = generateQuizOptions(correctWord, shortList);

        expect(options.length, equals(4));
        // 应该有占位符
        final hasPlaceholder = options.any((o) => o.startsWith('option_'));
        expect(hasPlaceholder, isTrue);
      });
    });

    group('评分逻辑测试', () {
      test('回答正确应该评分4（容易）', () {
        final selectedOption = 1;
        final correctOption = 1;
        final quality = calculateQuizQuality(selectedOption, correctOption);

        expect(quality, equals(4));
      });

      test('回答错误应该评分2（困难）', () {
        final selectedOption = 2;
        final correctOption = 1;
        final quality = calculateQuizQuality(selectedOption, correctOption);

        expect(quality, equals(2));
      });

      test('不同选项索引的评分', () {
        // 各种组合测试
        expect(calculateQuizQuality(0, 0), equals(4));
        expect(calculateQuizQuality(1, 1), equals(4));
        expect(calculateQuizQuality(2, 2), equals(4));
        expect(calculateQuizQuality(3, 3), equals(4));
        expect(calculateQuizQuality(0, 1), equals(2));
        expect(calculateQuizQuality(1, 0), equals(2));
        expect(calculateQuizQuality(2, 3), equals(2));
        expect(calculateQuizQuality(3, 0), equals(2));
      });
    });

    group('正确答案索引测试', () {
      test('正确答案索引应该在0-3范围内', () {
        final correctWord = words[3];
        final options = generateQuizOptions(correctWord, words);
        final correctIndex = options.indexOf(correctWord.word);

        expect(correctIndex, greaterThanOrEqualTo(0));
        expect(correctIndex, lessThanOrEqualTo(3));
      });

      test('多次生成应该随机分布正确答案位置', () {
        final correctWord = words[0];
        final positions = <int>[];

        // 生成100次，统计正确答案位置分布
        for (var i = 0; i < 100; i++) {
          final options = generateQuizOptions(correctWord, words);
          positions.add(options.indexOf(correctWord.word));
        }

        // 每个位置都应该至少出现几次（随机性测试）
        for (var pos = 0; pos < 4; pos++) {
          final count = positions.where((p) => p == pos).length;
          expect(count, greaterThan(0),
              reason: '位置 $pos 应该至少出现一次');
        }
      });
    });
  });
}

/// 模拟 _generateQuizOptions 方法逻辑
List<String> generateQuizOptions(Word correctWord, List<Word> allWords) {
  final options = <String>[correctWord.word];

  // 从当前词库中随机选择3个干扰项
  final otherWords = allWords.where((w) => w.id != correctWord.id).toList();
  otherWords.shuffle();

  for (var i = 0; i < 3 && i < otherWords.length; i++) {
    options.add(otherWords[i].word);
  }

  // 如果词库中单词不足4个，用占位符填充
  while (options.length < 4) {
    options.add('option_${options.length}');
  }

  options.shuffle();
  return options;
}

/// 模拟 _onQuizNext 评分逻辑
int calculateQuizQuality(int selectedOption, int correctOption) {
  final isCorrect = selectedOption == correctOption;
  return isCorrect ? 4 : 2;
}
