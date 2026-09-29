import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'file_compat.dart';

/// 阅读壁纸目录。
///
/// 放在应用自己的 AppSupport 目录下的子目录里，而不是用户"文档"根目录：
/// 后者会在用户可见的目录里写入文件名符合本应用命名规则的文件，还会让
/// 前缀清理（`reader_bg_*`）的误删面扩大到用户自己的同名文件。
Future<Directory> _readerBgDir() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory(p.join(base.path, 'reader_bg'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// 清理旧的 reader_bg 缓存文件（保留正在使用的那个）
///
/// 文件名格式为 `reader_bg_<时间戳>.<ext>`，早期实现按 `reader_bg.` 前缀匹配，
/// 永远匹配不到实际文件，导致每换一张壁纸都会永久残留一份。
/// 同时改为异步遍历，避免同步扫描整个目录阻塞 UI 线程。
Future<void> _cleanOldReaderBgFiles(
  Directory dir, {
  String? keepPath,
}) async {
  try {
    await for (final f in dir.list()) {
      if (f is! File) continue;
      final name = f.uri.pathSegments.last;
      if (!name.startsWith('reader_bg_') && !name.startsWith('reader_bg.')) {
        continue;
      }
      if (keepPath != null && f.path == keepPath) continue;
      await f.delete();
    }
  } catch (_) {}
}

/// 清理旧的壁纸文件（[keepPath] 之外的全部删掉）。
///
/// **必须在壁纸路径成功落盘之后调用**：反过来的顺序（先删旧图、再落盘设置）
/// 一旦设置写入失败/进程被杀，设置里仍指向已被删除的旧文件，用户的壁纸就
/// 静默消失了。
Future<void> cleanOldReaderBackgrounds({String? keepPath}) async {
  try {
    await _cleanOldReaderBgFiles(await _readerBgDir(), keepPath: keepPath);
  } catch (_) {}
}

/// 把选中的图片复制到应用目录，返回持久化路径
Future<String?> saveReaderBackground(AppFile file, String ext) async {
  try {
    final dir = await _readerBgDir();
    //用时间戳生成唯一文件名，避免图片缓存导致显示旧图
    final dst =
        '${dir.path}${Platform.pathSeparator}reader_bg_${DateTime.now().millisecondsSinceEpoch}.$ext';
    //先写新文件，确认成功后再由调用方（落盘设置之后）清理旧文件
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      await File(dst).writeAsBytes(file.bytes!, flush: true);
    } else {
      await File(file.path).copy(dst);
    }
    return dst;
  } catch (e) {
    // 磁盘满 / 无权限 / 源图损坏：保留错误原因，便于排查
    debugPrint('保存阅读背景失败：$e');
    return null;
  }
}

bool readerBgFileExists(String path) {
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}

/// [cacheWidth] 为解码宽度（物理像素），限制解码尺寸以降低壁纸与模糊开销
Widget readerBgImage(String path, {int? cacheWidth}) {
  return Image.file(
    File(path),
    fit: BoxFit.cover,
    cacheWidth: cacheWidth,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}
