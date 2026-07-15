import 'package:flutter/foundation.dart';

class AppInitializationService {
  static final ValueNotifier<int> resetSignal = ValueNotifier<int>(0);
  static final ValueNotifier<int> databaseRefreshSignal = ValueNotifier<int>(0);

  static void notifyDatabaseRefreshed() {
    databaseRefreshSignal.value++;
  }

  static void showOnboardingAfterInitialization() {
    resetSignal.value++;
  }
}
