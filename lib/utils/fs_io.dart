import 'dart:io';
import 'package:path/path.dart' as p;

/// 确保目录存在（桌面/移动端）
Future<void> ensureDirectoryExists(String path) async {
  final dir = Directory(p.dirname(path));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

/// 文件是否存在（桌面/移动端）
Future<bool> fileExists(String path) => File(path).exists();

/// 复制文件（桌面/移动端）
Future<void> copyFile(String from, String to) async {
  await File(from).copy(to);
}

/// 当前工作目录（桌面端用于迁移旧版"相对 CWD"的数据库文件）
String? get currentDirectoryPath => Directory.current.path;
