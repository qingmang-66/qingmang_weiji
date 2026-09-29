import 'package:sqflite/sqflite.dart';

/// DAO 的数据库句柄归一化。
///
/// 生产路径传入 [DatabaseService.databaseHandle]（函数）：数据库打开失败
/// 自愈（见 `DatabaseService.database`）后，DAO 会自动拿到新句柄；
/// 测试与旧式调用可能直接传入已打开的 `Future<Database>`，这里统一归一化为
/// "每次访问重新求值"的函数形式，两种写法都能工作。
Future<Database> Function() normalizeDbHandle(Object handle) {
  if (handle is Future<Database> Function()) return handle;
  if (handle is Future<Database>) return () => handle;
  throw ArgumentError.value(
    handle,
    'dbHandle',
    '数据库句柄需要 Future<Database> 或它的提供函数',
  );
}
