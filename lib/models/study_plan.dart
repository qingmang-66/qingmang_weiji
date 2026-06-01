/// 学习计划类型
enum StudyPlanType {
  /// 固定每日量：用户指定每天学习多少新词
  fixedDaily,

  /// 固定截止日：用户指定目标日期，系统计算每日任务
  fixedDeadline,

  /// 考试目标：基于考试词库生成计划
  examTarget,
}

/// 学习计划状态
enum StudyPlanStatus {
  /// 进行中
  active,

  /// 暂停
  paused,

  /// 已完成
  completed,
}

/// 学习计划模型
///
/// 描述用户基于词库和目标设置的学习计划，
/// 用于首页今日任务、计划进度展示和每日任务量估算。
class StudyPlan {
  final int? id;

  /// 计划名称
  final String name;

  /// 关联词库 ID 列表
  final List<int> wordBookIds;

  /// 计划类型
  final StudyPlanType type;

  /// 目标日期，固定每日量类型可为 null
  final DateTime? targetDate;

  /// 每日新词目标
  final int dailyNewTarget;

  /// 计划范围内总词数
  final int totalWords;

  /// 计划状态
  final StudyPlanStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyPlan({
    this.id,
    required this.name,
    required this.wordBookIds,
    required this.type,
    this.targetDate,
    required this.dailyNewTarget,
    required this.totalWords,
    this.status = StudyPlanStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  StudyPlan copyWith({
    int? id,
    String? name,
    List<int>? wordBookIds,
    StudyPlanType? type,
    DateTime? targetDate,
    int? dailyNewTarget,
    int? totalWords,
    StudyPlanStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      wordBookIds: wordBookIds ?? this.wordBookIds,
      type: type ?? this.type,
      targetDate: targetDate ?? this.targetDate,
      dailyNewTarget: dailyNewTarget ?? this.dailyNewTarget,
      totalWords: totalWords ?? this.totalWords,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      // 词库 ID 列表用逗号拼接存储
      'word_book_ids': wordBookIds.join(','),
      'type': type.index,
      'target_date': targetDate?.toIso8601String(),
      'daily_new_target': dailyNewTarget,
      'total_words': totalWords,
      'status': status.index,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StudyPlan.fromMap(Map<String, dynamic> map) {
    return StudyPlan(
      id: map['id'] as int?,
      name: map['name'] as String,
      wordBookIds: _parseWordBookIds(map['word_book_ids'] as String?),
      type: StudyPlanType
          .values[(map['type'] as int? ?? 0)
              .clamp(0, StudyPlanType.values.length - 1)],
      targetDate: (map['target_date'] as String?) != null
          ? DateTime.tryParse(map['target_date'] as String)
          : null,
      dailyNewTarget: (map['daily_new_target'] as int?) ?? 0,
      totalWords: (map['total_words'] as int?) ?? 0,
      status: StudyPlanStatus
          .values[(map['status'] as int? ?? 0)
              .clamp(0, StudyPlanStatus.values.length - 1)],
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// 解析逗号拼接的词库 ID 字符串
  static List<int> _parseWordBookIds(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }
}
