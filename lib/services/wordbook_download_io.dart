import 'dart:io';
import 'package:path/path.dart' as p;

Future<void> ensureParentDir(String filePath) async {
  final dir = Directory(p.dirname(filePath));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

Future<void> writeString(String path, String content) async {
  await File(path).writeAsString(content);
}
