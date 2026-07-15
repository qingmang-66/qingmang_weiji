import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
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

Future<void> renameFile(String from, String to) async {
  await File(from).rename(to);
}

Future<void> deleteIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
