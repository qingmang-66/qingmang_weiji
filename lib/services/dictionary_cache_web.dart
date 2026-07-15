Future<String> audioCacheDir() async => '';

Future<bool> fileExists(String path) async => false;

Future<void> writeBytes(String path, List<int> bytes) async {}

Future<void> pruneAudioCache(
  String audioDir, {
  required int maxFiles,
  required int maxBytes,
}) async {}
