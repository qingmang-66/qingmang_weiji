import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsService', () {
    test('本地 TTS 播放失败时临时降级在线发音，且不改变全局发音源', () async {
      final calls = <String>[];
      final service = TtsService.test(
        speakLocal: (word) async {
          calls.add('local:$word');
          throw Exception('本地 TTS 不可用');
        },
        playOnline: (word) async => calls.add('online:$word'),
        configureLocal: (_) async {},
      );

      await service.init(isOnline: false, accent: 'uk');
      await service.playWord('apple');
      await service.playWord('banana');

      expect(calls, [
        'local:apple',
        'online:apple',
        'local:banana',
        'online:banana',
      ]);
    });

    test('更新发音源但未传 speechRate 时保留最近一次语速', () async {
      final configuredRates = <double>[];
      final service = TtsService.test(
        configureLocal: (rate) async => configuredRates.add(rate),
      );

      await service.init(isOnline: false, speechRate: 0.7);
      await service.updateSettings(isOnline: true);
      await service.updateSettings(isOnline: false);

      expect(configuredRates, [0.7, 0.7]);
    });
  });
}
