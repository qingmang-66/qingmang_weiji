import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('AndroidManifest', () {
    test('声明 TTS 服务查询能力，允许 Android 11+ 发现本地语音引擎', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android.intent.action.TTS_SERVICE'));
    });
  });
}
