import '../models/word_favorite.dart';
import 'daos/favorite_dao.dart';

/// 收藏夹服务
///
/// 刻意做得很薄：收藏没有"规则"（不像错词本有连续答对移出、弱词有评分），
/// 全部逻辑就是一张全局唯一的单词表，UI 直接调这里即可。
class FavoriteService {
  final FavoriteDao dao;

  const FavoriteService({required this.dao});

  /// 切换收藏，返回切换后是否已收藏
  Future<bool> toggleWord(int wordId, {FavoriteSource? source}) =>
      dao.toggle(wordId, source: source?.name);

  Future<void> addWord(int wordId, {FavoriteSource? source}) =>
      dao.add(wordId, source: source?.name);

  /// 批量收藏（错词页"加入收藏夹"、多选复习等场景）
  Future<int> addWords(List<int> wordIds, {FavoriteSource? source}) =>
      dao.addMany(wordIds, source: source?.name);

  Future<void> removeWord(int wordId) => dao.remove(wordId);

  Future<void> removeWords(List<int> wordIds) => dao.removeMany(wordIds);

  Future<void> clearAll() => dao.clear();

  Future<bool> isFavorite(int wordId) => dao.contains(wordId);

  /// 整批词的收藏状态（阅读器/学习页一次取回，避免 N+1 查询）
  Future<Set<int>> filterFavorited(Iterable<int> wordIds) =>
      dao.filterFavorited(wordIds);

  Future<Set<int>> getAllFavoriteWordIds() => dao.getFavoriteWordIds();

  /// 某词书内已收藏的单词 id（阅读器用）
  Future<Set<int>> getFavoriteWordIdsInBook(int wordBookId) =>
      dao.getFavoriteWordIdsInBook(wordBookId);

  Future<int> getCount() => dao.getCount();

  /// 收藏列表
  ///
  /// [keyword] 模糊匹配单词/释义，[source] / [wordBookId] / [timeRange] 为筛选条件，
  /// [ascending] 控制按收藏时间的排序方向（默认最新在前）。
  Future<List<WordFavorite>> getAll({
    String? keyword,
    FavoriteSource? source,
    int? wordBookId,
    FavoriteTimeRange timeRange = FavoriteTimeRange.all,
    bool ascending = false,
  }) => dao.getAll(
    keyword: keyword,
    source: source?.name,
    wordBookId: wordBookId,
    since: timeRange.since(),
    ascending: ascending,
  );

  /// 有收藏的词库汇总（按词库筛选胶囊用）
  Future<List<FavoriteBookSummary>> getBookSummaries() =>
      dao.getBookSummaries();

  Future<List<WordFavorite>> getByWordIds(List<int> wordIds) =>
      dao.getByIds(wordIds);
}
