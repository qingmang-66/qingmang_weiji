import 'package:flutter/foundation.dart';
import '../../models/favorite_sort_mode.dart';
import '../../models/favorite_word.dart';
import '../../models/word.dart';
import '../database_service.dart';

/// 收藏夹仓库
///
/// 对外暴露收藏夹相关的高层操作，封装 DAO 细节并提供错误日志。
class FavoriteRepository {
  /// 添加收藏（已存在则更新 groupName / note）
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

  /// 移除单个收藏
  Future<void> removeFavorite(int wordId) async {
    try {
      await DatabaseService.favoriteDao.removeFavorite(wordId);
    } catch (e) {
      debugPrint('FavoriteRepository.removeFavorite error: $e');
      rethrow;
    }
  }

  /// 批量移除收藏
  Future<void> removeFavorites(List<int> wordIds) async {
    try {
      await DatabaseService.favoriteDao.removeFavorites(wordIds);
    } catch (e) {
      debugPrint('FavoriteRepository.removeFavorites error: $e');
      rethrow;
    }
  }

  /// 是否已收藏
  Future<bool> isFavorite(int wordId) =>
      DatabaseService.favoriteDao.isFavorite(wordId);

  /// 根据 wordId 获取收藏元数据
  Future<FavoriteWord?> getByWordId(int wordId) async {
    try {
      return await DatabaseService.favoriteDao.getByWordId(wordId);
    } catch (e) {
      debugPrint('FavoriteRepository.getByWordId error: $e');
      rethrow;
    }
  }

  /// 获取所有收藏记录
  Future<List<FavoriteWord>> getAllFavorites({String? groupName}) =>
      DatabaseService.favoriteDao.getAllFavorites(groupName: groupName);

  /// 获取收藏的单词详情（带排序）
  Future<List<Word>> getFavoriteWords({
    String? groupName,
    FavoriteSortMode orderBy = FavoriteSortMode.createdDesc,
  }) => DatabaseService.favoriteDao.getFavoriteWords(
    groupName: groupName,
    orderBy: orderBy,
  );

  /// 收藏总数
  Future<int> getFavoriteCount() =>
      DatabaseService.favoriteDao.getFavoriteCount();

  /// 所有分组及计数
  Future<List<MapEntry<String, int>>> getGroups() =>
      DatabaseService.favoriteDao.getGroups();

  /// 更新单个收藏的分组
  Future<void> updateGroup(int wordId, String groupName) =>
      DatabaseService.favoriteDao.updateGroup(wordId, groupName);

  /// 批量更新分组
  Future<void> updateGroupBatch(List<int> wordIds, String groupName) async {
    try {
      await DatabaseService.favoriteDao.updateGroupBatch(wordIds, groupName);
    } catch (e) {
      debugPrint('FavoriteRepository.updateGroupBatch error: $e');
      rethrow;
    }
  }

  /// 更新备注
  Future<void> updateNote(int wordId, String? note) =>
      DatabaseService.favoriteDao.updateNote(wordId, note);

  /// 更新最近学习时间
  Future<void> updateLastStudiedAt(List<int> wordIds, DateTime when) =>
      DatabaseService.favoriteDao.updateLastStudiedAt(wordIds, when);
}
