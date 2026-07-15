import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/models/models.dart';

void main() {
  // 阶段四：高频错词排行服务 - 纯逻辑/算法测试
  // 完整的数据库集成测试依赖 DatabaseService 初始化路径，
  // 适合在集成测试中覆盖（与 sqflite_common_ffi 一起），本文件聚焦纯逻辑。

  group('WrongWordRankingItem - 排序契约', () {
    test('score 高的项排前面', () {
      final items = <WrongWordRankingItem>[
        WrongWordRankingItem(
          word: Word(id: 1, word: 'low', wordBookId: 1),
          wrongCount: 1,
          lastWrongTime: DateTime(2024, 1, 1),
          viewedAnswerCount: 0,
          latestReviewWrong: false,
          score: 10,
          breakdown: const WrongWordScoreBreakdown(
            wrongCountScore: 0,
            recencyScore: 0,
            viewedAnswerScore: 0,
            reviewWrongScore: 0,
            persistentScore: 0,
          ),
        ),
        WrongWordRankingItem(
          word: Word(id: 2, word: 'high', wordBookId: 1),
          wrongCount: 5,
          lastWrongTime: DateTime(2024, 2, 1),
          viewedAnswerCount: 0,
          latestReviewWrong: false,
          score: 50,
          breakdown: const WrongWordScoreBreakdown(
            wrongCountScore: 0,
            recencyScore: 0,
            viewedAnswerScore: 0,
            reviewWrongScore: 0,
            persistentScore: 0,
          ),
        ),
      ];
      items.sort((a, b) => b.score.compareTo(a.score));
      expect(items.first.word.word, 'high');
      expect(items.last.word.word, 'low');
    });

    test('score 相等时 last_wrong_time 较新的排前面', () {
      final items = <WrongWordRankingItem>[
        WrongWordRankingItem(
          word: Word(id: 1, word: 'old', wordBookId: 1),
          wrongCount: 1,
          lastWrongTime: DateTime(2024, 1, 1),
          viewedAnswerCount: 0,
          latestReviewWrong: false,
          score: 30,
          breakdown: const WrongWordScoreBreakdown(
            wrongCountScore: 0,
            recencyScore: 0,
            viewedAnswerScore: 0,
            reviewWrongScore: 0,
            persistentScore: 0,
          ),
        ),
        WrongWordRankingItem(
          word: Word(id: 2, word: 'recent', wordBookId: 1),
          wrongCount: 1,
          lastWrongTime: DateTime(2024, 3, 1),
          viewedAnswerCount: 0,
          latestReviewWrong: false,
          score: 30,
          breakdown: const WrongWordScoreBreakdown(
            wrongCountScore: 0,
            recencyScore: 0,
            viewedAnswerScore: 0,
            reviewWrongScore: 0,
            persistentScore: 0,
          ),
        ),
      ];
      items.sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return b.lastWrongTime.compareTo(a.lastWrongTime);
      });
      expect(items.first.word.word, 'recent');
      expect(items.last.word.word, 'old');
    });
  });
}
