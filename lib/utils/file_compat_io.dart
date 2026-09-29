import 'dart:io';
import 'dart:typed_data';

class AppFile {
  final String path;
  final Uint8List? bytes;

  /// 是否为应用自己生成的临时副本（用完应调用 [cleanup] 删除）。
  /// 用户自己的原始文件始终为 false，避免误删。
  final bool isTemporary;

  AppFile(this.path, [this.bytes, this.isTemporary = false]);

  int lengthSync() {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return bytes?.length ?? 0;
    }
  }

  /// 异步读取文件大小：避免在 build/itemBuilder 等构建路径上做同步磁盘 IO
  Future<int> length() async {
    try {
      return await File(path).length();
    } catch (_) {
      return bytes?.length ?? 0;
    }
  }

  /// 删除临时副本；非临时文件不做任何操作
  Future<void> cleanup() async {
    if (!isTemporary) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 删除失败不影响主流程
    }
  }
}
