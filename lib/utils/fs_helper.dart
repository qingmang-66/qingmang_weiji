import 'fs_stub.dart' if (dart.library.io) 'fs_io.dart' as impl;

/// 确保目录存在（Web 空实现）
Future<void> ensureDirectoryExists(String path) =>
    impl.ensureDirectoryExists(path);
