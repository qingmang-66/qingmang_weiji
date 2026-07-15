import 'package:flutter/foundation.dart';
import '../../models/custom_word_set.dart';
import '../../models/custom_word_set_item_sort_mode.dart';
import '../../models/custom_word_set_sort_mode.dart';
import '../../models/word.dart';
import '../database_service.dart';

/// 自定义单词集仓库
class CustomWordSetRepository {
  /// 创建词集
  Future<int> createSet({required String name, String? description}) async {
    try {
      final now = DateTime.now();
      final set = CustomWordSet(
        name: name,
        description: description,
        createdAt: now,
        updatedAt: now,
      );
      return await DatabaseService.customWordSetDao.createSet(set);
    } catch (e) {
      debugPrint('CustomWordSetRepository.createSet error: $e');
      rethrow;
    }
  }

  /// 重命名/修改描述
  Future<void> renameSet(
    CustomWordSet set,
    String name, {
    String? description,
  }) async {
    final updated = set.copyWith(
      name: name,
      description: description ?? set.description,
      updatedAt: DateTime.now(),
    );
    try {
      await DatabaseService.customWordSetDao.updateSet(updated);
    } catch (e) {
      debugPrint('CustomWordSetRepository.renameSet error: $e');
      rethrow;
    }
  }

  /// 删除词集
  Future<void> deleteSet(int setId) async {
    try {
      await DatabaseService.customWordSetDao.deleteSet(setId);
    } catch (e) {
      debugPrint('CustomWordSetRepository.deleteSet error: $e');
      rethrow;
    }
  }

  /// 获取全部词集（支持搜索 + 排序）
  Future<List<CustomWordSet>> getAllSets({
    String? query,
    CustomWordSetSortMode orderBy = CustomWordSetSortMode.updatedDesc,
  }) => DatabaseService.customWordSetDao.getAllSets(
    query: query,
    orderBy: orderBy,
  );

  /// 按 ID 获取词集
  Future<CustomWordSet?> getSet(int setId) async {
    try {
      return await DatabaseService.customWordSetDao.getSet(setId);
    } catch (e) {
      debugPrint('CustomWordSetRepository.getSet error: $e');
      rethrow;
    }
  }

  /// 批量加入单词
  Future<void> addWords(int setId, List<int> wordIds) async {
    try {
      await DatabaseService.customWordSetDao.addWords(setId, wordIds);
    } catch (e) {
      debugPrint('CustomWordSetRepository.addWords error: $e');
      rethrow;
    }
  }

  /// 批量移除单词
  Future<void> removeWords(int setId, List<int> wordIds) async {
    try {
      await DatabaseService.customWordSetDao.removeWords(setId, wordIds);
    } catch (e) {
      debugPrint('CustomWordSetRepository.removeWords error: $e');
      rethrow;
    }
  }

  /// 原子移动单词到其他词集
  Future<void> moveWords(
    int sourceSetId,
    int targetSetId,
    List<int> wordIds,
  ) async {
    try {
      await DatabaseService.customWordSetDao.moveWords(
        sourceSetId,
        targetSetId,
        wordIds,
      );
    } catch (e) {
      debugPrint('CustomWordSetRepository.moveWords error: $e');
      rethrow;
    }
  }

  /// 获取词集内单词（支持排序）
  Future<List<Word>> getWordsInSet(
    int setId, {
    CustomWordSetItemSortMode orderBy = CustomWordSetItemSortMode.addedAsc,
  }) => DatabaseService.customWordSetDao.getWordsInSet(setId, orderBy: orderBy);

  /// 获取词集内单词数量
  Future<int> getWordCount(int setId) =>
      DatabaseService.customWordSetDao.getWordCount(setId);

  /// 批量获取多个词集的单词数
  Future<Map<int, int>> getWordCounts(List<int> setIds) =>
      DatabaseService.customWordSetDao.getWordCounts(setIds);

  /// 判断单词是否已在词集中（阶段三：自定义词集增强新增）
  Future<bool> isWordInSet(int setId, int wordId) async {
    try {
      return await DatabaseService.customWordSetDao.isWordInSet(setId, wordId);
    } catch (e) {
      debugPrint('CustomWordSetRepository.isWordInSet error: $e');
      rethrow;
    }
  }

  /// 更新词集的学习时间（阶段三：自定义词集增强新增）
  Future<void> updateLastStudiedAt(int setId, DateTime when) async {
    try {
      await DatabaseService.customWordSetDao.updateLastStudiedAt(setId, when);
    } catch (e) {
      debugPrint('CustomWordSetRepository.updateLastStudiedAt error: $e');
      rethrow;
    }
  }
}
