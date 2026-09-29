import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsService', () {
    test('本地 TTS 失败时自动回退在线发音，不上报错误', () async {
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
      var errors = 0;
      final sub = service.errorStream.listen((_) => errors++);
      await service.playWord('apple');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      // 在线成功 ⇒ 用户听到声音，不该再弹窗打扰
      expect(calls, ['local:apple', 'online:apple']);
      expect(errors, 0);
    });

    test('在线发音失败时自动回退本地合成音，不上报错误', () async {
      final calls = <String>[];
      final service = TtsService.test(
        speakLocal: (word) async => calls.add('local:$word'),
        playOnline: (word) async {
          calls.add('online:$word');
          throw Exception('在线发音不可用');
        },
        configureLocal: (_) async {},
      );

      await service.init(isOnline: true);
      var errors = 0;
      final sub = service.errorStream.listen((_) => errors++);
      await service.playWord('apple');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(calls, ['online:apple', 'local:apple']);
      expect(errors, 0);
    });

    test('本地与在线都失败才上报 localFailed', () async {
      final calls = <String>[];
      final service = TtsService.test(
        speakLocal: (word) async {
          calls.add('local:$word');
          throw Exception('本地 TTS 不可用');
        },
        playOnline: (word) async {
          calls.add('online:$word');
          throw Exception('在线发音不可用');
        },
        configureLocal: (_) async {},
      );

      await service.init(isOnline: false, accent: 'uk');
      final eventFuture = service.errorStream.first;
      await service.playWord('apple');
      final captured = await eventFuture;

      expect(calls, ['local:apple', 'online:apple']);
      expect(captured.type, TtsErrorType.localFailed);
      expect(captured.word, 'apple');
    });

    test('切换发音源后重播仍然失败则上报 bothUnavailable', () async {
      final service = TtsService.test(
        speakLocal: (_) async => throw Exception('本地 TTS 不可用'),
        playOnline: (_) async => throw Exception('在线发音不可用'),
        configureLocal: (_) async {},
      );

      await service.init(isOnline: false);
      await service.switchToOnline();
      final eventFuture = service.errorStream.first;
      await service.playWordAfterSwitch('apple');
      final captured = await eventFuture;

      expect(captured.type, TtsErrorType.bothUnavailable);
      expect(captured.word, 'apple');
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

    test('switchToOnline 将发音源标记为在线', () async {
      final service = TtsService.test(configureLocal: (_) async {});
      await service.init(isOnline: false);
      expect(service.isOnline, isFalse);

      await service.switchToOnline();

      expect(service.isOnline, isTrue);
      expect(service.isOnlineAvailable, isTrue);
    });

    test('switchToLocal 将发音源标记为本地并重新配置 TTS', () async {
      var configureCount = 0;
      final service = TtsService.test(
        configureLocal: (_) async => configureCount++,
      );
      await service.init(isOnline: true);
      expect(service.isOnline, isTrue);

      await service.switchToLocal();

      expect(service.isOnline, isFalse);
      expect(service.isLocalAvailable, isTrue);
      expect(configureCount, 1);
    });

    test('playWordAfterSwitch 使用当前源播放', () async {
      final calls = <String>[];
      final service = TtsService.test(
        speakLocal: (word) async => calls.add('local:$word'),
        playOnline: (word) async => calls.add('online:$word'),
        configureLocal: (_) async {},
      );

      await service.init(isOnline: false);
      await service.switchToOnline();
      await service.playWordAfterSwitch('banana');

      expect(calls, ['online:banana']);
    });

    test('Windows 禁用本地 TTS 并上报错误，不调用本地配置或播放', () async {
      final calls = <String>[];
      final service = TtsService.test(
        isWindows: true,
        speakLocal: (word) async => calls.add('local:$word'),
        configureLocal: (_) async => calls.add('configure'),
      );
      final errors = <TtsErrorEvent>[];
      final subscription = service.errorStream.listen(errors.add);

      await service.init(isOnline: false);
      await service.playWord('apple');
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(calls, isEmpty);
      expect(service.isLocalAvailable, isFalse);
      // 初始化只标记不可用，实际播放时才上报
      expect(errors, hasLength(1));
      expect(errors.single.type, TtsErrorType.localFailed);
      expect(errors.single.word, 'apple');
    });
  });
}
