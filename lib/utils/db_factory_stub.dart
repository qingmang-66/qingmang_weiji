import 'package:sqflite/sqflite.dart';

/// 非Web/非IO平台的占位实现
void setupDatabaseFactory() {
  // 默认使用 sqflite 内置 factory
}

DatabaseFactory? get webDatabaseFactory => null;
