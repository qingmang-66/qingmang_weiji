/// 词库模型 - 支持版本管理
class WordBook {
  final int? id;
  final String name;
  final String description;
  final bool isBuiltIn;
  final int totalWords;
  final String? version; // 词库版本号

  WordBook({
    this.id,
    required this.name,
    this.description = '',
    this.isBuiltIn = false,
    this.totalWords = 0,
    this.version,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'is_built_in': isBuiltIn ? 1 : 0,
        'total_words': totalWords,
        'version': version,
      };

  factory WordBook.fromMap(Map<String, dynamic> map) => WordBook(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        isBuiltIn: map['is_built_in'] == 1,
        totalWords: map['total_words'] as int? ?? 0,
        version: map['version'] as String?,
      );

  WordBook copyWith({
    int? id,
    String? name,
    String? description,
    bool? isBuiltIn,
    int? totalWords,
    String? version,
  }) =>
      WordBook(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        isBuiltIn: isBuiltIn ?? this.isBuiltIn,
        totalWords: totalWords ?? this.totalWords,
        version: version ?? this.version,
      );
}