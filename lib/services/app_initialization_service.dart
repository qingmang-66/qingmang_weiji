import 'package:flutter/foundation.dart';

class AppInitializationService {
  static final ValueNotifier<int> resetSignal = ValueNotifier<int>(0);
  static final ValueNotifier<int> databaseRefreshSignal = ValueNotifier<int>(0);

  /// 开屏动画是否已经结束。
  ///
  /// 上下文引导的高亮位置依赖首页真实布局，若在开屏动画覆盖期间弹出，
  /// 高亮会落在被遮盖的位置上，因此需要等开屏结束再展示。
  static final ValueNotifier<bool> splashCompleted = ValueNotifier<bool>(false);

  static void notifyDatabaseRefreshed() {
    databaseRefreshSignal.value++;
  }

  static void showOnboardingAfterInitialization() {
    resetSignal.value++;
  }

  static void notifySplashCompleted() {
    splashCompleted.value = true;
  }
}
