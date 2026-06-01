import 'package:flutter/foundation.dart';
import '../models/models.dart';
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

    await DatabaseService.wrongWordDao.reduceWrongCount(result.wordId);
  }

  Future<void> applyReviewResults(List<WrongWordReviewResult> results) async {
    for (final result in results) {
      await applyReviewResult(result);
    }
  }
}
