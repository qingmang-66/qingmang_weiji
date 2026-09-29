import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 全局交互活动监视器（高刷新率 / LTPO 适配）。
///
/// 背景光斑、shimmer 等**常驻循环动画**会让屏幕"永远有内容在变"：
/// - Android 的 LTPO 面板（1~120Hz 自适应）只有在没有任何持续动画时
///   才会把刷新率降到 1Hz 省电，循环动画会让它一直保持高刷；
/// - Windows 的 60/90/120Hz 高刷屏同样会因为循环动画持续出帧。
///
/// 这里记录最后一次指针/键盘活动时间：空闲超过 [idleAfter] 后 [idle] 置为
/// true，各处循环动画据此暂停（画面冻结在当前位置，不跳变）；任何交互都会
/// 立即唤醒（下一帧恢复）。一次性动画（入场/弹簧/转场/翻页）不受影响——
/// 它们本身只有一个生命周期，不会阻止系统降频。
///
/// 指针事件用 [PointerRouter] 全局路由观察，不包裹组件、不参与命中测试、
/// 不消费任何手势。
class AppIdleMonitor with WidgetsBindingObserver {
  AppIdleMonitor._();

  static final AppIdleMonitor instance = AppIdleMonitor._();

  /// 空闲多久后暂停循环动画。
  ///
  /// 3 秒覆盖翻页、停顿思考这类中间态；太短会让静态阅读场景频繁冻结/唤醒，
  /// 太长则 LTPO 降频收益被推迟。
  Duration idleAfter = const Duration(seconds: 3);

  /// 是否处于空闲（循环动画应暂停）。动画宿主监听此值决定起停。
  final ValueNotifier<bool> idle = ValueNotifier<bool>(false);

  DateTime _lastActivity = DateTime.now();
  Timer? _idleTimer;
  bool _started = false;

  /// 在 runApp 之前（WidgetsFlutterBinding.ensureInitialized 之后）调用一次。
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    // 全局指针路由：只观察、不影响命中测试与手势竞技
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _scheduleIdleCheck();
  }

  /// 停止观察（测试与生命周期收尾用）
  void stop() {
    if (!_started) return;
    _started = false;
    _idleTimer?.cancel();
    _idleTimer = null;
    // 复位空闲态：否则在"空闲"状态停止后，监听者会永远停在暂停状态
    idle.value = false;
    WidgetsBinding.instance.removeObserver(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
  }

  /// 手动标记一次活动（非指针场景：通知点击、程序化切页等）
  void markActivity() {
    // stop() 之后不应再武装定时器（否则测试会报 "Timer is still pending"，
    // 运行期也会在已停止观察后继续改 idle）
    if (!_started) return;
    _lastActivity = DateTime.now();
    if (idle.value) idle.value = false;
    _scheduleIdleCheck();
  }

  void _onPointerEvent(PointerEvent event) {
    // 只把"用户的主动交互"算作活动；合成的 hover（桌面鼠标停留）也算，
    // 成本极低（重置一个计时器）
    markActivity();
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) markActivity();
    return false; // 不消费，只观察
  }

  /// 距离上次活动多久才需要重新排一次检查
  ///
  /// 高刷屏 + 高回报率鼠标的 hover/move 可达 100+ Hz，每个事件都
  /// cancel + 新建 Timer 会持续产生对象分配与定时器抖动（与本类"省电"的
  /// 目标相反）。这里做 200ms 节流：只有活动间隔超过阈值才重建定时器，
  /// 而空闲判定的精度不受影响（3s 量级）。
  static const Duration _rescheduleThreshold = Duration(milliseconds: 200);
  DateTime _lastSchedule = DateTime.fromMillisecondsSinceEpoch(0);

  void _scheduleIdleCheck() {
    final now = DateTime.now();
    // 只在"定时器still在跑 且 距上次排程不到节流窗口"时跳过重建；
    // 已触发的定时器（isActive=false）必须重建，否则空闲态永远不会翻转
    if (_idleTimer?.isActive == true &&
        now.difference(_lastSchedule) < _rescheduleThreshold) {
      return;
    }
    _lastSchedule = now;
    _idleTimer?.cancel();
    _idleTimer = Timer(idleAfter, _onIdleTick);
  }

  void _onIdleTick() {
    _idleTimer = null;
    if (idle.value) return;
    final since = DateTime.now().difference(_lastActivity);
    if (since >= idleAfter) {
      idle.value = true;
      return;
    }
    // 还差一点：按剩余时间重排，而不是"再来一整个 idleAfter"
    //（否则实际进入空闲可能被拖到 2×idleAfter）
    _lastSchedule = DateTime.fromMillisecondsSinceEpoch(0);
    _idleTimer?.cancel();
    _idleTimer = Timer(idleAfter - since, _onIdleTick);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回到前台视为活动：用户回来时应立即看到动画在动
    if (state == AppLifecycleState.resumed) markActivity();
  }
}
