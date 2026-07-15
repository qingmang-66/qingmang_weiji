/// 收藏夹列表排序方式
enum FavoriteSortMode {
  /// 最近收藏在前（默认）
  createdDesc,

  /// 字母 A→Z
  wordAsc,

  /// 最近复习在前（未复习的置底）
  lastStudiedDesc,
}
