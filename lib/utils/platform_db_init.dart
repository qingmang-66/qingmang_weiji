import 'package:sqflite/sqflite.dart';

import 'db_factory_stub.dart'
    if (dart.library.io) 'db_factory_io.dart'
    if (dart.library.html) 'db_factory_web.dart'
    as impl;

/// 根据平台初始化数据库引擎
void initDatabaseFactory() {
  impl.setupDatabaseFactory();
}

/// Web 端 factory（非 Web 返回 null）
DatabaseFactory? get webDatabaseFactory => impl.webDatabaseFactory;
