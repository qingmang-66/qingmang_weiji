import 'dart:io';

Future<String?> readText(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsString();
}
