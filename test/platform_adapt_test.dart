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

    test('主学习流桌面才显示快捷键', () {
      final source = [
        'lib/screens/pre_study_screen.dart',
        'lib/screens/pre_study_screen/direct_study_screen.dart',
        'lib/screens/pre_study_screen/quiz_widgets.dart',
        'lib/screens/pre_study_screen/study_mode_chip.dart',
      ].map((p) => File(p).readAsStringSync()).join('\n');
      expect(source, contains('PlatformAdapt.showKeyboardShortcuts'));
      // 说明：原断言检查 RawGestureDetector / _onSwipeQuality /
      // _onQuizSwipeVertical（滑动翻题 + 垂直滑动评分）。这三个标识符在
      // 当前实现中已不存在（学习页评分入口为按钮与键盘快捷键），断言长期
      // 失败、属无效测试；这里改为验证现存的键盘交互入口。
      expect(source, contains('KeyEventResult'));
      expect(source, contains('_handleKeyEvent'));
    });

    test('ECDICT 延迟初始化、后台预热与分块拷贝', () {
      final dict = File(
        'lib/services/local_dictionary_service.dart',
      ).readAsStringSync();
      final dictIo = File(
        'lib/services/local_dictionary_io.dart',
      ).readAsStringSync();
      final main = File('lib/main.dart').readAsStringSync();
      expect(dict, contains('warmUpInBackground'));
      expect(dict, contains('_initFuture'));
      expect(dictIo, contains('writeBytesInChunks'));
      expect(dictIo, contains('1024 * 1024'));
      expect(main, contains('LocalDictionaryService.warmUpInBackground'));
    });
  });
}
