import 'package:flutter/material.dart';
import '../utils/translations.dart';

/// 记忆阶段枚举 - 使用固定标识符，不受语言切换影响
///
/// 数据库和组件间传递使用枚举名称（如 "newLearned"），
/// 仅在 UI 展示时通过 [displayName] 获取翻译后的文本
enum MemoryStage {
  newLearned,  // 新学
  initial,     // 初步
  consolidating, // 巩固
  familiar,    // 熟悉
  mastered,    // 掌握
}

/// 记忆阶段的本地化扩展
extension MemoryStageLocalization on MemoryStage {
  /// 根据上下文返回当前语言的显示名称
  String displayName(BuildContext context) {
    switch (this) {
      case MemoryStage.newLearned:
        return context.tr.newLearned;
      case MemoryStage.initial:
        return context.tr.initial;
      case MemoryStage.consolidating:
        return context.tr.consolidating;
      case MemoryStage.familiar:
        return context.tr.familiar;
      case MemoryStage.mastered:
        return context.tr.mastered;
    }
  }
}