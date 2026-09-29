import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// 备份文件需要口令才能解密（UI 据此弹出输入框后重试）
class BackupPasswordRequiredException implements Exception {
  const BackupPasswordRequiredException();

  @override
  String toString() => '该备份已加密，需要输入口令';
}

/// 口令错误或内容被篡改（AES-GCM 的认证失败）
class BackupPasswordException implements Exception {
  const BackupPasswordException();

  @override
  String toString() => '备份口令错误或文件已损坏';
}

/// 加密信封本身结构不合法（字段缺失/base64 解不开/迭代次数越界）。
///
/// 必须与 [BackupPasswordException] 区分开：这些情况下**口令一定是对的也没用**，
/// 统一报"口令错误"会让用户对着一个坏文件反复试口令（每次还要重跑 PBKDF2）。
class BackupFormatException implements Exception {
  const BackupFormatException(this.reason);

  final String reason;

  @override
  String toString() => '加密备份格式错误：$reason';
}

/// 加密备份的信封格式：
///
/// ```
/// {
///   "format": "qingmang-encrypted-backup",
///   "version": 1,
///   "kdf": "pbkdf2-hmac-sha256",
///   "iterations": 120000,
///   "cipher": "aes-256-gcm",
///   "salt": "<base64>",   // 16 字节随机盐
///   "nonce": "<base64>",  // 12 字节随机 nonce
///   "mac": "<base64>",    // GCM 认证标签（口令错误/内容被改都会校验失败）
///   "data": "<base64>"    // 密文（明文备份 JSON 的 UTF-8 字节）
/// }
/// ```
///
/// 历史明文备份不带 `format` 标记，恢复路径自动识别两种格式，向后兼容。
class BackupCrypto {
  static const String formatTag = 'qingmang-encrypted-backup';
  static const int _defaultIterations = 120000;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;

  static final AesGcm _algorithm = AesGcm.with256bits();
  static final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _defaultIterations,
    bits: 256,
  );

  /// 该 JSON 根节点是否为加密信封
  static bool isEncryptedEnvelope(Object? decoded) =>
      decoded is Map && decoded['format'] == formatTag;

  /// 加密明文备份 JSON，返回信封 JSON 字符串
  static Future<String> encrypt(String plainJson, String password) async {
    final salt = _randomBytes(_saltLength);
    final key = await _deriveKey(password, salt, _defaultIterations);
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plainJson),
      secretKey: key,
      nonce: _randomBytes(_nonceLength),
    );
    return jsonEncode({
      'format': formatTag,
      'version': 1,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': _defaultIterations,
      'cipher': 'aes-256-gcm',
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'data': base64Encode(secretBox.cipherText),
    });
  }

  /// 解密信封，返回明文备份 JSON；口令错误/内容被篡改统一抛
  /// [BackupPasswordException]（两者对用户的下一步动作相同：重试口令或换文件）
  /// 迭代次数的合法区间：下界防止"0 次派生"这种形同明文的口令保护，
  /// 上界防止被构造成 `iterations = 2^31` 之类的信封 —— PBKDF2 会在 isolate 里
  /// 跑上无限久，界面永远停在"恢复中"，用户只能杀进程。
  static const int _minIterations = 10000;
  static const int _maxIterations = 5000000;

  static Future<String> decrypt(
    Map<dynamic, dynamic> envelope,
    String password,
  ) async {
    final List<int> salt;
    final List<int> nonce;
    final List<int> mac;
    final List<int> data;
    final int iterations;
    try {
      salt = base64Decode(envelope['salt'] as String);
      nonce = base64Decode(envelope['nonce'] as String);
      mac = base64Decode(envelope['mac'] as String);
      data = base64Decode(envelope['data'] as String);
      iterations =
          (envelope['iterations'] as num?)?.toInt() ?? _defaultIterations;
    } catch (e) {
      // 结构就不对：与口令无关，直接告诉用户文件坏了
      throw const BackupFormatException('字段缺失或不是合法的 base64');
    }
    if (salt.isEmpty || nonce.isEmpty) {
      throw const BackupFormatException('salt/nonce 为空');
    }
    if (iterations < _minIterations || iterations > _maxIterations) {
      throw BackupFormatException(
        'iterations 越界（$iterations，允许 '
        '$_minIterations~$_maxIterations）',
      );
    }
    try {
      final key = await _deriveKey(password, salt, iterations);
      final clear = await _algorithm.decrypt(
        SecretBox(data, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      // 与恢复路径一致：明文容错解码，内容问题交给后续 JSON 校验报错
      return utf8.decode(clear, allowMalformed: true);
    } catch (e) {
      if (e is BackupFormatException) rethrow;
      // 到这里只可能是 GCM 认证失败 = 口令错误或内容被篡改
      throw const BackupPasswordException();
    }
  }

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    int iterations,
  ) {
    // PBKDF2 迭代次数随信封记录（未来提高强度时旧备份仍可解）
    final pbkdf2 = iterations == _defaultIterations
        ? _pbkdf2
        : Pbkdf2(
            macAlgorithm: Hmac.sha256(),
            iterations: iterations,
            bits: 256,
          );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  static List<int> _randomBytes(int length) {
    final rnd = Random.secure();
    return List<int>.generate(length, (_) => rnd.nextInt(256));
  }
}
