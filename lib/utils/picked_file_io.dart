import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'file_compat.dart';

Future<AppFile?> resolveToFile(PlatformFile platformFile) async {
  final path = platformFile.path;
  if (path != null && path.isNotEmpty) {
    final file = File(path);
    if (await file.exists()) {
      // Android 上 file_picker 会把选中文件复制到 cache/file_picker/<ts>/<name>，
      // 那份副本只有 clearTemporaryFiles() 能清（按 qingmang_pick_ 前缀过滤的
      // 清理逻辑覆盖不到），于是每次导入词库 / 恢复备份 / 选壁纸都会在缓存里
      // 永久留一份完整副本（100MB 的备份就是 100MB 残留）。
      // 这里把它搬进应用自己的临时目录（同一分区 rename，零拷贝）并标记为
      // isTemporary，调用方用完 cleanup() 就能删掉。
      final adopted = await _adoptPickerCachedFile(file, platformFile.name);
      if (adopted != null) return adopted;
      // 用户自己的原始文件：保持只读语义，绝不删除
      return AppFile(path, platformFile.bytes);
    }
  }
  final bytes = platformFile.bytes;
  if (bytes == null || bytes.isEmpty) return null;
  final dir = await getTemporaryDirectory();
  final name = platformFile.name.isNotEmpty
      ? platformFile.name
      : 'picked_file.bin';
  final safeName = p.basename(name);
  //先清掉上次遗留的临时副本，避免中途放弃时无限累积
  await _cleanStalePickedFiles(dir);
  final file = File(
    p.join(
      dir.path,
      'qingmang_pick_${DateTime.now().millisecondsSinceEpoch}_$safeName',
    ),
  );
  await file.writeAsBytes(bytes, flush: true);
  //标记为临时文件：调用方用完可 cleanup() 删除
  return AppFile(file.path, bytes, true);
}

/// 把 file_picker 缓存目录里的副本"认领"到应用自己的临时目录。
///
/// 返回 null 表示这不是 picker 的缓存文件（是用户原始文件），或搬运失败，
/// 调用方应按原路径只读使用。
///
/// 判定必须严格：
/// - **仅 Android**：桌面端 file_picker 返回的就是用户文件的真实路径，
///   把"路径里含 `/file_picker/`"当成缓存副本，会把用户放在同名目录下的
///   文件（如 `D:\downloads\file_picker\backup.json`）搬走、并在流程结束时
///   被 cleanup() 删掉；
/// - 用 `p.isWithin` 做**路径段**比较，而不是 `contains` 字符串匹配；
/// - 必须在 picker 自己的缓存根（`<cacheDir>/file_picker/`）之内。
Future<AppFile?> _adoptPickerCachedFile(File source, String name) async {
  if (!Platform.isAndroid) return null;
  try {
    final cacheDir = await getTemporaryDirectory();
    final pickerRoot = p.join(cacheDir.path, 'file_picker');
    if (!p.isWithin(pickerRoot, source.path)) return null;

    final dir = await getTemporaryDirectory();
    await _cleanStalePickedFiles(dir);
    final safeName = name.isNotEmpty ? p.basename(name) : 'picked_file.bin';
    final target = File(
      p.join(
        dir.path,
        'qingmang_pick_${DateTime.now().millisecondsSinceEpoch}_$safeName',
      ),
    );
    // 同分区 rename：不产生额外拷贝，也不占双份空间
    await source.rename(target.path);
    // 顺手清掉 picker 遗留的其它副本与空目录（本次要用的文件已经搬走，
    // clearTemporaryFiles 只删 cache/file_picker，不会碰到我们的临时目录）
    try {
      await FilePicker.platform.clearTemporaryFiles();
    } catch (_) {
      // 清理失败不影响本次流程
    }
    return AppFile(target.path, null, true);
  } catch (_) {
    return null;
  }
}

/// 删除 24 小时前创建的临时副本（保留最近的，避免误删正在使用的文件）
Future<void> _cleanStalePickedFiles(Directory dir) async {
  try {
    final deadline = DateTime.now().subtract(const Duration(hours: 24));
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith('qingmang_pick_')) continue;
      final stat = await entity.stat();
      if (stat.modified.isBefore(deadline)) {
        await entity.delete();
      }
    }
  } catch (_) {
    // 清理失败不影响正常流程
  }
}
