Future<String> audioCacheDir() async => '';

Future<bool> fileExists(String path) async => false;

Future<void> writeBytes(String path, List<int> bytes) async {}

Future<void> deleteIfExists(String path) async {}

/// 清空发音缓存（Web 无本地缓存，空实现）
Future<void> clearAudioCache() async {}

Future<void> pruneAudioCache(
  String audioDir, {
  required int maxFiles,
  required int maxBytes,
}) async {}
