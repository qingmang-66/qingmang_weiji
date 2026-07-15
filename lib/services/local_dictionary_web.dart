import 'dart:typed_data';

void initDesktopFfi() {}

Future<bool> fileExists(String path) async => false;

Future<void> writeBytesInChunks(String path, Uint8List bytes) async {}

Future<void> renameFile(String from, String to) async {}

Future<void> deleteIfExists(String path) async {}
