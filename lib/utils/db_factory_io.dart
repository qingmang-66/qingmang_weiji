import 'dart:io' show Platform;

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 桌面/移动端数据库初始化
void setupDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Android/iOS/macOS 使用原生 sqflite 插件
}

DatabaseFactory? get webDatabaseFactory => null;
