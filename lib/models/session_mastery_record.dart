/// 会话掌握记录模型 - 支持跨天持久化
class SessionMasteryRecord {
  final int? id;
  final int wordId;
  final String date; // YYYY-MM-DD格式
  final double sessionScore;
  final int attemptCount;
  final int wrongCount;
  final int revealCount;
  final int retryCount;
  final int correctStreak;
  final double bestModeWeight;
  final bool hasHighWeightVerification;
  final bool hasOnlyRecallVerification;
  final bool hasOnlyQuizVerification;
  final DateTime createdAt;

  SessionMasteryRecord({
    this.id,
    required this.wordId,
    required this.date,
    required this.sessionScore,
    required this.attemptCount,
    required this.wrongCount,
    required this.revealCount,
    required this.retryCount,
    required this.correctStreak,
    required this.bestModeWeight,
    required this.hasHighWeightVerification,
    required this.hasOnlyRecallVerification,
    required this.hasOnlyQuizVerification,
    required this.createdAt,
  });

  /// 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'word_id': wordId,
      'date': date,
      'session_score': sessionScore,
      'attempt_count': attemptCount,
      'wrong_count': wrongCount,
      'reveal_count': revealCount,
      'retry_count': retryCount,
      'correct_streak': correctStreak,
      'best_mode_weight': bestModeWeight,
      'has_high_weight_verification': hasHighWeightVerification ? 1 : 0,
      'has_only_recall_verification': hasOnlyRecallVerification ? 1 : 0,
      'has_only_quiz_verification': hasOnlyQuizVerification ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// 从数据库Map创建
  factory SessionMasteryRecord.fromMap(Map<String, dynamic> map) {
    // 字段一律容错：备份导入/旧版本数据可能出现 NULL、num 类型偏差，
    // 硬转型（as int / as num / DateTime.parse）会让整批记录解析失败
    int asInt(String key, [int fallback = 0]) {
      final v = map[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return fallback;
    }

    double asDouble(String key, [double fallback = 0]) {
      final v = map[key];
      if (v is num) return v.toDouble();
      return fallback;
    }

    return SessionMasteryRecord(
      id: map['id'] as int?,
      wordId: asInt('word_id'),
      date: (map['date'] as String?) ?? '',
      sessionScore: asDouble('session_score'),
      attemptCount: asInt('attempt_count'),
      wrongCount: asInt('wrong_count'),
      revealCount: asInt('reveal_count'),
      retryCount: asInt('retry_count'),
      correctStreak: asInt('correct_streak'),
      bestModeWeight: asDouble('best_mode_weight'),
      hasHighWeightVerification: asInt('has_high_weight_verification') == 1,
      hasOnlyRecallVerification: asInt('has_only_recall_verification') == 1,
      hasOnlyQuizVerification: asInt('has_only_quiz_verification') == 1,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// 复制并修改部分字段
  SessionMasteryRecord copyWith({
    int? id,
    int? wordId,
    String? date,
    double? sessionScore,
    int? attemptCount,
    int? wrongCount,
    int? revealCount,
    int? retryCount,
    int? correctStreak,
    double? bestModeWeight,
    bool? hasHighWeightVerification,
    bool? hasOnlyRecallVerification,
    bool? hasOnlyQuizVerification,
    DateTime? createdAt,
  }) {
    return SessionMasteryRecord(
      id: id ?? this.id,
      wordId: wordId ?? this.wordId,
      date: date ?? this.date,
      sessionScore: sessionScore ?? this.sessionScore,
      attemptCount: attemptCount ?? this.attemptCount,
      wrongCount: wrongCount ?? this.wrongCount,
      revealCount: revealCount ?? this.revealCount,
      retryCount: retryCount ?? this.retryCount,
      correctStreak: correctStreak ?? this.correctStreak,
      bestModeWeight: bestModeWeight ?? this.bestModeWeight,
      hasHighWeightVerification:
          hasHighWeightVerification ?? this.hasHighWeightVerification,
      hasOnlyRecallVerification:
          hasOnlyRecallVerification ?? this.hasOnlyRecallVerification,
      hasOnlyQuizVerification:
          hasOnlyQuizVerification ?? this.hasOnlyQuizVerification,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
