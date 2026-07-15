import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P2 TTS', () {
    test('TtsService 含英文引擎检测', () {
      final source = File('lib/services/tts_service.dart').readAsStringSync();
      expect(source, contains('_detectEnglishEngine'));
      expect(source, contains('hasEnglishEngine'));
      expect(source, contains('getLanguages'));
      expect(source, contains('missing_en_engine'));
    });

    test('TTS 错误文案含语音包提示', () {
      final tr = File('lib/utils/translations.dart').readAsStringSync();
      expect(tr, contains('ttsMissingEngineMessage'));
      expect(tr, contains('英文语音'));
    });
  });

  group('P2 触控与生命周期', () {
    test('FluidButton 最小热区与震动', () {
      final source = File('lib/widgets/fluid_button.dart').readAsStringSync();
      expect(source, contains('minHeight: 48'));
      expect(source, contains('HapticFeedback'));
    });

    test('后台停止 TTS', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('didChangeAppLifecycleState'));
      expect(main, contains('ttsService.stop'));
      // inactive 不停播，避免下拉通知栏打断
      expect(main, isNot(contains('AppLifecycleState.inactive')));
    });
  });

  group('P2 系统栏', () {
    test('Edge-to-edge 与状态栏同步', () {
      final main = File('lib/main.dart').readAsStringSync();
      final ui = File('lib/utils/system_ui.dart').readAsStringSync();
      expect(main, contains('SystemUiMode.edgeToEdge'));
      expect(main, contains('applySystemUiOverlay'));
      expect(ui, contains('statusBarIconBrightness'));
    });
  });
}
