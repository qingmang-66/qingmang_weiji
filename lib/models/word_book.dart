// 词库模型 - 支持版本管理和排序
import '../utils/optional.dart';

class WordBook {
  final int? id;
  final String name;
  final String description;
  final bool isBuiltIn;
  final int totalWords;
  final String? version; // 词库版本号
  final int sortOrder; // 排序顺序，数值越小越靠前

  WordBook({
    this.id,
    required this.name,
    this.description = '',
    this.isBuiltIn = false,
    this.totalWords = 0,
    this.version,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'is_built_in': isBuiltIn ? 1 : 0,
    'total_words': totalWords,
    'version': version,
    'sort_order': sortOrder,
  };

  factory WordBook.fromMap(Map<String, dynamic> map) => WordBook(
    id: map['id'] as int?,
    name: map['name'] as String,
    description: map['description'] as String? ?? '',
    isBuiltIn: map['is_built_in'] == 1,
    totalWords: map['total_words'] as int? ?? 0,
    version: map['version'] as String?,
    sortOrder: map['sort_order'] as int? ?? 0,
  );

  /// copyWith：可空字段使用 Optional 包装，支持显式设为 null
  WordBook copyWith({
    int? id,
    String? name,
    String? description,
    bool? isBuiltIn,
    int? totalWords,
    Optional<String?>? version,
    int? sortOrder,
  }) => WordBook(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    totalWords: totalWords ?? this.totalWords,
    version: version != null ? version.value : this.version,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}
