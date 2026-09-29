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

/// 备份文件大小上限。
///
/// 恢复流程会把整个文件读成 String、再交给 isolate 解析 JSON，
/// 峰值内存约为文件体积的 3~4 倍：100MB 的备份在中端机上足以 OOM。
/// 收到 50MB（对应几十万条学习记录，远超正常使用量）。
const int maxBackupBytes = 50 * 1024 * 1024;

Future<String> readString(String path) async {
  final file = File(path);
  if (!await file.exists()) throw Exception('备份文件不存在');
  final size = await file.length();
  if (size > maxBackupBytes) {
    throw Exception('备份文件过大，请选择小于 ${maxBackupBytes ~/ (1024 * 1024)}MB 的备份文件');
  }
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
    await hardenFilePermission(target.path);
  } catch (e) {
    if (movedAside && !await target.exists() && await previous.exists()) {
      await previous.rename(target.path);
    }
    rethrow;
  }
}

/// 收紧备份文件的访问权限。
///
/// 备份默认落在"文档"目录的明文文件：
/// - Windows：同机其它标准用户/继承的 ACL 可能可读，这里移除继承并只授予
///   当前用户完全控制；`icacls` 不可用或权限不足时静默跳过。
/// - macOS/Linux：默认 umask 下文件常为 644（同机用户可读），收紧为 600。
/// 加固失败一律不影响备份流程。
Future<void> hardenFilePermission(String path) async {
  if (Platform.isWindows) {
    final user = Platform.environment['USERNAME'];
    if (user == null || user.isEmpty) return;
    try {
      await Process.run('icacls', [
        path,
        '/inheritance:r',
        '/grant:r',
        '$user:F',
      ]).timeout(const Duration(seconds: 5));
    } catch (_) {
      // 加固失败不影响备份可用性
    }
    return;
  }
  try {
    await Process.run('chmod', [
      '600',
      path,
    ]).timeout(const Duration(seconds: 5));
  } catch (_) {
    // 加固失败不影响备份可用性
  }
}

/// 清理中断残留的中间文件（`.tmp` / `.bak`）。
///
/// 备份采用"临时文件 + 原子替换"写入：进程在替换中途被杀（断电、强杀）
/// 会留下含**明文学习数据**的 `.bak`/`.tmp` 副本，既占空间又扩大泄露面。
/// 每次列出备份列表时顺带清理。
Future<void> cleanupStaleBackupTemps(String directory) async {
  final dir = Directory(directory);
  if (!await dir.exists()) return;
  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    final path = entity.path;
    if (path.endsWith('.bak')) {
      //atomicReplace 在"target 已改名为 .bak、temp→target 未完成"时被强杀会
      //留下 target 不存在、只有 .bak 的状态：此时 .bak 是唯一有效的上一份
      //备份（且不以 .json 结尾、列表里看不到），必须还原而不是删除
      final targetPath = path.substring(0, path.length - 4);
      if (!await File(targetPath).exists()) {
        try {
          await entity.rename(targetPath);
        } catch (_) {
          // 还原失败（被占用等）不影响主流程
        }
        continue;
      }
    } else if (!path.endsWith('.tmp')) {
      continue;
    }
    try {
      await entity.delete();
    } catch (_) {
      // 删除失败（被占用等）不影响主流程
    }
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
