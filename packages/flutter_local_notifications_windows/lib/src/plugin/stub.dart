import '../details.dart';
import 'base.dart';

/// The Windows implementation of `package:flutter_local_notifications`.
///
/// 桩实现：所有方法均为空操作，避免 FFI 绑定导致 AOT 编译崩溃。
/// Windows 通知由 local_notifier 包独立处理。
class FlutterLocalNotificationsWindows extends WindowsNotificationsBase {
  /// Flutter 插件注册入口（由 dart_plugin_registrant.dart 自动调用）
  ///
  /// 必须把平台实例填上：`FlutterLocalNotificationsPlatform._instance` 是
  /// `static late`（无初值），主插件的每个入口都会先读它来判定平台实现，
  /// 缺了这一步 Windows 上会抛 LateInitializationError（报错信息与真实原因
  /// 完全无关）。当前调用点都靠 `isWindowsPlatform` 早退挡住了，这里补上
  /// 仅作兜底，避免将来漏掉一处就崩。
  static void registerWith() {
    FlutterLocalNotificationsPlatform.instance =
        FlutterLocalNotificationsWindows();
  }

  @override
  Future<bool> initialize({
    required WindowsInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    return false;
  }

  @override
  void dispose() {}

  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async =>
      <ActiveNotification>[];

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => null;

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => <PendingNotificationRequest>[];

  @override
  Future<void> periodicallyShow({
    required int id,
    String? title,
    String? body,
    required RepeatInterval repeatInterval,
  }) async {}

  @override
  Future<void> periodicallyShowWithDuration({
    required int id,
    String? title,
    String? body,
    required Duration repeatDurationInterval,
  }) async {}

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    WindowsNotificationDetails? notificationDetails,
  }) async {}

  @override
  Future<void> showRawXml({
    required int id,
    required String xml,
    Map<String, String> bindings = const <String, String>{},
  }) async {}

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required TZDateTime scheduledDate,
    WindowsNotificationDetails? notificationDetails,
    String? payload,
  }) async {}

  @override
  Future<void> zonedScheduleRawXml({
    required int id,
    required String xml,
    required TZDateTime scheduledDate,
  }) async {}
  @override
  Future<NotificationUpdateResult> updateBindings({
    required int id,
    required Map<String, String> bindings,
  }) async => NotificationUpdateResult.success;

  @override
  bool isValidXml(String xml) => false;
}
