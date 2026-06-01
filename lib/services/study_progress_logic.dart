class StudyProgressLogic {
  const StudyProgressLogic._();

  static List<int> remainingWordIds({
    required List<int> wordIds,
    required int currentIndex,
  }) {
    final safeIndex = currentIndex.clamp(0, wordIds.length);
    return wordIds.skip(safeIndex).toList(growable: false);
  }

  static int? nextProgressIndex({
    required int currentIndex,
    required int totalWords,
  }) {
    final nextIndex = currentIndex + 1;
    if (nextIndex >= totalWords) return null;
    return nextIndex;
  }

  static String defaultProgressKey({
    required String source,
    required int? wordBookId,
  }) {
    return '$source:${wordBookId ?? 'global'}';
  }

  static String safeProgressTitle(String? title) {
    final value = title?.trim() ?? '';
    if (value.isEmpty) return '继续学习';
    return value;
  }
}
