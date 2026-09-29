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

/// 原子写入：先写 .tmp 再 rename。
///
/// 直接写目标路径时，写到一半被强杀/断电会留下半截文件，而它下次会被
/// `fileExists` 当成有效缓存命中（播放失败也不会重下），坏缓存永久生效。
Future<void> writeBytes(String path, List<int> bytes) async {
  final temp = File('$path.tmp');
  await temp.writeAsBytes(bytes, flush: true);
  try {
    await temp.rename(path);
  } catch (_) {
    // 跨分区等 rename 失败的情况：退回直接写目标（并清理临时文件）
    await File(path).writeAsBytes(bytes, flush: true);
    try {
      await temp.delete();
    } catch (_) {}
  }
}

Future<void> deleteIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) {
    try {
      await file.delete();
    } catch (_) {}
  }
}

/// 清空发音缓存（切换口音/音源后必须调用，否则旧口音的缓存会被继续命中）
Future<void> clearAudioCache() async {
  final dir = Directory(await audioCacheDir());
  if (!await dir.exists()) return;
  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    try {
      await entity.delete();
    } catch (_) {}
  }
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
