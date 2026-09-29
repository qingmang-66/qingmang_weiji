import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'daos/wrong_word_dao.dart';
import 'database_service.dart';

/// 错词本服务
/// 自动收集学习时标记为"忘记"或"模糊"的单词
///
/// 数据库操作委托给 WrongWordDao，本类仅负责业务逻辑
class WrongWordService {
  WrongWordService._();
  static final WrongWordService _instance = WrongWordService._();
  factory WrongWordService() => _instance;

  Future<void> init() async {}

  /// 添加错词
  Future<void> addWrongWord(int wordId, {String? note}) async {
    try {
      await DatabaseService.wrongWordDao.addWrongWord(wordId, note: note);
    } catch (e) {
      debugPrint('添加错词失败：$e');
      rethrow;
    }
  }

  /// 获取所有错词
  Future<List<Word>> getWrongWords({int? limit}) =>
      DatabaseService.wrongWordDao.getWrongWords(limit: limit);

  /// 获取错词数量
  Future<int> getWrongWordCount() =>
      DatabaseService.wrongWordDao.getWrongWordCount();

  /// 获取错词错误次数
  Future<int> getWrongCount(int wordId) =>
      DatabaseService.wrongWordDao.getWrongCount(wordId);

  /// 从错词本移除（标记为已掌握）
  Future<void> removeWrongWord(int wordId) =>
      DatabaseService.wrongWordDao.removeWrongWord(wordId);

  /// 批量移除错词
  Future<void> removeWrongWords(List<int> wordIds) =>
      DatabaseService.wrongWordDao.removeWrongWords(wordIds);

  /// 更新错词备注
  Future<void> updateNote(int wordId, String note) =>
      DatabaseService.wrongWordDao.updateNote(wordId, note);

  Future<void> addStrengthEvent({
    required int wordId,
    required bool isWrong,
    bool viewedAnswer = false,
    String? reviewMode,
  }) => DatabaseService.wrongWordDao.addStrengthEvent(
    wordId: wordId,
    isWrong: isWrong,
    viewedAnswer: viewedAnswer,
    reviewMode: reviewMode,
  );

  Future<void> updateStrength(int wordId, double strength) =>
      DatabaseService.wrongWordDao.updateStrength(wordId, strength);

  /// 获取错词统计
  Future<Map<String, dynamic>> getWrongWordStats() =>
      DatabaseService.wrongWordDao.getWrongWordStats();

  /// 获取今日新增错词
  Future<List<Word>> getTodayWrongWords() =>
      DatabaseService.wrongWordDao.getTodayWrongWords();

  Future<List<Word>> getWrongWordsByIds(List<int> wordIds) =>
      DatabaseService.wrongWordDao.getWrongWordsByIds(wordIds);

  Future<void> applyReviewResult(WrongWordReviewResult result) async {
    if (result.shouldSuggestMastered) {
      await removeWrongWord(result.wordId);
      return;
    }

    if (result.shouldStrengthen) {
      await addWrongWord(result.wordId);
      return;
    }

    //答对：错误次数 -1，连续答对写入内存语义的绝对值（答错清零后重算），
    //避免"先答错再答对"时在旧库值上 +1 虚增 streak
    await DatabaseService.wrongWordDao.applyCorrectReview(
      result.wordId,
      correctStreak: result.nextCorrectStreak,
    );
  }

  /// 全部错词的连续答对次数，用于进入错词专项复习时载入进度基准
  Future<Map<int, int>> getCorrectStreaks() =>
      DatabaseService.wrongWordDao.getCorrectStreaks();

  /// 错因聚合（错题集标签与按错因筛选）
  Future<Map<int, WrongWordCauseAggregate>> getCauseAggregates(
    List<int> wordIds,
  ) => DatabaseService.wrongWordDao.getCauseAggregates(wordIds);

  /// 撤销"标记已掌握"：按快照原样回插，保留错误次数与连续答对进度
  Future<void> restoreWrongWords(List<WrongWordSnapshot> snapshots) =>
      DatabaseService.wrongWordDao.restoreWrongWords(snapshots);

  Future<void> applyReviewResults(List<WrongWordReviewResult> results) async {
    if (results.isEmpty) return;
    //按动作分组后单事务批量写入：逐词各开一个事务时，一场复习要付几十次 fsync
    final removeIds = <int>[];
    final strengthenIds = <int>[];
    final correctStreaks = <int, int>{};
    for (final result in results) {
      if (result.shouldSuggestMastered) {
        removeIds.add(result.wordId);
      } else if (result.shouldStrengthen) {
        strengthenIds.add(result.wordId);
      } else {
        //写入内存语义的绝对值（含本次会话内的答错清零），不是在库值上 +1
        correctStreaks[result.wordId] = result.nextCorrectStreak;
      }
    }
    await DatabaseService.wrongWordDao.applyReviewResultsBatch(
      removeIds: removeIds,
      strengthenIds: strengthenIds,
      correctStreaks: correctStreaks,
    );
  }

  // ========== 阶段四：高频错词排行 - 透传方法 ==========

  /// 拉取错词 + word 详情 + wrong_words 元数据
  Future<List<WrongWordMetaRow>> getAllWrongWordsWithMeta() async {
    try {
      return await DatabaseService.wrongWordDao.getAllWithMeta();
    } catch (e) {
      debugPrint('WrongWordService.getAllWrongWordsWithMeta error: $e');
      rethrow;
    }
  }

  /// 聚合 strength 表的查看答案次数与最近复习是否再错
  Future<Map<int, WrongWordStrengthAggregate>> getStrengthAggregates(
    List<int> wordIds,
  ) async {
    if (wordIds.isEmpty) return {};
    try {
      return await DatabaseService.wrongWordDao.getStrengthAggregates(wordIds);
    } catch (e) {
      debugPrint('WrongWordService.getStrengthAggregates error: $e');
      rethrow;
    }
  }
}
