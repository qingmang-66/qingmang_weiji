import 'dart:typed_data';

class AppFile {
  final String path;
  final Uint8List? bytes;

  /// 是否为应用自己生成的临时副本（Web 端无磁盘文件，恒为 false）
  final bool isTemporary;

  AppFile(this.path, [this.bytes, this.isTemporary = false]);

  int lengthSync() => bytes?.length ?? 0;

  /// 异步读取文件大小（Web 端内容已在内存，直接返回）
  Future<int> length() async => bytes?.length ?? 0;

  /// Web 端内容驻留内存，无需清理
  Future<void> cleanup() async {}
}
