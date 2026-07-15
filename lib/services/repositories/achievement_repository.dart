import 'package:flutter/foundation.dart';

import '../achievement_service.dart';
import '../../models/achievement_progress.dart';

/// 阶段四：成就系统仓库
///
/// 封装 [AchievementService] 调用，向上层提供：
/// - 加载并检测
/// - 加载全量/最近已解锁
/// - 订阅解锁事件
class AchievementRepository {
  final AchievementService _service;

  AchievementRepository(this._service);

  /// 加载并检测新解锁
  Future<List<AchievementProgress>> loadAndCheck() async {
    try {
      await _service.checkAndUnlock();
      return await _service.loadAll();
    } catch (e) {
      debugPrint('AchievementRepository.loadAndCheck error: $e');
      rethrow;
    }
  }

  /// 加载全量进度（不触发检测）
  Future<List<AchievementProgress>> loadAll() async {
    try {
      return await _service.loadAll();
    } catch (e) {
      debugPrint('AchievementRepository.loadAll error: $e');
      rethrow;
    }
  }

  /// 加载最近 N 条已解锁
  Future<List<AchievementProgress>> getRecent({int limit = 3}) async {
    try {
      return await _service.loadRecentUnlocked(limit: limit);
    } catch (e) {
      debugPrint('AchievementRepository.getRecent error: $e');
      return const [];
    }
  }

  /// 解锁事件流
  Stream<List<AchievementProgress>> get newlyUnlockedStream =>
      _service.newlyUnlockedStream;
}
