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
  final DateTime? firstLearnedAt; // 首次学习时间，用于区分今日新学/复习

  ReviewRecord({
    this.id,
    required this.wordId,
    this.quality = 0,
    this.interval = 1,
    this.easeFactor = 2.5,
    this.repetitions = 0,
    required this.nextReview,
    required this.lastReview,
    this.firstLearnedAt,
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
    // null 时交由 DAO 决定（首次插入写当前时间或沿用库中已有值）
    if (firstLearnedAt != null) {
      map['first_learned_at'] = firstLearnedAt!.toIso8601String();
    }
    return map;
  }

  factory ReviewRecord.fromMap(Map<String, dynamic> map) => ReviewRecord(
    id: map['id'] as int?,
    wordId: (map['word_id'] as int?) ?? 0,
    quality: map['quality'] as int? ?? 0,
    interval: map['interval'] as int? ?? 1,
    easeFactor: (map['ease_factor'] as num?)?.toDouble() ?? 2.5,
    repetitions: map['repetitions'] as int? ?? 0,
    //时间字段一律容错：备份导入的脏数据（缺字段/NULL/非法串）不应让整批
    //复习记录解析抛错——复习主链路会整体失败
    nextReview: _parseDateOrNow(map['next_review']),
    lastReview: _parseDateOrNow(map['last_review']),
    firstLearnedAt: map['first_learned_at'] == null
        ? null
        : DateTime.tryParse(map['first_learned_at'] as String),
  );

  /// 容错解析时间戳，失败按当前时间（仅用于脏数据兜底，正常数据总有值）
  static DateTime _parseDateOrNow(Object? value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  ReviewRecord copyWith({
    int? id,
    int? wordId,
    int? quality,
    int? interval,
    double? easeFactor,
    int? repetitions,
    DateTime? nextReview,
    DateTime? lastReview,
    DateTime? firstLearnedAt,
    bool clearFirstLearnedAt = false,
  }) => ReviewRecord(
    id: id ?? this.id,
    wordId: wordId ?? this.wordId,
    quality: quality ?? this.quality,
    interval: interval ?? this.interval,
    easeFactor: easeFactor ?? this.easeFactor,
    repetitions: repetitions ?? this.repetitions,
    nextReview: nextReview ?? this.nextReview,
    lastReview: lastReview ?? this.lastReview,
    firstLearnedAt: clearFirstLearnedAt
        ? null
        : (firstLearnedAt ?? this.firstLearnedAt),
  );
}
