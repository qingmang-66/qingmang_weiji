import 'dart:io';
import 'package:path/path.dart' as p;

/// 确保目录存在（桌面/移动端）
Future<void> ensureDirectoryExists(String path) async {
  final dir = Directory(p.dirname(path));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}
