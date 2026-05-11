/// 复习记录模型
class ReviewRecord {
  final int? id;
  final int wordId;
  final int quality;
  final int interval; // 间隔天数
  final double easeFactor;
  final int repetitions;
  final DateTime nextReview;
  final DateTime lastReview;

  ReviewRecord({
    this.id,
    required this.wordId,
    this.quality = 0,
    this.interval = 1,
    this.easeFactor = 2.5,
    this.repetitions = 0,
    required this.nextReview,
    required this.lastReview,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'word_id': wordId,
      'quality': quality,
      'interval': interval,
      'ease_factor': easeFactor,
      'repetitions': repetitions,
      'next_review': nextReview.toIso8601String(),
      'last_review': lastReview.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory ReviewRecord.fromMap(Map<String, dynamic> map) => ReviewRecord(
        id: map['id'] as int?,
        wordId: map['word_id'] as int,
        quality: map['quality'] as int? ?? 0,
        interval: map['interval'] as int? ?? 1,
        easeFactor: map['ease_factor'] as double? ?? 2.5,
        repetitions: map['repetitions'] as int? ?? 0,
        nextReview: DateTime.parse(map['next_review'] as String),
        lastReview: DateTime.parse(map['last_review'] as String),
      );

  ReviewRecord copyWith({
    int? id,
    int? wordId,
    int? quality,
    int? interval,
    double? easeFactor,
    int? repetitions,
    DateTime? nextReview,
    DateTime? lastReview,
  }) =>
      ReviewRecord(
        id: id ?? this.id,
        wordId: wordId ?? this.wordId,
        quality: quality ?? this.quality,
        interval: interval ?? this.interval,
        easeFactor: easeFactor ?? this.easeFactor,
        repetitions: repetitions ?? this.repetitions,
        nextReview: nextReview ?? this.nextReview,
        lastReview: lastReview ?? this.lastReview,
      );
}
