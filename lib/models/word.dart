// 单词模型 - 增强版
import '../utils/optional.dart';
import '../utils/phonetic_utils.dart';

class Word {
  final int? id;
  final String word;
  final String phonetic;
  final String definition;
  final String? example;
  final String? exampleTranslation;
  final int wordBookId;
  final String? root; // 词根
  final String? suffix; // 词缀
  final String? synonym; // 同义词
  final String? antonym; // 反义词
  final String? derivative; // 派生词

  Word({
    this.id,
    required this.word,
    String phonetic = '',
    this.definition = '',
    this.example,
    this.exampleTranslation,
    required this.wordBookId,
    this.root,
    this.suffix,
    this.synonym,
    this.antonym,
    this.derivative,
  }) : //词库源数据可能带多个读音/用途注释，统一只保留主读音，避免界面重复展示
       phonetic = PhoneticUtils.primary(phonetic);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'word': word,
      'phonetic': phonetic,
      'definition': definition,
      'example': example,
      'example_translation': exampleTranslation,
      'word_book_id': wordBookId,
      'root': root,
      'suffix': suffix,
      'synonym': synonym,
      'antonym': antonym,
      'derivative': derivative,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Word.fromMap(Map<String, dynamic> map) => Word(
    id: map['id'] as int?,
    word: map['word'] as String,
    phonetic: map['phonetic'] as String? ?? '',
    definition: map['definition'] as String? ?? '',
    example: map['example'] as String?,
    exampleTranslation: map['example_translation'] as String?,
    wordBookId: map['word_book_id'] as int,
    root: map['root'] as String?,
    suffix: map['suffix'] as String?,
    synonym: map['synonym'] as String?,
    antonym: map['antonym'] as String?,
    derivative: map['derivative'] as String?,
  );

  /// copyWith：可空字段使用 Optional 包装，支持显式设为 null
  /// 不传参数 → 不修改；传 Optional(null) → 设为 null；传 Optional(value) → 设为新值
  Word copyWith({
    int? id,
    String? word,
    String? phonetic,
    String? definition,
    Optional<String?>? example,
    Optional<String?>? exampleTranslation,
    int? wordBookId,
    Optional<String?>? root,
    Optional<String?>? suffix,
    Optional<String?>? synonym,
    Optional<String?>? antonym,
    Optional<String?>? derivative,
  }) => Word(
    id: id ?? this.id,
    word: word ?? this.word,
    phonetic: phonetic ?? this.phonetic,
    definition: definition ?? this.definition,
    example: example != null ? example.value : this.example,
    exampleTranslation: exampleTranslation != null
        ? exampleTranslation.value
        : this.exampleTranslation,
    wordBookId: wordBookId ?? this.wordBookId,
    root: root != null ? root.value : this.root,
    suffix: suffix != null ? suffix.value : this.suffix,
    synonym: synonym != null ? synonym.value : this.synonym,
    antonym: antonym != null ? antonym.value : this.antonym,
    derivative: derivative != null ? derivative.value : this.derivative,
  );
}
