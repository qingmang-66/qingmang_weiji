import 'fs_stub.dart' if (dart.library.io) 'fs_io.dart' as impl;

/// 确保目录存在（Web 空实现）
Future<void> ensureDirectoryExists(String path) =>
    impl.ensureDirectoryExists(path);

/// 文件是否存在（Web 恒 false）
Future<bool> fileExists(String path) => impl.fileExists(path);

/// 复制文件（Web 空实现）
Future<void> copyFile(String from, String to) => impl.copyFile(from, to);

/// 当前工作目录（Web 为 null）
String? get currentDirectoryPath => impl.currentDirectoryPath;
