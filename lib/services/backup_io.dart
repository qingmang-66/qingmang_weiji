import 'dart:io';
import 'package:path/path.dart' as p;

Future<void> ensureDir(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) await dir.create(recursive: true);
}

Future<void> ensureParentDir(String filePath) async {
  await ensureDir(p.dirname(filePath));
}

Future<void> writeString(String path, String content) async {
  await File(path).writeAsString(content);
}

Future<String> readString(String path) async {
  final file = File(path);
  if (!await file.exists()) throw Exception('备份文件不存在');
  final size = await file.length();
  if (size > 20 * 1024 * 1024) throw Exception('备份文件过大，请选择小于20MB的备份文件');
  return file.readAsString();
}

Future<void> deleteIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}

Future<void> atomicReplace(String tempPath, String targetPath) async {
  final temp = File(tempPath);
  final target = File(targetPath);
  final previous = File('$targetPath.bak');
  if (await previous.exists()) await previous.delete();
  var movedAside = false;
  if (await target.exists()) {
    await target.rename(previous.path);
    movedAside = true;
  }
  try {
    try {
      await temp.rename(target.path);
    } catch (_) {
      await temp.copy(target.path);
      await temp.delete();
    }
    if (movedAside && await previous.exists()) await previous.delete();
  } catch (e) {
    if (movedAside && !await target.exists() && await previous.exists()) {
      await previous.rename(target.path);
    }
    rethrow;
  }
}

Future<List<String>> listJsonFiles(String directory) async {
  final dir = Directory(directory);
  if (!await dir.exists()) return [];
  final entries = <MapEntry<String, DateTime>>[];
  await for (final entity in dir.list()) {
    if (entity is File && entity.path.endsWith('.json')) {
      final stat = await entity.stat();
      entries.add(MapEntry(entity.path, stat.modified));
    }
  }
  entries.sort((a, b) => b.value.compareTo(a.value));
  return entries.map((e) => e.key).toList();
}

Future<void> downloadText(
  String fileName,
  String content, {
  String mimeType = 'text/plain',
}) async {}
