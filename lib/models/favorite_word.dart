/// 收藏单词模型
///
/// 用于用户主动收集重要单词。每条记录关联一个单词（word_id），
/// 可附加分组名称与备注，并记录最近一次专项学习时间。
class FavoriteWord {
  /// 收藏记录 ID
  final int? id;

  /// 关联的单词 ID
  final int wordId;

  /// 分组名称，可选；为空时归入「默认」分组
  final String groupName;

  /// 用户备注
  final String? note;

  /// 收藏时间
  final DateTime createdAt;

  /// 最近一次专项学习时间，可为空
  final DateTime? lastStudiedAt;

  const FavoriteWord({
    this.id,
    required this.wordId,
    this.groupName = '默认',
    this.note,
    required this.createdAt,
    this.lastStudiedAt,
  });

  /// 默认分组名
  static const String defaultGroup = '默认';

  /// 转为数据库 Map
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'word_id': wordId,
      'group_name': groupName,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'last_studied_at': lastStudiedAt?.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  /// 从数据库 Map 构造
  factory FavoriteWord.fromMap(Map<String, dynamic> map) {
    return FavoriteWord(
      id: map['id'] as int?,
      wordId: map['word_id'] as int,
      groupName: (map['group_name'] as String?) ?? defaultGroup,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastStudiedAt: map['last_studied_at'] != null
          ? DateTime.parse(map['last_studied_at'] as String)
          : null,
    );
  }

  FavoriteWord copyWith({
    int? id,
    int? wordId,
    String? groupName,
    String? note,
    DateTime? createdAt,
    DateTime? lastStudiedAt,
  }) {
    return FavoriteWord(
      id: id ?? this.id,
      wordId: wordId ?? this.wordId,
      groupName: groupName ?? this.groupName,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
    );
  }
}
