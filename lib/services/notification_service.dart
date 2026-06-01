import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 本地通知服务 - 学习/复习提醒
///
/// 跨平台通知实现：
/// - Android：flutter_local_notifications 的 zonedSchedule + matchDateTimeComponents
/// - iOS/macOS：flutter_local_notifications 的 zonedSchedule + matchDateTimeComponents
/// - Windows：local_notifier 弹出系统 Toast 通知（避免 flutter_local_notifications_windows
///   的 FFI 绑定导致 AOT 编译崩溃），每日提醒使用 Timer 轮询
/// - Linux：flutter_local_notifications 桌面通知
///
/// 注意（安全）：通知内容不包含任何敏感数据，仅展示待复习数量等非隐私信息。
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// flutter_local_notifications 插件实例（用于 Android/iOS/macOS/Linux）
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 是否已成功初始化
  bool _initialized = false;

  /// 当前平台是否支持本地通知插件
  bool _supported = false;

  /// 每日提醒通知 ID（固定，便于覆盖/取消）
  static const int _dailyReminderId = 1001;

  /// 即时提醒通知 ID
  static const int _instantReminderId = 1002;

  /// Android 通知渠道 ID
  static const String _channelId = 'study_reminder_channel';
  static const String _channelName = '学习提醒';
  static const String _channelDesc = '每日单词学习与复习提醒';

  /// Windows 每日提醒的 Timer（Windows 不支持 matchDateTimeComponents 重复通知）
  Timer? _windowsDailyTimer;

  /// Windows 每日提醒的调度参数
  int? _windowsReminderHour;
  int? _windowsReminderMinute;
  String? _windowsReminderTitle;
  String? _windowsReminderBody;

  /// 初始化通知服务
  ///
  /// 初始化时区数据、各平台插件设置，并在移动端请求通知权限。
  /// Windows 使用 local_notifier 弹出 Toast 通知。
  Future<void> init() async {
    if (_initialized) return;

    // 初始化时区数据，供 zonedSchedule 使用
    try {
      tz_data.initializeTimeZones();
      _configureLocalTimeZone();
    } catch (e) {
      debugPrint('通知服务：时区初始化失败，降级处理 - $e');
    }

    try {
      // Windows 使用 local_notifier，不走 flutter_local_notifications 初始化
      if (Platform.isWindows) {
        await _initWindows();
      } else {
        await _initOtherPlatforms();
      }

      _supported = true;
      _initialized = true;

      debugPrint('通知服务初始化完成（平台支持: $_supported）');
    } catch (e) {
      _supported = false;
      _initialized = true;
      debugPrint('通知服务初始化失败 - $e');
    }
  }

  /// Windows 平台初始化：使用 local_notifier
  Future<void> _initWindows() async {
    await localNotifier.setup(
      appName: '清茫微记',
      // 非 MSIX 应用使用 ignore 策略，避免因缺少开始菜单快捷方式导致初始化失败
      shortcutPolicy: ShortcutPolicy.ignore,
    );
    debugPrint('通知服务：Windows local_notifier 初始化完成');
  }

  /// 非 Windows 平台初始化：使用 flutter_local_notifications
  Future<void> _initOtherPlatforms() async {
    // Android 设置（使用默认应用图标）
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS / macOS 设置
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Linux 设置
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: '打开应用',
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 移动端创建通知渠道并请求权限
    await _requestPermissionsIfNeeded();
  }

  /// 根据系统本地时间偏移推断时区，失败则保持默认（UTC）
  void _configureLocalTimeZone() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      // 中国大陆（UTC+8）最常见，直接匹配，其余使用 UTC 降级
      if (offset == const Duration(hours: 8)) {
        tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
      } else {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    } catch (e) {
      debugPrint('通知服务：设置本地时区失败，使用默认 - $e');
    }
  }

  /// 移动端请求通知权限并创建 Android 渠道
  Future<void> _requestPermissionsIfNeeded() async {
    try {
      if (Platform.isAndroid) {
        final androidImpl = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.defaultImportance,
          ),
        );
        await androidImpl?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } else if (Platform.isMacOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('通知服务：请求权限失败 - $e');
    }
  }

  /// 构建通用通知详情（包含各平台配置，不含 Windows）
  NotificationDetails _buildNotificationDetails() {
    return NotificationDetails(
      android: const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
      linux: const LinuxNotificationDetails(),
    );
  }

  /// 设置每日定时提醒
  ///
  /// [hour]、[minute] 为每日提醒时刻；[title]、[body] 为通知文案。
  /// - Android/iOS/macOS/Linux：使用 zonedSchedule + matchDateTimeComponents 实现每日重复
  /// - Windows：使用 local_notifier + Timer 每分钟检查，到时间后弹出 Toast 通知
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    if (!_supported) {
      debugPrint('通知服务：初始化失败，无法设置每日提醒');
      return;
    }

    try {
      // 先取消已有的每日提醒
      await cancelReminder();

      if (Platform.isWindows) {
        // Windows 使用 Timer 轮询 + local_notifier 弹出通知
        _windowsReminderHour = hour;
        _windowsReminderMinute = minute;
        _windowsReminderTitle = title;
        _windowsReminderBody = body;
        _startWindowsDailyTimer();
        debugPrint(
          '通知服务：已设置 Windows 每日提醒 $hour:$minute（local_notifier + Timer 轮询）',
        );
      } else {
        // Android/iOS/macOS/Linux：使用 zonedSchedule + matchDateTimeComponents
        final scheduled = _nextInstanceOf(hour, minute);
        await _plugin.zonedSchedule(
          id: _dailyReminderId,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: _buildNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        debugPrint('通知服务：已设置每日提醒 $hour:$minute');
      }
    } catch (e) {
      debugPrint('通知服务：设置每日提醒失败 - $e');
    }
  }

  /// 启动 Windows 每日提醒的 Timer 轮询
  ///
  /// 每分钟检查一次当前时间是否匹配设定的提醒时刻，
  /// 匹配时通过 local_notifier 弹出 Toast 通知。
  /// Timer 仅在应用运行期间有效。
  void _startWindowsDailyTimer() {
    _windowsDailyTimer?.cancel();
    _windowsDailyTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_windowsReminderHour == null || _windowsReminderMinute == null) {
        return;
      }
      final now = DateTime.now();
      if (now.hour == _windowsReminderHour &&
          now.minute == _windowsReminderMinute) {
        _showWindowsNotification(
          title: _windowsReminderTitle ?? '学习提醒',
          body: _windowsReminderBody ?? '该背单词啦，坚持就是胜利！',
        );
      }
    });
  }

  /// 通过 local_notifier 显示 Windows Toast 通知
  void _showWindowsNotification({required String title, required String body}) {
    try {
      final notification = LocalNotification(title: title, body: body);
      notification.onShow = () {
        debugPrint('通知服务：Windows 通知已显示 - $title');
      };
      notification.onClick = () {
        debugPrint('通知服务：Windows 通知被点击 - $title');
      };
      notification.show();
    } catch (e) {
      debugPrint('通知服务：Windows 通知显示失败 - $e');
    }
  }

  /// 计算下一个指定时刻的时区时间（若今日已过则顺延到明日）
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// 取消每日提醒
  Future<void> cancelReminder() async {
    // 取消 Windows Timer
    _windowsDailyTimer?.cancel();
    _windowsDailyTimer = null;
    _windowsReminderHour = null;
    _windowsReminderMinute = null;
    _windowsReminderTitle = null;
    _windowsReminderBody = null;

    if (!_supported) return;
    try {
      if (!Platform.isWindows) {
        await _plugin.cancel(id: _dailyReminderId);
      }
    } catch (e) {
      debugPrint('通知服务：取消提醒 - $e');
    }
  }

  /// 立即显示复习提醒通知
  Future<void> showReviewReminder(int dueCount) async {
    if (!_initialized) await init();

    final title = '复习提醒';
    final body = '你有 $dueCount 个单词待复习，快来巩固记忆吧！';

    await _showNotification(id: _instantReminderId, title: title, body: body);
  }

  /// 通用通知显示方法（根据平台分发）
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_supported) {
      debugPrint('通知（降级）：$title - $body');
      return;
    }

    try {
      if (Platform.isWindows) {
        // Windows 使用 local_notifier
        _showWindowsNotification(title: title, body: body);
      } else {
        // 其他平台使用 flutter_local_notifications
        await _plugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: _buildNotificationDetails(),
        );
      }
    } catch (e) {
      debugPrint('通知服务：显示通知失败 - $e');
    }
  }

  /// 检查并在需要时显示复习提醒
  Future<void> checkAndShowReminder(int dueCount) async {
    if (dueCount > 0) {
      await showReviewReminder(dueCount);
    }
  }

  /// 通知点击回调（进入应用，后续可扩展跳转到学习页）
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('通知被点击：payload=${response.payload}');
  }

  /// 加载通知设置（兼容旧接口）
  Future<bool> loadNotificationSetting() async {
    return true;
  }

  /// 释放资源（取消 Timer 等）
  void dispose() {
    _windowsDailyTimer?.cancel();
    _windowsDailyTimer = null;
  }
}
