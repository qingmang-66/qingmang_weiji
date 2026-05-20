// 应用事件总线 - 解耦服务层之间的依赖
//
// 使用发布-订阅模式，让服务之间无需直接引用彼此
// 适用于：通知触发、状态广播等场景

import 'package:flutter/foundation.dart';

/// 应用事件类型
enum AppEventType {
  /// 待复习单词数量变化
  dueWordsChanged,
  
  /// 学习进度更新
  studyProgressUpdated,
  
  /// 错词数量变化
  wrongWordsChanged,
  
  /// 词库切换
  wordBookChanged,
  
  /// 数据备份完成
  backupCompleted,
}

/// 事件数据包装器
class AppEvent {
  final AppEventType type;
  final Map<String, dynamic> data;

  AppEvent(this.type, {this.data = const {}});
}

/// 事件监听器回调
typedef AppEventListener = void Function(AppEvent event);

/// 应用事件总线
class EventBus {
  // 单例模式
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  // 存储所有监听器，key 为事件类型
  final Map<AppEventType, List<AppEventListener>> _listeners = {};

  /// 订阅指定类型的事件
  void subscribe(AppEventType type, AppEventListener listener) {
    _listeners.putIfAbsent(type, () => []).add(listener);
    debugPrint('📡 事件总线：订阅 ${type.name}');
  }

  /// 取消订阅
  void unsubscribe(AppEventType type, AppEventListener listener) {
    _listeners[type]?.remove(listener);
  }

  /// 发布事件
  void publish(AppEvent event) {
    final listeners = _listeners[event.type] ?? [];
    debugPrint('📡 事件总线：发布 ${event.type.name}，${listeners.length} 个监听器');
    
    for (final listener in listeners) {
      try {
        listener(event);
      } catch (e) {
        debugPrint('❌ 事件处理失败：${event.type.name}，$e');
      }
    }
  }

  /// 清空所有监听器（用于测试或重置）
  void clear() {
    _listeners.clear();
    debugPrint('📡 事件总线：已清空所有监听器');
  }
}

/// 便捷方法：获取事件总线实例
EventBus get eventBus => EventBus();
