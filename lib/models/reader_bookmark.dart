/// 阅读模式书签命名方式
enum ReaderBookmarkNaming { word, number, custom }

/// 阅读模式书签
class ReaderBookmark {
  final int id;
  final int wordBookId;
  //词在书中的序号，与分页无关，改字体后位置依然有效
  final int wordIndex;

  /// 创建书签时该位置的单词文本（旧数据为 null）。
  ///
  /// 词库重新导入/词序变化后 `wordIndex` 会静默指向另一个词；有了文本
  /// 快照，书签面板可以提示"词序已变化"，而不是把用户带到错误的词。
  final String? wordText;
  final String? customName;
  final DateTime createdAt;

  const ReaderBookmark({
    required this.id,
    required this.wordBookId,
    required this.wordIndex,
    this.wordText,
    this.customName,
    required this.createdAt,
  });

  factory ReaderBookmark.fromMap(Map<String, dynamic> map) {
    return ReaderBookmark(
      id: map['id'] as int,
      wordBookId: map['word_book_id'] as int,
      wordIndex: map['word_index'] as int,
      wordText: map['word_text'] as String?,
      customName: map['custom_name'] as String?,
      //时间容错：备份导入的脏数据/非法串不应让书签列表整体解析失败
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word_book_id': wordBookId,
      'word_index': wordIndex,
      'word_text': wordText,
      'custom_name': customName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
