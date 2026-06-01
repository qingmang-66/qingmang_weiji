/// 自定义单词集模型
///
/// 用户可创建多个专题词集（例如「商务英语」「单词易混淆词」），
/// 每个词集包含若干单词条目（CustomWordSetItem）。
class CustomWordSet {
  /// 单词集 ID
  final int? id;

  /// 名称
  final String name;

  /// 描述
  final String? description;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  const CustomWordSet({
    this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory CustomWordSet.fromMap(Map<String, dynamic> map) {
    return CustomWordSet(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  CustomWordSet copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomWordSet(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 单词集条目
class CustomWordSetItem {
  final int? id;
  final int setId;
  final int wordId;
  final int sortOrder;
  final DateTime addedAt;

  const CustomWordSetItem({
    this.id,
    required this.setId,
    required this.wordId,
    this.sortOrder = 0,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'set_id': setId,
      'word_id': wordId,
      'sort_order': sortOrder,
      'added_at': addedAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory CustomWordSetItem.fromMap(Map<String, dynamic> map) {
    return CustomWordSetItem(
      id: map['id'] as int?,
      setId: map['set_id'] as int,
      wordId: map['word_id'] as int,
      sortOrder: map['sort_order'] as int? ?? 0,
      addedAt: DateTime.parse(map['added_at'] as String),
    );
  }
}
