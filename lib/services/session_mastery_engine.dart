import 'dart:math';
import '../models/review_record.dart';
import '../models/session_mastery_record.dart';
import 'review_scheduler.dart';
import 'session_mastery_repository.dart';

enum StudyModeType { recall, spelling, listening, quiz }

enum StudyAttemptOutcome {
  firstCorrect,
  retryCorrect,
  wrong,
  revealed,
  recallForgot,
  recallVague,
  recallRemembered,
  recallEasy,
}

class SessionMasteryState {
  final int wordId;
  final double sessionScore;
  final int attemptCount;
  final int wrongCount;
  final int revealCount;
  final int retryCount;
  final int correctStreak;
  final StudyModeType? lastMode;
  final double bestModeWeight;
  final bool hasHighWeightVerification;
  final bool hasOnlyRecallVerification;
  final bool hasOnlyQuizVerification;

  const SessionMasteryState({
    required this.wordId,
    required this.sessionScore,
    required this.attemptCount,
    required this.wrongCount,
    required this.revealCount,
    required this.retryCount,
    required this.correctStreak,
    required this.lastMode,
    required this.bestModeWeight,
    required this.hasHighWeightVerification,
    required this.hasOnlyRecallVerification,
    required this.hasOnlyQuizVerification,
  });

  factory SessionMasteryState.initial(int wordId) {
    return SessionMasteryState(
      wordId: wordId,
      sessionScore: 0,
      attemptCount: 0,
      wrongCount: 0,
      revealCount: 0,
      retryCount: 0,
      correctStreak: 0,
      lastMode: null,
      bestModeWeight: 0,
      hasHighWeightVerification: false,
      hasOnlyRecallVerification: false,
      hasOnlyQuizVerification: false,
    );
  }

  bool get isMastered =>
      sessionScore >= 76 && wrongCount == 0 && revealCount == 0;

  bool get isStrongMastered => sessionScore >= 82 && bestModeWeight >= 0.92;

  bool get isWeak => sessionScore < 55 || wrongCount >= 2 || revealCount > 0;

  SessionMasteryState copyWith({
    double? sessionScore,
    int? attemptCount,
    int? wrongCount,
    int? revealCount,
    int? retryCount,
    int? correctStreak,
    StudyModeType? lastMode,
    double? bestModeWeight,
    bool? hasHighWeightVerification,
    bool? hasOnlyRecallVerification,
    bool? hasOnlyQuizVerification,
  }) {
    return SessionMasteryState(
      wordId: wordId,
      sessionScore: sessionScore ?? this.sessionScore,
      attemptCount: attemptCount ?? this.attemptCount,
      wrongCount: wrongCount ?? this.wrongCount,
      revealCount: revealCount ?? this.revealCount,
      retryCount: retryCount ?? this.retryCount,
      correctStreak: correctStreak ?? this.correctStreak,
      lastMode: lastMode ?? this.lastMode,
      bestModeWeight: bestModeWeight ?? this.bestModeWeight,
      hasHighWeightVerification:
          hasHighWeightVerification ?? this.hasHighWeightVerification,
      hasOnlyRecallVerification:
          hasOnlyRecallVerification ?? this.hasOnlyRecallVerification,
      hasOnlyQuizVerification:
          hasOnlyQuizVerification ?? this.hasOnlyQuizVerification,
    );
  }
}

class SessionMasteryEngine {
  static const double masteredThreshold = 76;
  static const double strongMasteredThreshold = 82;
  static const double weakThreshold = 55;
  static const double oldScoreWeight = 0.65;
  static const double newAttemptWeight = 0.35;

  // 答题耗时惩罚阈值
  static const double fastThresholdMultiplier = 0.3; // 秒答阈值：平均时间的30%
  static const double slowThresholdMultiplier = 2.5; // 慢答阈值：平均时间的2.5倍
  static const double fastWrongPenalty = 15.0; // 秒答答错额外惩罚
  static const double slowCorrectPenalty = 5.0; // 慢答答对轻微惩罚

  // 默认时间阈值（无历史数据时使用）
  static const double defaultFastThresholdMs = 1500.0; // 1.5秒内视为秒答
  static const double defaultSlowThresholdMs = 12500.0; // 12.5秒以上视为慢答

  // 答题时间历史记录上限（防止内存泄漏）
  static const int maxTimeHistorySize = 50;

  final Map<int, SessionMasteryState> _states = {};
  final Map<int, List<int>> _wordTimeHistory = {}; // 存储每个单词的答题时间（毫秒）
  final Set<int> _touchedWordIds = {}; // 记录本次会话中实际学习过的单词ID
  final SessionMasteryRepository _repository = SessionMasteryRepository();

  Map<int, SessionMasteryState> get states => Map.unmodifiable(_states);

  SessionMasteryState stateFor(int wordId) =>
      _states[wordId] ?? SessionMasteryState.initial(wordId);

  static double modeWeight(StudyModeType mode) {
    return switch (mode) {
      StudyModeType.spelling => 1.00,
      StudyModeType.listening => 0.92,
      StudyModeType.quiz => 0.72,
      StudyModeType.recall => 0.55,
    };
  }

  SessionMasteryState recordAttempt({
    required int wordId,
    required StudyModeType mode,
    required StudyAttemptOutcome outcome,
    ReviewRecord? reviewRecord,
  }) {
    final previous = stateFor(wordId);
    final weight = modeWeight(mode);
    final retentionWeight = _retentionWeight(reviewRecord);
    final nextWrongCount = previous.wrongCount + (_isWrong(outcome) ? 1 : 0);
    final nextRevealCount =
        previous.revealCount +
        (outcome == StudyAttemptOutcome.revealed ? 1 : 0);
    final nextRetryCount =
        previous.retryCount +
        (outcome == StudyAttemptOutcome.retryCorrect ? 1 : 0);
    final nextCorrectStreak = _isCorrect(outcome)
        ? previous.correctStreak + 1
        : 0;
    final attemptCount = previous.attemptCount + 1;
    final attemptScore = _attemptScore(
      outcome: outcome,
      mode: mode,
      retentionWeight: retentionWeight,
      wrongCount: nextWrongCount,
      revealCount: nextRevealCount,
      retryCount: nextRetryCount,
      correctStreak: nextCorrectStreak,
      attemptCount: attemptCount,
    );
    final nextScore = previous.attemptCount == 0
        ? attemptScore
        : previous.sessionScore * oldScoreWeight +
              attemptScore * newAttemptWeight;
    final nextBestModeWeight = _isCorrect(outcome)
        ? _max(previous.bestModeWeight, weight)
        : previous.bestModeWeight;
    final verifiedModes = <StudyModeType>{
      if (previous.lastMode != null) previous.lastMode!,
      mode,
    };
    final nextState = previous.copyWith(
      sessionScore: nextScore.clamp(0, 100),
      attemptCount: attemptCount,
      wrongCount: nextWrongCount,
      revealCount: nextRevealCount,
      retryCount: nextRetryCount,
      correctStreak: nextCorrectStreak,
      lastMode: mode,
      bestModeWeight: nextBestModeWeight,
      hasHighWeightVerification:
          previous.hasHighWeightVerification ||
          (_isCorrect(outcome) && weight >= 0.92),
      hasOnlyRecallVerification:
          verifiedModes.length == 1 &&
          verifiedModes.first == StudyModeType.recall,
      hasOnlyQuizVerification:
          verifiedModes.length == 1 &&
          verifiedModes.first == StudyModeType.quiz,
    );
    _states[wordId] = nextState;
    return nextState;
  }

  bool shouldSkipMainFlow(int wordId) => stateFor(wordId).isMastered;

  bool shouldStrengthen(int wordId) => stateFor(wordId).isWeak;

  int calculateReviewQuality(int wordId) {
    final state = stateFor(wordId);
    final readiness =
        state.sessionScore +
        state.bestModeWeight * 10 -
        state.revealCount * 15 -
        state.wrongCount * 10;
    var quality = switch (readiness) {
      >= 92 => 5,
      >= 78 => 4,
      >= 60 => 3,
      >= 40 => 2,
      _ => 1,
    };
    if (state.revealCount > 0) quality = quality.clamp(1, 2);
    if (state.wrongCount >= 2) quality = quality.clamp(1, 2);
    if (state.wrongCount == 1) quality = quality.clamp(1, 3);
    if (state.hasOnlyRecallVerification) quality = quality.clamp(1, 4);
    if (state.hasOnlyQuizVerification) quality = quality.clamp(1, 4);
    return quality;
  }

  static StudyModeType modeFromStudyMode(int studyMode) {
    return switch (studyMode) {
      2 => StudyModeType.spelling,
      3 => StudyModeType.listening,
      4 || 5 => StudyModeType.quiz,
      _ => StudyModeType.recall,
    };
  }

  /// 根据当前掌握状态推荐下一个学习模式
  /// 返回null表示应该跳过该词
  int? recommendNextMode({
    required int currentMode,
    required SessionMasteryState state,
    bool enableSpotCheck = false,
  }) {
    // 强掌握或已掌握 → 默认跳过
    if (state.isStrongMastered || state.isMastered) {
      // 低频抽查：5%概率随机抽查，使用拼写模式(最高权重)
      if (enableSpotCheck && Random().nextDouble() < 0.05) {
        return 2; // 拼写模式
      }
      return null; // 跳过
    }

    // 薄弱词 → 切换到高权重模式
    if (state.isWeak) {
      if (currentMode == 1) return 2; // 回忆→拼写
      if (currentMode == 4 || currentMode == 5) return 2; // 测验→拼写
      return currentMode; // 已在高权重模式，保持
    }

    // 学习中 → 保持当前模式
    return currentMode;
  }

  double _attemptScore({
    required StudyAttemptOutcome outcome,
    required StudyModeType mode,
    required double retentionWeight,
    required int wrongCount,
    required int revealCount,
    required int retryCount,
    required int correctStreak,
    required int attemptCount,
  }) {
    final base = _actionBase(outcome);
    final streakBonus = correctStreak >= 3 ? 10 : (correctStreak >= 2 ? 6 : 0);
    final wrongPenalty = wrongCount * 12;
    final revealPenalty = revealCount * 18;
    final retryPenalty = retryCount * 8;
    final repetitionPenalty = attemptCount >= 3 ? (attemptCount - 2) * 5 : 0;
    return base * modeWeight(mode) * retentionWeight +
        streakBonus -
        wrongPenalty -
        revealPenalty -
        retryPenalty -
        repetitionPenalty;
  }

  double _actionBase(StudyAttemptOutcome outcome) {
    return switch (outcome) {
      StudyAttemptOutcome.firstCorrect => 100,
      StudyAttemptOutcome.retryCorrect => 78,
      StudyAttemptOutcome.recallEasy => 88,
      StudyAttemptOutcome.recallRemembered => 72,
      StudyAttemptOutcome.recallVague => 38,
      StudyAttemptOutcome.recallForgot => 15,
      StudyAttemptOutcome.wrong => 28,
      StudyAttemptOutcome.revealed => 12,
    };
  }

  double _retentionWeight(ReviewRecord? record) {
    if (record == null) return 1.0;
    final retention = ReviewScheduler.estimateRetention(record);
    if (retention >= 85) return 0.92;
    if (retention >= 70) return 1.0;
    if (retention >= 45) return 1.10;
    return 1.05;
  }

  bool _isCorrect(StudyAttemptOutcome outcome) {
    return outcome == StudyAttemptOutcome.firstCorrect ||
        outcome == StudyAttemptOutcome.retryCorrect ||
        outcome == StudyAttemptOutcome.recallEasy ||
        outcome == StudyAttemptOutcome.recallRemembered;
  }

  bool _isWrong(StudyAttemptOutcome outcome) {
    return outcome == StudyAttemptOutcome.wrong ||
        outcome == StudyAttemptOutcome.recallForgot ||
        outcome == StudyAttemptOutcome.recallVague;
  }

  double _max(double a, double b) => a > b ? a : b;

  /// 记录答题尝试（带耗时）
  SessionMasteryState recordAttemptWithDuration({
    required int wordId,
    required StudyModeType mode,
    required StudyAttemptOutcome outcome,
    ReviewRecord? reviewRecord,
    required int durationMs, // 答题耗时（毫秒）
  }) {
    // 记录本次会话中实际学习过的单词
    _touchedWordIds.add(wordId);

    // 计算时间惩罚（使用当前历史记录，不包含本次答题时间）
    final timePenalty = _calculateTimePenalty(
      wordId: wordId,
      durationMs: durationMs,
      isCorrect: _isCorrect(outcome),
    );

    // 记录答题时间（带上限控制，防止内存泄漏）
    _wordTimeHistory.putIfAbsent(wordId, () => []);
    final history = _wordTimeHistory[wordId]!;
    history.add(durationMs);

    // 保留最近N条记录，删除旧数据
    if (history.length > maxTimeHistorySize) {
      history.removeRange(0, history.length - maxTimeHistorySize);
    }

    final previous = stateFor(wordId);
    final weight = modeWeight(mode);
    final retentionWeight = _retentionWeight(reviewRecord);
    final nextWrongCount = previous.wrongCount + (_isWrong(outcome) ? 1 : 0);
    final nextRevealCount =
        previous.revealCount +
        (outcome == StudyAttemptOutcome.revealed ? 1 : 0);
    final nextRetryCount =
        previous.retryCount +
        (outcome == StudyAttemptOutcome.retryCorrect ? 1 : 0);
    final nextCorrectStreak = _isCorrect(outcome)
        ? previous.correctStreak + 1
        : 0;
    final attemptCount = previous.attemptCount + 1;
    final attemptScore = _attemptScoreWithDuration(
      outcome: outcome,
      mode: mode,
      retentionWeight: retentionWeight,
      wrongCount: nextWrongCount,
      revealCount: nextRevealCount,
      retryCount: nextRetryCount,
      correctStreak: nextCorrectStreak,
      attemptCount: attemptCount,
      timePenalty: timePenalty,
    );
    final nextScore = previous.attemptCount == 0
        ? attemptScore
        : previous.sessionScore * oldScoreWeight +
              attemptScore * newAttemptWeight;
    final nextBestModeWeight = _isCorrect(outcome)
        ? _max(previous.bestModeWeight, weight)
        : previous.bestModeWeight;
    final verifiedModes = <StudyModeType>{
      if (previous.lastMode != null) previous.lastMode!,
      mode,
    };
    final nextState = previous.copyWith(
      sessionScore: nextScore.clamp(0, 100),
      attemptCount: attemptCount,
      wrongCount: nextWrongCount,
      revealCount: nextRevealCount,
      retryCount: nextRetryCount,
      correctStreak: nextCorrectStreak,
      lastMode: mode,
      bestModeWeight: nextBestModeWeight,
      hasHighWeightVerification:
          previous.hasHighWeightVerification ||
          (_isCorrect(outcome) && weight >= 0.92),
      hasOnlyRecallVerification:
          verifiedModes.length == 1 &&
          verifiedModes.first == StudyModeType.recall,
      hasOnlyQuizVerification:
          verifiedModes.length == 1 &&
          verifiedModes.first == StudyModeType.quiz,
    );
    _states[wordId] = nextState;
    return nextState;
  }

  /// 计算时间惩罚
  double _calculateTimePenalty({
    required int wordId,
    required int durationMs,
    required bool isCorrect,
  }) {
    final thresholds = _calculateTimeThresholds(wordId);
    final fastThreshold = thresholds['fast']!;
    final slowThreshold = thresholds['slow']!;

    // 秒答答错：加重惩罚
    if (durationMs < fastThreshold && !isCorrect) {
      return fastWrongPenalty;
    }

    // 慢答答对：轻微惩罚
    if (durationMs > slowThreshold && isCorrect) {
      return slowCorrectPenalty;
    }

    // 其他情况：无额外惩罚
    return 0.0;
  }

  /// 计算动态时间阈值
  Map<String, double> _calculateTimeThresholds(int wordId) {
    final history = _wordTimeHistory[wordId];
    if (history == null || history.isEmpty) {
      // 无历史数据，使用默认值
      return {'fast': defaultFastThresholdMs, 'slow': defaultSlowThresholdMs};
    }

    // 计算平均答题时间（使用fold代替reduce，更安全）
    final sum = history.fold<int>(0, (a, b) => a + b);
    final avgTime = sum / history.length;

    // 如果历史记录太少（少于3次），使用更保守的阈值
    final fastMultiplier = history.length < 3
        ? fastThresholdMultiplier *
              0.7 // 更宽松的秒答阈值
        : fastThresholdMultiplier;
    final slowMultiplier = history.length < 3
        ? slowThresholdMultiplier *
              1.5 // 更宽松的慢答阈值
        : slowThresholdMultiplier;

    return {'fast': avgTime * fastMultiplier, 'slow': avgTime * slowMultiplier};
  }

  /// 带时间惩罚的答题分数计算
  double _attemptScoreWithDuration({
    required StudyAttemptOutcome outcome,
    required StudyModeType mode,
    required double retentionWeight,
    required int wrongCount,
    required int revealCount,
    required int retryCount,
    required int correctStreak,
    required int attemptCount,
    required double timePenalty,
  }) {
    final base = _actionBase(outcome);
    final streakBonus = correctStreak >= 3 ? 10 : (correctStreak >= 2 ? 6 : 0);
    final wrongPenalty = wrongCount * 12;
    final revealPenalty = revealCount * 18;
    final retryPenalty = retryCount * 8;
    final repetitionPenalty = attemptCount >= 3 ? (attemptCount - 2) * 5 : 0;
    return base * modeWeight(mode) * retentionWeight +
        streakBonus -
        wrongPenalty -
        revealPenalty -
        retryPenalty -
        repetitionPenalty -
        timePenalty;
  }

  /// 加载指定日期的会话记录
  Future<void> loadSessionForDate(String date) async {
    final records = await _repository.getRecordsForDate(date);
    for (final record in records) {
      _states[record.wordId] = SessionMasteryState(
        wordId: record.wordId,
        sessionScore: record.sessionScore,
        attemptCount: record.attemptCount,
        wrongCount: record.wrongCount,
        revealCount: record.revealCount,
        retryCount: record.retryCount,
        correctStreak: record.correctStreak,
        lastMode: null,
        bestModeWeight: record.bestModeWeight,
        hasHighWeightVerification: record.hasHighWeightVerification,
        hasOnlyRecallVerification: record.hasOnlyRecallVerification,
        hasOnlyQuizVerification: record.hasOnlyQuizVerification,
      );
    }
  }

  /// 保存当前会话状态到数据库（只保存本次实际学习的单词）
  Future<void> saveSession() async {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 只保存本次会话中实际学习过的单词
    for (final wordId in _touchedWordIds) {
      final state = _states[wordId];
      if (state == null) continue;

      final record = SessionMasteryRecord(
        wordId: wordId,
        date: date,
        sessionScore: state.sessionScore,
        attemptCount: state.attemptCount,
        wrongCount: state.wrongCount,
        revealCount: state.revealCount,
        retryCount: state.retryCount,
        correctStreak: state.correctStreak,
        bestModeWeight: state.bestModeWeight,
        hasHighWeightVerification: state.hasHighWeightVerification,
        hasOnlyRecallVerification: state.hasOnlyRecallVerification,
        hasOnlyQuizVerification: state.hasOnlyQuizVerification,
        createdAt: now,
      );

      await _repository.saveSessionRecord(record);
    }
  }

  /// 加载最近N天的会话记录并综合计算
  Future<void> loadMultiDaySession({int days = 7}) async {
    final allRecords = await _repository.getRecentRecordsForAllWords(
      days: days,
    );

    for (final entry in allRecords.entries) {
      final wordId = entry.key;
      final records = entry.value;

      if (records.isEmpty) continue;

      // 计算加权平均分数
      double totalWeight = 0.0;
      double weightedScore = 0.0;
      int totalAttempts = 0;
      int totalWrong = 0;
      int totalReveal = 0;
      int totalRetry = 0;
      double maxBestModeWeight = 0.0;
      bool hasHighWeight = false;
      bool hasOnlyRecall = true;
      bool hasOnlyQuiz = true;

      final now = DateTime.now();

      for (final record in records) {
        // 计算日期权重
        final recordDate = DateTime.parse(record.date);
        final daysAgo = now.difference(recordDate).inDays;
        final weight = _max(0.2, 1.0 - (daysAgo * 0.2));

        totalWeight += weight;
        weightedScore += record.sessionScore * weight;
        totalAttempts += record.attemptCount;
        totalWrong += record.wrongCount;
        totalReveal += record.revealCount;
        totalRetry += record.retryCount;
        maxBestModeWeight = _max(maxBestModeWeight, record.bestModeWeight);
        hasHighWeight = hasHighWeight || record.hasHighWeightVerification;
        hasOnlyRecall = hasOnlyRecall && record.hasOnlyRecallVerification;
        hasOnlyQuiz = hasOnlyQuiz && record.hasOnlyQuizVerification;
      }

      final comprehensiveScore = totalWeight > 0
          ? weightedScore / totalWeight
          : 0.0;

      _states[wordId] = SessionMasteryState(
        wordId: wordId,
        sessionScore: comprehensiveScore.clamp(0, 100),
        attemptCount: totalAttempts, // 累加总答题次数
        wrongCount: totalWrong, // 累加总错误次数
        revealCount: totalReveal, // 累加总提示次数
        retryCount: totalRetry, // 累加总重试次数
        correctStreak: 0, // 跨天后重置连续正确计数（记忆状态不连续）
        lastMode: null, // 跨天后重置上次使用的模式
        bestModeWeight: maxBestModeWeight,
        hasHighWeightVerification: hasHighWeight,
        hasOnlyRecallVerification: hasOnlyRecall,
        hasOnlyQuizVerification: hasOnlyQuiz,
      );
    }
  }

  /// 获取单词的平均答题时间（毫秒）
  double getAverageTimeForWord(int wordId) {
    final history = _wordTimeHistory[wordId];
    if (history == null || history.isEmpty) return 0.0;
    final sum = history.fold<int>(0, (a, b) => a + b);
    return sum / history.length;
  }
}
