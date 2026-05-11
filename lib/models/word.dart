/// 单词模型 - 增强版
class Word {
  final int? id;
  final String word;
  final String phonetic;
  final String definition;
  final String? example;
  final String? exampleTranslation;
  final int wordBookId;
  final String? root;           // 词根
  final String? suffix;        // 词缀
  final String? synonym;       // 同义词
  final String? antonym;        // 反义词
  final String? derivative;     // 派生词

  Word({
    this.id,
    required this.word,
    this.phonetic = '',
    this.definition = '',
    this.example,
    this.exampleTranslation,
    required this.wordBookId,
    this.root,
    this.suffix,
    this.synonym,
    this.antonym,
    this.derivative,
  });

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

  Word copyWith({
    int? id,
    String? word,
    String? phonetic,
    String? definition,
    String? example,
    String? exampleTranslation,
    int? wordBookId,
    String? root,
    String? suffix,
    String? synonym,
    String? antonym,
    String? derivative,
  }) =>
      Word(
        id: id ?? this.id,
        word: word ?? this.word,
        phonetic: phonetic ?? this.phonetic,
        definition: definition ?? this.definition,
        example: example ?? this.example,
        exampleTranslation: exampleTranslation ?? this.exampleTranslation,
        wordBookId: wordBookId ?? this.wordBookId,
        root: root ?? this.root,
        suffix: suffix ?? this.suffix,
        synonym: synonym ?? this.synonym,
        antonym: antonym ?? this.antonym,
        derivative: derivative ?? this.derivative,
      );
}
