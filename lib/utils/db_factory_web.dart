import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web 平台数据库初始化
void setupDatabaseFactory() {
  // 不使用 shared worker，避免缺少 sqflite_sw.js 时初始化失败
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}

DatabaseFactory? get webDatabaseFactory => databaseFactoryFfiWebNoWebWorker;
