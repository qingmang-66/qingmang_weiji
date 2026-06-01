import 'study_source.dart';

class SpecializedStudyRequest {
  final StudySource source;
  final String title;
  final int? wordBookId;
  final List<int> wordIds;
  final int studyMode;
  final bool isReview;
  final bool allowProgressSave;
  final String? explicitProgressKey;

  const SpecializedStudyRequest({
    required this.source,
    required this.title,
    required this.wordBookId,
    required this.wordIds,
    required this.studyMode,
    required this.isReview,
    this.allowProgressSave = true,
    this.explicitProgressKey,
  });

  bool get hasWords => wordIds.isNotEmpty;

  String get progressKey {
    if (explicitProgressKey != null && explicitProgressKey!.isNotEmpty) {
      return explicitProgressKey!;
    }
    return '${source.key}:${wordBookId ?? 'global'}';
  }
}
