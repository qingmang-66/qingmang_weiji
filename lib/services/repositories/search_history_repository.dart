import '../../models/search_history_item.dart';
import '../database_service.dart';

/// 搜索历史仓库
class SearchHistoryRepository {
  Future<void> record(String query) =>
      DatabaseService.searchHistoryDao.record(query);

  Future<List<SearchHistoryItem>> recent({int limit = 10}) =>
      DatabaseService.searchHistoryDao.recent(limit: limit);

  Future<void> clear() => DatabaseService.searchHistoryDao.clear();

  Future<void> deleteOne(String query) =>
      DatabaseService.searchHistoryDao.deleteOne(query);
}
