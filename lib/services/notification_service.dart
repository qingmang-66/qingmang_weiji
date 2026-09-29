import 'dart:async';
import '../utils/platform_info.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_sound_service.dart';

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

  /// 系统设置跳转通道（原生侧定义在 MainActivity）
  static const MethodChannel _systemChannel = MethodChannel(
    'qingmang_weiji/system',
  );

  /// 通知点击后待处理的 payload（冷启动/前台）
  final ValueNotifier<String?> pendingLaunchPayload = ValueNotifier<String?>(
    null,
  );
  static const String payloadDailyReminder = 'daily_reminder';
  static const String payloadReviewReminder = 'review_reminder';
  void clearPendingLaunchPayload() {
    pendingLaunchPayload.value = null;
  }

  /// 当前平台是否支持本地通知插件
  bool _supported = false;

  /// 平台本身确定不支持通知（如 Web），确认后不再尝试初始化
  bool _platformUnsupported = false;

  /// 上次初始化失败的时间：失败后允许限频重试，避免"开关打开却永远收不到提醒"
  DateTime? _lastInitFailure;

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

  /// 今天是否已触发过每日提醒（补发逻辑防重复）
  ///
  /// 同时持久化到 SharedPreferences：只放内存时，用户在提醒时刻之后重启应用
  /// 会再收到一次同样的提醒；而 cancelReminder（重新调度前必调）一旦清空它，
  /// 同一天里改一次提醒设置就会重复弹一次。
  String? _windowsLastFiredDate;
  static const String _keyWindowsLastFiredDate = 'windowsReminderLastFiredDate';

  /// 初始化中的 Future：冷启动后台初始化与用户此刻打开提醒开关可能同时触发，
  /// 没有这道闸门时插件会被 initialize 两遍（平台侧重复注册）
  Future<void>? _initInFlight;

  /// 初始化通知服务
  ///
  /// 初始化时区数据、各平台插件设置，并在移动端请求通知权限。
  /// Windows 使用 local_notifier 弹出 Toast 通知。
  ///
  /// 并发调用复用同一次初始化；失败后的限频重试逻辑（见 [_initInternal]）
  /// 仍然保留 —— Future 完成后即清空闸门，下次调用照常重走判断。
  Future<void> init() {
    final inFlight = _initInFlight;
    if (inFlight != null) return inFlight;
    final future = _initInternal().whenComplete(() {
      _initInFlight = null;
    });
    _initInFlight = future;
    return future;
  }

  Future<void> _initInternal() async {
    if (_initialized) {
      //已成功初始化、或平台确定不支持：无需再动
      if (_supported || _platformUnsupported) return;
      //上次是「临时失败」：限频重试（1 分钟），否则用户打开提醒开关也会静默失效
      final lastFailure = _lastInitFailure;
      if (lastFailure == null ||
          DateTime.now().difference(lastFailure) < const Duration(minutes: 1)) {
        return;
      }
    }

    if (kIsWeb) {
      _supported = false;
      _platformUnsupported = true;
      _initialized = true;
      return;
    }

    // 初始化时区数据，供 zonedSchedule 使用
    try {
      tz_data.initializeTimeZones();
      await _configureLocalTimeZone();
    } catch (e) {
      debugPrint('通知服务：时区初始化失败，降级处理 - $e');
    }

    try {
      // Windows 使用 local_notifier，不走 flutter_local_notifications 初始化
      if (isWindowsPlatform) {
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
      _lastInitFailure = DateTime.now();
      debugPrint('通知服务初始化失败 - $e（稍后可重试）');
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
    // Android 通知小图标必须是单色剪影：用启动器图标会在通知栏显示成纯白块，
    // 因此单独提供 @drawable/ic_notification（白色书本形状）。
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
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

    // 冷启动时用户可能是"点通知进来的"：onDidReceiveNotificationResponse
    // 只在应用已运行时触发，冷启动必须用 getNotificationAppLaunchDetails 取回，
    // 否则"点提醒直接进复习"这类跳转会静默失效
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final payload = launch?.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          pendingLaunchPayload.value = payload;
        }
      }
    } catch (e) {
      debugPrint('通知服务：读取冷启动通知 payload 失败 - $e');
    }

    // 移动端创建通知渠道并请求权限
    await _requestPermissionsIfNeeded();
  }

  /// 通过平台时区 API 获取 IANA 名称，失败时按固定偏移推断，再失败降级 UTC
  Future<void> _configureLocalTimeZone() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      return;
    } catch (e) {
      debugPrint('通知服务：获取平台时区失败，尝试按偏移推断 - $e');
    }
    try {
      final offset = DateTime.now().timeZoneOffset;
      // 偏移推断兜底：按实际偏移构造 Etc/GMT 区域。
      // 注意 tz 库的 Etc/GMT-N 是 POSIX 语义（符号相反）：Etc/GMT-8 表示 UTC+8。
      // 非整小时偏移（如 UTC+5:30）会被截断到整点——仅在平台时区 API 失败时
      // 才会走到这里，误差远小于此前"非 UTC+8 一律按 UTC"的做法。
      if (offset == Duration.zero) {
        tz.setLocalLocation(tz.getLocation('Etc/GMT'));
      } else {
        final hours = offset.inHours;
        tz.setLocalLocation(
          tz.getLocation(
            offset.isNegative ? 'Etc/GMT+${-hours}' : 'Etc/GMT-$hours',
          ),
        );
      }
    } catch (e) {
      debugPrint('通知服务：设置本地时区失败，使用默认 - $e');
    }
  }

  /// 移动端创建通知渠道 / 申请权限
  ///
  /// Android 的权限申请刻意**不放在冷启动**：与使用场景脱节的权限框很容易被
  /// 用户当场拒掉，之后开关打开也收不到提醒。改由用户第一次打开"每日学习提醒"
  /// 时申请（见 [scheduleDailyReminder]），时机与意图一致。
  Future<void> _requestPermissionsIfNeeded() async {
    try {
      if (isAndroidPlatform) {
        final androidImpl = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            // 学习提醒是用户主动开启的定时提醒，用 high 才会在到点时横幅弹出；
            // default 只会安静地落进通知栏，手机上很容易错过
            //（Windows 端本身就是 Toast 弹窗，两边体验由此对齐）。
            importance: Importance.high,
          ),
        );
      } else if (isIOSPlatform) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } else if (isMacOSPlatform) {
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
        importance: Importance.high,
        priority: Priority.high,
        // 用 dart 侧指定的单色小图标；不填会退回初始化时给的那个
        icon: '@drawable/ic_notification',
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
      linux: const LinuxNotificationDetails(),
    );
  }

  /// 打开本应用的通知设置页（Android）。
  ///
  /// 通知权限被拒后，光提示"失败"不够 —— 用户需要去系统设置里手动打开，
  /// 这里直接带他过去。其它平台没有对应的统一入口，静默忽略。
  Future<void> openSystemSettings() async {
    if (!isAndroidPlatform) return;
    try {
      await _systemChannel.invokeMethod<void>('openNotificationSettings');
    } catch (e) {
      debugPrint('通知服务：打开系统通知设置失败 - $e');
    }
  }

  /// 再确认一次 Android 通知权限。
  ///
  /// 启动时已经申请过一次，但用户可能当场就拒了；之后在设置里打开提醒时如果不
  /// 复查，开关会停在"已开启"而通知永远不会来（静默失败）。已授权时系统不会再
  /// 弹框，所以这里重复调用是安全的。
  ///
  /// 返回 false 只有一种情况：用户确实拒绝了通知权限。
  Future<bool> _ensureAndroidNotificationPermission() async {
    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl == null) return true;
      // Android 13 以下 / 部分 ROM 会返回 null，此时不拦，交给系统通知开关决定
      final granted = await androidImpl.requestNotificationsPermission();
      return granted ?? true;
    } catch (e) {
      debugPrint('通知服务：确认通知权限失败 - $e');
      return true;
    }
  }

  /// 设置每日定时提醒
  ///
  /// [hour]、[minute] 为每日提醒时刻；[title]、[body] 为通知文案。
  /// - Android/iOS/macOS/Linux：使用 zonedSchedule + matchDateTimeComponents 实现每日重复
  /// - Windows：使用 local_notifier + Timer 每分钟检查，到时间后弹出 Toast 通知
  ///
  /// 通知权限被拒时抛异常，调用方据此提示用户并回滚开关，
  /// 不会出现"开关是开的、提醒却不来"这种静默失败。
  ///
  /// [ensurePermission] 为 true 时会先复查 Android 通知权限（用户主动开启提醒时
  /// 用）；启动时恢复已有调度不传，避免冷启动弹权限框。
  ///
  /// 平台本身不支持通知（Web / 插件初始化失败）不抛：那不是用户操作失败，
  /// 只是这台设备没有这个能力，静默跳过即可。
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    bool ensurePermission = false,
  }) async {
    if (!_initialized) await init();
    if (!_supported) {
      // 平台本身不支持（Web）：静默跳过是合理的，UI 不会给出这个开关
      if (_platformUnsupported) {
        debugPrint('通知服务：当前平台不支持本地通知，跳过');
        return;
      }
      // 初始化失败（插件/图标/ROM 问题）：必须让调用方知道，
      // 否则就是"开关显示已开启、但永远收不到提醒"的静默失败
      throw StateError('notification service unavailable');
    }

    if (ensurePermission &&
        isAndroidPlatform &&
        !await _ensureAndroidNotificationPermission()) {
      debugPrint('通知服务：通知权限被拒，无法设置每日提醒');
      throw StateError('notification permission denied');
    }

    try {
      // 先取消已有的每日提醒（不清理"今日已触发"，避免同日改时间重复弹）
      await _cancelReminder(clearFiredDate: false);

      if (isWindowsPlatform) {
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
      // 向上抛：提醒开关需要据此回滚并提示用户，
      // 否则调度失败会表现为"开关开着但没有提醒"
      rethrow;
    }
  }

  /// 启动 Windows 每日提醒的 Timer 轮询
  ///
  /// 每分钟检查一次：今日提醒时刻已过且当天尚未触发，则弹一次 Toast。
  /// - 系统挂起导致轮询跳过精确分钟时，由"时刻已过 + 当日未触发"自然补发；
  /// - 用户在提醒时刻之后才启动应用（如 20:00 提醒、21:30 开机），
  ///   启动后的第一次轮询即补发当天错过的提醒；
  /// - Timer 仅在应用运行期间有效，关闭应用后收不到提醒。
  void _startWindowsDailyTimer() {
    _windowsDailyTimer?.cancel();
    //先把"今日是否已触发"从磁盘读回来（异步，不阻塞定时器启动）
    unawaited(_loadWindowsLastFiredDate());
    _windowsDailyTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final hour = _windowsReminderHour;
      final minute = _windowsReminderMinute;
      if (hour == null || minute == null) return;
      final now = DateTime.now();
      final scheduled = DateTime(now.year, now.month, now.day, hour, minute);
      if (now.isBefore(scheduled)) return; // 今日时刻未到
      final todayKey = '${now.year}-${now.month}-${now.day}';
      if (_windowsLastFiredDate == todayKey) return; // 今日已触发
      //写入放在展示之后（见 _showWindowsNotification）：展示失败时当天还能重试
      await _showWindowsNotification(
        title: _windowsReminderTitle ?? '学习提醒',
        body: _windowsReminderBody ?? '该背单词啦，坚持就是胜利！',
        firedDateKey: todayKey,
      );
    });
  }

  Future<void> _loadWindowsLastFiredDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _windowsLastFiredDate =
          prefs.getString(_keyWindowsLastFiredDate) ?? _windowsLastFiredDate;
    } catch (e) {
      debugPrint('通知服务：读取 Windows 提醒触发日期失败 - $e');
    }
  }

  Future<void> _saveWindowsLastFiredDate(String dateKey) async {
    _windowsLastFiredDate = dateKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyWindowsLastFiredDate, dateKey);
    } catch (e) {
      debugPrint('通知服务：保存 Windows 提醒触发日期失败 - $e');
    }
  }

  /// 通过 local_notifier 显示 Windows Toast 通知。
  ///
  /// 提示音由 [ReminderSoundService] 播放（受其 enabled 开关控制）：
  /// local_notifier 的 Windows 端不读 [LocalNotification.silent]
  /// （插件 C++ 只取 identifier/title/body/actions），系统 Toast 音关不掉，
  /// 但用户常在系统设置里把通知音整体静音——此时应用侧提示音是提醒
  /// 唯一的声音来源；若系统 Toast 音开着，两声会短暂重叠，可接受。
  /// 设置页的「提醒声音」开关即写入 ReminderSoundService.enabled，
  /// 不接通这里的话该开关毫无作用。
  ///
  /// [firedDateKey] 非空表示这次是每日提醒：展示成功后才记入"今日已触发"，
  /// 展示失败时当天还能在下一分钟的轮询里重试。
  Future<void> _showWindowsNotification({
    required String title,
    required String body,
    String? firedDateKey,
  }) async {
    try {
      final notification = LocalNotification(title: title, body: body);
      notification.onShow = () {
        debugPrint('通知服务：Windows 通知已显示 - $title');
      };
      notification.onClick = () {
        // 应用正在运行，点击回调可达：直接把 payload 交给首页做跳转，
        // 否则 Windows 上点通知什么都不会发生
        debugPrint('通知服务：Windows 通知被点击 - $title');
        pendingLaunchPayload.value = payloadDailyReminder;
      };
      await notification.show();
      // 提示音播放失败不该影响"今日已触发"的记录，内部自行兜底
      unawaited(
        ReminderSoundService.instance.playReminderSound().catchError(
          (Object e) => debugPrint('通知服务：提醒提示音播放失败 - $e'),
        ),
      );
      if (firedDateKey != null) {
        await _saveWindowsLastFiredDate(firedDateKey);
      }
    } catch (e) {
      debugPrint('通知服务：Windows 通知显示失败 - $e');
    }
  }

  /// 计算下一个指定时刻的时区时间（若今日已过则顺延到明日）
  ///
  /// 用 `TZDateTime.from(本地墙上时间, tz.local)` 而不是
  /// `TZDateTime(tz.local, y, m, d, h, min)`：
  /// 后者把 "20:00" 解释成 **tz.local 时区**的 20:00，一旦 tz.local 退化到
  /// UTC（时区通道不可用/ROM 返回非 IANA 名称时的兜底），在 UTC+8 上就会
  /// 实际 04:00 才触发；`from` 取的是"本地墙上时间对应的绝对时刻"，
  /// 无论 tz.local 是正确时区、整点偏移兜底还是 UTC，触发的都是本地 20:00。
  /// 顺延一天用日历构造而非 `add(Duration(days: 1))`：后者是绝对时长，
  /// 跨夏令时切换日会把本地钟点推移 1 小时。
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = DateTime.now();
    var wall = DateTime(now.year, now.month, now.day, hour, minute);
    if (wall.isBefore(now)) {
      wall = DateTime(now.year, now.month, now.day + 1, hour, minute);
    }
    return tz.TZDateTime.from(wall, tz.local);
  }

  /// 取消每日提醒（用户主动关闭）。
  ///
  /// 连同"今日已触发"标记一起清除：否则同一天里关闭再重新开启后，
  /// Windows 路径会因"今日已发"判定而不再补发。
  Future<void> cancelReminder() => _cancelReminder(clearFiredDate: true);

  /// 取消每日提醒的内部实现。
  ///
  /// [clearFiredDate] 为 false 时不碰 [_windowsLastFiredDate]：scheduleDailyReminder
  /// 开头也会调用这里做"先取消再重排"，若清掉标记，同一天内改一次提醒时间就会重复弹一次。
  Future<void> _cancelReminder({required bool clearFiredDate}) async {
    // 取消 Windows Timer
    _windowsDailyTimer?.cancel();
    _windowsDailyTimer = null;
    _windowsReminderHour = null;
    _windowsReminderMinute = null;
    _windowsReminderTitle = null;
    _windowsReminderBody = null;
    if (clearFiredDate) {
      _windowsLastFiredDate = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyWindowsLastFiredDate);
      } catch (e) {
        debugPrint('通知服务：清除 Windows 提醒触发日期失败 - $e');
      }
    }

    // 冷启动时通知初始化不再阻塞首帧（见 DIContainer.init），
    // 因此这里可能先于初始化被调用（例如启动时恢复"提醒已关闭"的设置）：
    // 不确定初始化完成就取消，会漏掉这次取消、留下一条已过期的提醒。
    if (!_initialized) await init();
    if (!_supported) return;
    try {
      if (!isWindowsPlatform) {
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
      if (isWindowsPlatform) {
        // Windows 使用 local_notifier
        await _showWindowsNotification(title: title, body: body);
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
    final payload = response.payload;
    debugPrint('通知被点击：payload=$payload');
    if (payload != null && payload.isNotEmpty) {
      _instance.pendingLaunchPayload.value = payload;
    }
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
