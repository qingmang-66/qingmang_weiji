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

  /// 阶段三：自定义词集增强 - 词集专项学习时携带 setId，用于完成后回写
  final int? customWordSetId;

  /// 阶段三：专项学习完成回调
  ///
  /// 由 [SpecializedStudyService] 在构造 Request 时注入，
  /// [PreStudyScreen._finishStudy] 末尾统一调用。
  ///
  /// 设计要点：
  /// - nullable：错词本 / 搜索结果专项学习无需回写，设为 null
  /// - 闭包自包含：失败处理由闭包内部 try-catch 完成（debugPrint）
  /// - 仅调用一次：PreStudyScreen 不会重复触发
  final Future<void> Function()? onCompleted;

  const SpecializedStudyRequest({
    required this.source,
    required this.title,
    required this.wordBookId,
    required this.wordIds,
    required this.studyMode,
    required this.isReview,
    this.allowProgressSave = true,
    this.explicitProgressKey,
    this.customWordSetId,
    this.onCompleted,
  });

  bool get hasWords => wordIds.isNotEmpty;

  String get progressKey {
    if (explicitProgressKey != null && explicitProgressKey!.isNotEmpty) {
      return explicitProgressKey!;
    }
    return '${source.key}:${wordBookId ?? 'global'}';
  }
}
