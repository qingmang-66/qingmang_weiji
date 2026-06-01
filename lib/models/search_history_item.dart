/// 搜索历史记录
class SearchHistoryItem {
  final int? id;
  final String query;
  final DateTime createdAt;

  const SearchHistoryItem({
    this.id,
    required this.query,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'query': query,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory SearchHistoryItem.fromMap(Map<String, dynamic> map) {
    return SearchHistoryItem(
      id: map['id'] as int?,
      query: map['query'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
