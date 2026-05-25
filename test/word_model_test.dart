import 'package:test/test.dart';
import 'package:qingmang_weiji/models/word.dart';
import 'package:qingmang_weiji/models/word_book.dart';
import 'package:qingmang_weiji/models/review_record.dart';
import 'package:qingmang_weiji/utils/optional.dart';

void main() {
  group('Word 模型测试', () {
    test('Word.toMap() 和 fromMap() 往返转换', () {
      final word = Word(
        id: 1,
        word: 'test',
        phonetic: '/test/',
        definition: 'n. 测试',
        example: 'This is a test.',
        exampleTranslation: '这是一个测试。',
        wordBookId: 1,
        root: 'test',
        suffix: null,
        synonym: 'exam',
        antonym: null,
        derivative: 'testing',
      );

      final map = word.toMap();
      final restored = Word.fromMap(map);

      expect(restored.word, equals('test'));
      expect(restored.phonetic, equals('/test/'));
      expect(restored.definition, equals('n. 测试'));
      expect(restored.example, equals('This is a test.'));
      expect(restored.synonym, equals('exam'));
    });

    test('Word.copyWith() 创建副本', () {
      final original = Word(word: 'original', definition: '原始的', wordBookId: 1);

      final copy = original.copyWith(
        definition: '修改后的',
        example: Optional('A sentence.'),
      );

      expect(copy.word, equals('original'));
      expect(copy.definition, equals('修改后的'));
      expect(copy.example, equals('A sentence.'));
      expect(original.definition, equals('原始的')); // 原始不受影响
    });
  });

  group('WordBook 模型测试', () {
    test('WordBook.toMap() 和 fromMap() 往返转换', () {
      final book = WordBook(
        id: 1,
        name: 'CET-4',
        description: '大学英语四级词汇',
        isBuiltIn: true,
        totalWords: 1000,
        version: '1.0.0',
      );

      final map = book.toMap();
      final restored = WordBook.fromMap(map);

      expect(restored.name, equals('CET-4'));
      expect(restored.isBuiltIn, equals(true));
      expect(restored.totalWords, equals(1000));
    });
  });

  group('ReviewRecord 模型测试', () {
    test('ReviewRecord.toMap() 和 fromMap() 往返转换', () {
      final record = ReviewRecord(
        id: 1,
        wordId: 10,
        quality: 4,
        interval: 7,
        easeFactor: 2.5,
        repetitions: 3,
        nextReview: DateTime(2024, 6, 1),
        lastReview: DateTime(2024, 5, 25),
      );

      final map = record.toMap();
      final restored = ReviewRecord.fromMap(map);

      expect(restored.wordId, equals(10));
      expect(restored.quality, equals(4));
      expect(restored.interval, equals(7));
      expect(restored.easeFactor, equals(2.5));
    });

    test('ReviewRecord.copyWith() 创建副本', () {
      final original = ReviewRecord(
        wordId: 1,
        quality: 3,
        interval: 4,
        easeFactor: 2.5,
        repetitions: 2,
        nextReview: DateTime(2024, 6, 1),
        lastReview: DateTime(2024, 5, 28),
      );

      final copy = original.copyWith(quality: 5, interval: 7, repetitions: 3);

      expect(copy.wordId, equals(1));
      expect(copy.quality, equals(5));
      expect(copy.interval, equals(7));
      expect(copy.repetitions, equals(3));
      expect(original.quality, equals(3)); // 原始不受影响
    });

    test('ReviewRecord 默认值', () {
      final record = ReviewRecord(
        wordId: 1,
        nextReview: DateTime.now(),
        lastReview: DateTime.now(),
      );

      expect(record.quality, equals(0));
      expect(record.interval, equals(1));
      expect(record.easeFactor, equals(2.5));
      expect(record.repetitions, equals(0));
    });
  });
}
