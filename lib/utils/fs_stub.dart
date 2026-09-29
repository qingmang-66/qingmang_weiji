/// 文件系统操作的 stub 实现（Web）
Future<void> ensureDirectoryExists(String path) async {
  // Web 无文件系统
}

/// 文件是否存在（Web 恒 false）
Future<bool> fileExists(String path) async => false;

/// 复制文件（Web 空实现）
Future<void> copyFile(String from, String to) async {}

/// 当前工作目录（Web 无此概念，返回 null）
String? get currentDirectoryPath => null;
