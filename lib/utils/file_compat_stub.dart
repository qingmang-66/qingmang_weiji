/// Web/桌面统一的文件路径包装
library;

import 'dart:typed_data';

class AppFile {
  final String path;
  final Uint8List? bytes;

  /// 是否为应用自己生成的临时副本（无文件系统平台恒为 false）
  final bool isTemporary;

  AppFile(this.path, [this.bytes, this.isTemporary = false]);

  int lengthSync() => bytes?.length ?? 0;

  /// 异步读取文件大小（无文件系统平台直接返回内存长度）
  Future<int> length() async => bytes?.length ?? 0;

  /// 无文件系统平台无需清理
  Future<void> cleanup() async {}
}
