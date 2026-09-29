import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 引导状态与埋点服务。
///
/// 负责：
/// - 记录各页面的「上下文引导（coach mark）」是否已看过，保证每页只弹一次；
/// - 记录新手引导流程中的关键事件（本地计数 + debug 输出），
///   用于后续分析哪一步被跳过最多，不涉及任何网络上报。
class GuideService {
  GuideService._();

  static const String _seenPrefix = 'guide_seen_';
  static const String _eventPrefix = 'guide_event_';

  // ---- 上下文引导 ID ----
  /// 主流程巡览：首页 → 词库 → 阅读 → 统计
  static const String tipMainTour = 'main_tour';

  /// 选词页：五种练习模式 + 智能模式 + 开始按钮
  static const String tipStudyModes = 'study_modes';

  /// 做题页：收藏 / 查词典 / 桌面端快捷键
  static const String tipStudyActions = 'study_actions';

  /// 词库页：导入、批量管理、词库卡片
  static const String tipWordBook = 'wordbook';

  /// 阅读页：词条菜单（记住了 / 收藏 / 书签 / 查词典）+ 顶栏按钮
  static const String tipReaderFeatures = 'reader_features';

  /// 统计页：今日建议 + 学习报告 + 成就中心
  static const String tipStats = 'stats';

  /// 设置页：外观 / 发音与词典 / 提醒 / 帮助与引导
  static const String tipSettings = 'settings';

  /// 错词集：专项复习、筛选、列表
  static const String tipWrongWords = 'wrong_words';

  /// 收藏集：搜索、筛选、专项复习
  static const String tipFavorites = 'favorites';

  /// 全部引导 ID，供「重看功能提示」与测试遍历
  static const List<String> allTipIds = [
    tipMainTour,
    tipStudyModes,
    tipStudyActions,
    tipWordBook,
    tipReaderFeatures,
    tipStats,
    tipSettings,
    tipWrongWords,
    tipFavorites,
  ];

  // ---- 引导内的跨 Tab 跳转 ----
  /// 引导请求切换到的底部 Tab 序号；由 HomeScreen 监听并执行，执行后置空。
  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  static void requestTab(int index) {
    requestedTab.value = index;
  }

  static void clearRequestedTab() {
    requestedTab.value = null;
  }

  /// 该页面的上下文引导是否已经看过
  static Future<bool> isSeen(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_seenPrefix$id') ?? false;
    } catch (e) {
      debugPrint('引导状态读取失败：$e');
      // 读失败按"未看过"处理：此前 return true 会让持久层异常期间
      // 全部功能提示静默永不弹出，且没有任何可恢复路径
      return false;
    }
  }

  /// 标记该页面的上下文引导已看过
  static Future<void> markSeen(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_seenPrefix$id', true);
    } catch (e) {
      debugPrint('引导状态保存失败：$e');
    }
  }

  /// 重置所有上下文引导，让各页面下次进入时重新展示提示
  static Future<void> resetAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith(_seenPrefix))
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('引导状态重置失败：$e');
    }
  }

  /// 「重看功能提示」信号：自增一次，通知 HomeScreen 清掉本会话的
  /// 已展示缓存并立即重播引导。只清 prefs 标记是不够的——
  /// HomeScreen 的 _shownTabGuides 与主导览的 initState 时机都不会重来，
  /// 表现为「点了重看却什么都没发生」。
  static final ValueNotifier<int> replayTipsSignal = ValueNotifier<int>(0);

  static void notifyReplayTips() {
    replayTipsSignal.value++;
  }

  // ---- 引导流程埋点（本地） ----

  /// 引导流程事件名
  static const String eventStart = 'onboarding_start';
  static const String eventStepView = 'onboarding_step_view';
  static const String eventSkip = 'onboarding_skip';
  static const String eventComplete = 'onboarding_complete';
  static const String eventImportBooks = 'onboarding_import_books';

  /// 记录一次引导事件。仅本地累加计数并输出日志，便于后续排查与优化。
  static Future<void> logEvent(
    String name, {
    Map<String, Object?>? params,
  }) async {
    if (kDebugMode) {
      debugPrint('[Guide] $name${params == null ? '' : ' $params'}');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_eventPrefix$name';
      await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
    } catch (e) {
      debugPrint('引导埋点写入失败：$e');
    }
  }

  /// 读取某事件的累计次数（测试 / 内部诊断用）
  static Future<int> eventCount(String name) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_eventPrefix$name') ?? 0;
  }
}
