import 'word.dart';

/// 收藏来源：仅用于收藏夹里的来源标签与统计，不参与任何去重逻辑
enum FavoriteSource {
  /// 学习/测验模式里收藏的
  study,

  /// 阅读模式里收藏的
  reader,

  /// 首页快捷搜索里收藏的
  homeSearch;

  static FavoriteSource? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in FavoriteSource.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

/// 收藏时间范围筛选（收藏夹的筛选胶囊）
///
/// 全部按**自然日**计算，而不是"过去 N×24 小时"：胶囊上写的是"今天 / 近 7 天"，
/// 用户对它的理解就是日历上的今天与最近 N 个自然日。
enum FavoriteTimeRange {
  all,
  today,
  last7Days,
  last30Days;

  /// 无法识别（含旧数据 / null）时按「全部」处理，不做激进降级
  static FavoriteTimeRange tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return FavoriteTimeRange.all;
    for (final value in FavoriteTimeRange.values) {
      if (value.name == raw) return value;
    }
    return FavoriteTimeRange.all;
  }

  /// 起始时间点（含）；返回 null 表示不限制时间。
  ///
  /// "今天"指今天 00:00 起；"近 7 天"指今天在内的 7 个自然日（今天 00:00 - 6 天）。
  DateTime? since({DateTime? now}) {
    final base = now ?? DateTime.now();
    final startOfToday = DateTime(base.year, base.month, base.day);
    return switch (this) {
      FavoriteTimeRange.all => null,
      FavoriteTimeRange.today => startOfToday,
      //用日历构造而非 subtract(Duration)：绝对时长跨夏令时会推移 1 小时，
      //导致起点变成前一天 23:00 或当天 01:00，边界附近的收藏可能被误纳入/排除
      FavoriteTimeRange.last7Days => DateTime(base.year, base.month, base.day - 6),
      FavoriteTimeRange.last30Days => DateTime(
        base.year,
        base.month,
        base.day - 29,
      ),
    };
  }
}

/// 收藏夹条目
///
/// 收藏是**单词级、跨词库全局唯一**的（表 `word_favorites` 上 `word_id` UNIQUE）：
/// 同一个词无论在哪个词库、在学习模式还是阅读模式里收藏，都是同一条记录。
/// 这样「我的收藏」里不会出现两条一模一样的词，也便于一键专项复习。
class WordFavorite {
  final Word word;

  /// 首次收藏来源；旧数据可能为空
  final FavoriteSource? source;

  final DateTime createdAt;

  /// 预留字段，当前 UI 未使用
  final String? note;

  const WordFavorite({
    required this.word,
    required this.createdAt,
    this.source,
    this.note,
  });

  /// [row] 需要同时包含 `word_favorites` 的列与 `words` 的列
  factory WordFavorite.fromMap(Map<String, dynamic> row) {
    final rawCreated = row['created_at'];
    return WordFavorite(
      word: Word.fromMap(Map<String, dynamic>.from(row)),
      source: FavoriteSource.tryParse(row['source'] as String?),
      createdAt: rawCreated == null
          ? DateTime.now()
          : (DateTime.tryParse(rawCreated.toString()) ?? DateTime.now()),
      note: row['note'] as String?,
    );
  }
}

/// 收藏所属词库的汇总，用于收藏夹的「按词库筛选」胶囊
///
/// 只统计**确实有收藏**的词库：收藏横跨多个词库时，把没有任何收藏的词库也列出来
/// 没有意义（点进去必然是空的）。[count] 就是该词库下的收藏条数。
class FavoriteBookSummary {
  final int wordBookId;

  /// 词库名；词库已删除等情况下可能为空，由 UI 决定兜底显示
  final String name;

  final int count;

  const FavoriteBookSummary({
    required this.wordBookId,
    required this.name,
    required this.count,
  });

  factory FavoriteBookSummary.fromMap(Map<String, dynamic> row) =>
      FavoriteBookSummary(
        wordBookId: row['book_id'] as int,
        name: (row['book_name'] as String?)?.trim() ?? '',
        count: row['c'] as int? ?? 0,
      );
}
