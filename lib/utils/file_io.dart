import 'dart:io';
import 'dart:typed_data';

String get pathSeparator => Platform.pathSeparator;

Future<void> writeBytes(String path, Uint8List bytes) async {
  await File(path).writeAsBytes(bytes, flush: true);
}

String? windowsDesktopPath() {
  final home = Platform.environment['USERPROFILE'];
  if (home == null || home.isEmpty) return null;
  return '$home\\Desktop';
}

String? macDesktopPath() {
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) return null;
  return '$home/Desktop';
}

Future<void> downloadBytes(
  String fileName,
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) async {
  // 非 Web 不需要浏览器下载
}
