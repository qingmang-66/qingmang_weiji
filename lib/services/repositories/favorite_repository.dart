import 'package:flutter/foundation.dart';
import '../../models/favorite_word.dart';
import '../../models/word.dart';
import '../database_service.dart';

/// 收藏夹仓库
///
/// 对外暴露收藏夹相关的高层操作，封装 DAO 细节并提供错误日志。
class FavoriteRepository {
  Future<int> addFavorite({
    required int wordId,
    String groupName = FavoriteWord.defaultGroup,
    String? note,
  }) async {
    try {
      return await DatabaseService.favoriteDao.addFavorite(
        wordId: wordId,
        groupName: groupName,
        note: note,
      );
    } catch (e) {
      debugPrint('FavoriteRepository.addFavorite error: $e');
      rethrow;
    }
  }

  Future<void> removeFavorite(int wordId) =>
      DatabaseService.favoriteDao.removeFavorite(wordId);

  Future<void> removeFavorites(List<int> wordIds) =>
      DatabaseService.favoriteDao.removeFavorites(wordIds);

  Future<bool> isFavorite(int wordId) =>
      DatabaseService.favoriteDao.isFavorite(wordId);

  Future<List<FavoriteWord>> getAllFavorites({String? groupName}) =>
      DatabaseService.favoriteDao.getAllFavorites(groupName: groupName);

  Future<List<Word>> getFavoriteWords({String? groupName}) =>
      DatabaseService.favoriteDao.getFavoriteWords(groupName: groupName);

  Future<int> getFavoriteCount() =>
      DatabaseService.favoriteDao.getFavoriteCount();

  Future<List<MapEntry<String, int>>> getGroups() =>
      DatabaseService.favoriteDao.getGroups();

  Future<void> updateGroup(int wordId, String groupName) =>
      DatabaseService.favoriteDao.updateGroup(wordId, groupName);

  Future<void> updateNote(int wordId, String? note) =>
      DatabaseService.favoriteDao.updateNote(wordId, note);

  Future<void> updateLastStudiedAt(List<int> wordIds, DateTime when) =>
      DatabaseService.favoriteDao.updateLastStudiedAt(wordIds, when);
}
