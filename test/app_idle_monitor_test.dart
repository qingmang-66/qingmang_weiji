import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/utils/app_idle_monitor.dart';

void main() {
  // start() 依赖 WidgetsBinding 与 GestureBinding：纯 test() 不会自动初始化
  // binding，必须在最前面显式初始化（用真实时间，区别于 testWidgets 的
  // FakeAsync，空闲计时器才能自然到期）
  TestWidgetsFlutterBinding.ensureInitialized();

  // 高刷新率 / LTPO 适配的核心不变式：
  // 空闲 → idle=true（循环动画可暂停，系统得以降频）；
  // 任何交互 → 立即恢复 idle=false（动画唤醒）。
  test('空闲超时后进入 idle，交互后立即恢复', () async {
    final monitor = AppIdleMonitor.instance;
    monitor.idleAfter = const Duration(milliseconds: 60);
    monitor.start();
    addTearDown(() {
      monitor.stop();
      monitor.idle.value = false;
      monitor.idleAfter = const Duration(seconds: 3);
    });

    expect(monitor.idle.value, isFalse, reason: '启动即视为活动中');

    // 等过空闲阈值：进入 idle
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(monitor.idle.value, isTrue, reason: '无活动时应暂停循环动画');

    // 交互唤醒
    monitor.markActivity();
    expect(monitor.idle.value, isFalse, reason: '交互应立即恢复');

    // 再次空闲：重新进入 idle
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(monitor.idle.value, isTrue);
  });

  test('stop 后不再产生空闲通知（避免测试/生命周期残留定时器）', () async {
    final monitor = AppIdleMonitor.instance;
    monitor.idleAfter = const Duration(milliseconds: 40);
    monitor.markActivity();
    monitor.start();
    monitor.stop();

    var notified = 0;
    void listener() => notified++;
    monitor.idle.addListener(listener);
    addTearDown(() {
      monitor.idle.removeListener(listener);
      monitor.idle.value = false;
      monitor.idleAfter = const Duration(seconds: 3);
    });

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(notified, 0, reason: 'stop() 之后不应再有空闲翻转');
  });
}
