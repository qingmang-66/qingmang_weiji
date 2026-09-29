import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void initDesktopFfi() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

Future<bool> fileExists(String path) async => File(path).exists();

Future<void> writeBytesInChunks(String path, Uint8List bytes) async {
  final file = File(path);
  final sink = file.openWrite();
  const chunk = 1024 * 1024;
  for (var offset = 0; offset < bytes.length; offset += chunk) {
    final end = (offset + chunk > bytes.length) ? bytes.length : offset + chunk;
    sink.add(bytes.sublist(offset, end));
  }
  await sink.flush();
  await sink.close();
}

/// 追加写入一个资产分片（分片加载用：每次只把一片读进内存）。
///
/// 与 [writeBytesInChunks] 的分块不同：这里跨越多次 `rootBundle.load`，
/// 内存峰值从"整包词典大小"降到"单片大小"。
Future<void> appendBytes(String path, Uint8List bytes) async {
  await File(path).writeAsBytes(bytes, mode: FileMode.append, flush: true);
}

Future<void> renameFile(String from, String to) async {
  await File(from).rename(to);
}

Future<void> deleteIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
