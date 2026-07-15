import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> audioCacheDir() async {
  final dir = await getApplicationDocumentsDirectory();
  final audioDir = p.join(dir.path, 'audio_cache');
  final d = Directory(audioDir);
  if (!await d.exists()) {
    await d.create(recursive: true);
  }
  return audioDir;
}

Future<bool> fileExists(String path) async => File(path).exists();

Future<void> writeBytes(String path, List<int> bytes) async {
  await File(path).writeAsBytes(bytes);
}

Future<void> pruneAudioCache(
  String audioDir, {
  required int maxFiles,
  required int maxBytes,
}) async {
  final dir = Directory(audioDir);
  if (!await dir.exists()) return;
  final files = <File>[];
  await for (final entity in dir.list()) {
    if (entity is File) files.add(entity);
  }
  if (files.isEmpty) return;
  final stats = <File, FileStat>{};
  var totalBytes = 0;
  for (final file in files) {
    final stat = await file.stat();
    stats[file] = stat;
    totalBytes += stat.size;
  }
  if (files.length <= maxFiles && totalBytes <= maxBytes) return;
  files.sort((a, b) => stats[a]!.modified.compareTo(stats[b]!.modified));
  var count = files.length;
  for (final file in files) {
    if (count <= maxFiles && totalBytes <= maxBytes) break;
    final size = stats[file]?.size ?? 0;
    try {
      await file.delete();
      count--;
      totalBytes -= size;
    } catch (_) {}
  }
}
