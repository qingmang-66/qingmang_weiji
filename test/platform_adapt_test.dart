import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/utils/platform_adapt.dart';

void main() {
  group('PlatformAdapt', () {
    test('Windows 判定为桌面', () {
      if (!Platform.isWindows) return;
      expect(PlatformAdapt.isDesktop, isTrue);
      expect(PlatformAdapt.isMobile, isFalse);
    });

    test('FluidPage 与动画策略源码存在', () {
      final source = File('lib/utils/platform_adapt.dart').readAsStringSync();
      expect(source, contains('allowBackgroundAnimation'));
      expect(source, contains('showKeyboardShortcuts'));
      expect(source, contains('class FluidPage'));
    });
  });

  group('P1 适配落点', () {
    test('FluidBackground 支持生命周期停动画', () {
      final source = File(
        'lib/widgets/fluid_background.dart',
      ).readAsStringSync();
      expect(source, contains('WidgetsBindingObserver'));
      expect(source, contains('didChangeAppLifecycleState'));
      expect(source, contains('PlatformAdapt.allowBackgroundAnimation'));
    });

    test('学习页支持左右滑评分', () {
      final source = File('lib/screens/study_screen.dart').readAsStringSync();
      expect(source, contains('onHorizontalDragEnd'));
      expect(source, contains('_onSwipeQuality'));
      expect(source, contains('SafeArea'));
    });

    test('主学习流支持左右滑且桌面才显示快捷键', () {
      final source = File(
        'lib/screens/pre_study_screen.dart',
      ).readAsStringSync();
      expect(source, contains('PlatformAdapt.showKeyboardShortcuts'));
      expect(source, contains('onHorizontalDragEnd'));
      expect(source, contains('_onSwipeQuality'));
    });

    test('ECDICT 延迟初始化、后台预热与分块拷贝', () {
      final dict = File(
        'lib/services/local_dictionary_service.dart',
      ).readAsStringSync();
      final main = File('lib/main.dart').readAsStringSync();
      expect(dict, contains('warmUpInBackground'));
      expect(dict, contains('_initFuture'));
      expect(dict, contains('openWrite'));
      expect(dict, contains('1024 * 1024'));
      expect(main, contains('LocalDictionaryService.warmUpInBackground'));
    });
  });
}
