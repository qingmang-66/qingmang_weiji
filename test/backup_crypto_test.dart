import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/services/backup_crypto.dart';
import 'package:qingmang_weiji/services/backup_service.dart';
import 'package:qingmang_weiji/services/database_service.dart';

void main() {
  test('加密/解密往返，且信封不包含明文', () async {
    const plain = '{"appVersion":"3.1.0","schemaVersion":1,"tables":{}}';
    final envelope = await BackupCrypto.encrypt(plain, 'p@ss1234');

    // 信封是 JSON 且带格式标记；密文里不应出现明文片段
    final decoded = jsonDecode(envelope);
    expect(BackupCrypto.isEncryptedEnvelope(decoded), isTrue);
    expect(envelope.contains('schemaVersion'), isFalse);
    expect(envelope.contains('tables'), isFalse);

    final restored = await BackupCrypto.decrypt(
      Map<String, dynamic>.from(decoded as Map),
      'p@ss1234',
    );
    expect(restored, plain);
  });

  test('口令错误抛 BackupPasswordException（GCM 认证失败）', () async {
    final envelope = await BackupCrypto.encrypt('{"a":1}', 'right-password');
    final decoded = Map<String, dynamic>.from(jsonDecode(envelope) as Map);
    await expectLater(
      BackupCrypto.decrypt(decoded, 'wrong-password'),
      throwsA(isA<BackupPasswordException>()),
    );
  });

  test('密文被篡改时拒绝解密', () async {
    final envelope = await BackupCrypto.encrypt('{"a":1}', 'pw');
    final decoded = Map<String, dynamic>.from(jsonDecode(envelope) as Map);
    // 翻转载荷的最后一个字节
    final data = base64Decode(decoded['data'] as String);
    data[data.length - 1] = data.last ^ 0xFF;
    decoded['data'] = base64Encode(data);
    await expectLater(
      BackupCrypto.decrypt(decoded, 'pw'),
      throwsA(isA<BackupPasswordException>()),
    );
  });

  test('两次加密的盐/nonce 不同（相同明文得到不同密文）', () async {
    final a = await BackupCrypto.encrypt('{"a":1}', 'pw');
    final b = await BackupCrypto.encrypt('{"a":1}', 'pw');
    expect(a, isNot(equals(b)));
  });

  group('BackupService 恢复路径', () {
    setUp(() {
      BackupService.configureForTesting(
        backupDirectoryLoader: () async => 'unused',
        exportLoader: () async => const {},
        importLoader: (_) async {},
      );
    });

    test('加密备份：未提供口令抛 Required，口令正确则可恢复', () async {
      const raw = '{"appVersion":"3.1.0","schemaVersion":1,'
          '"tables":{"word_books":[{"id":1,"name":"书"}]}}';
      final envelope = await BackupCrypto.encrypt(raw, 'pw123');

      // 未提供口令 → 明确要求输入口令（而不是"文件格式错误"）
      await expectLater(
        BackupService.restoreFromRaw(envelope),
        throwsA(isA<BackupPasswordRequiredException>()),
      );
      // 口令错误
      await expectLater(
        BackupService.restoreFromRaw(envelope, password: 'bad'),
        throwsA(isA<BackupPasswordException>()),
      );
      // 口令正确 → 正常走校验与导入
      final result = await BackupService.restoreFromRaw(
        envelope,
        password: 'pw123',
      );
      expect(result['wordBooks'], 1);
    });

    test('历史明文备份不受影响（无需口令）', () async {
      const raw = '{"appVersion":"3.1.0","schemaVersion":1,'
          '"tables":{"word_books":[{"id":1,"name":"书"}]}}';
      final result = await BackupService.restoreFromRaw(raw);
      expect(result['wordBooks'], 1);
    });

    test('加密的空备份解密后仍被拒绝（数据保护不变式）', () async {
      const empty = '{"appVersion":"3.1.0","schemaVersion":1,"tables":{}}';
      final envelope = await BackupCrypto.encrypt(empty, 'pw');
      await expectLater(
        BackupService.restoreFromRaw(envelope, password: 'pw'),
        throwsA(isA<Exception>()),
      );
    });
  });

  test('schemaVersion 高于当前版本仍被拒绝', () async {
    final raw = jsonEncode({
      'appVersion': '9.9.9',
      'schemaVersion': DatabaseService.schemaVersion + 1,
      'tables': {
        'word_books': [
          {'id': 1},
        ],
      },
    });
    await expectLater(BackupService.restoreFromRaw(raw), throwsA(isA<Exception>()));
  });
}
