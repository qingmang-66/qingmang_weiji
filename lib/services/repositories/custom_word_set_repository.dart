import 'package:flutter/foundation.dart';
import '../../models/custom_word_set.dart';
import '../../models/word.dart';
import '../database_service.dart';

/// 自定义单词集仓库
class CustomWordSetRepository {
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
    await DatabaseService.customWordSetDao.updateSet(updated);
  }

  Future<void> deleteSet(int setId) =>
      DatabaseService.customWordSetDao.deleteSet(setId);

  Future<List<CustomWordSet>> getAllSets() =>
      DatabaseService.customWordSetDao.getAllSets();

  Future<CustomWordSet?> getSet(int setId) =>
      DatabaseService.customWordSetDao.getSet(setId);

  Future<void> addWords(int setId, List<int> wordIds) =>
      DatabaseService.customWordSetDao.addWords(setId, wordIds);

  Future<void> removeWords(int setId, List<int> wordIds) =>
      DatabaseService.customWordSetDao.removeWords(setId, wordIds);

  Future<List<Word>> getWordsInSet(int setId) =>
      DatabaseService.customWordSetDao.getWordsInSet(setId);

  Future<int> getWordCount(int setId) =>
      DatabaseService.customWordSetDao.getWordCount(setId);

  Future<Map<int, int>> getWordCounts(List<int> setIds) =>
      DatabaseService.customWordSetDao.getWordCounts(setIds);
}
