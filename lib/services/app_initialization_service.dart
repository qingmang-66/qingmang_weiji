import 'package:flutter/foundation.dart';

class AppInitializationService {
  static final ValueNotifier<int> resetSignal = ValueNotifier<int>(0);

  static void showOnboardingAfterInitialization() {
    resetSignal.value++;
  }
}
