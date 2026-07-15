import 'dart:io';

class AppFile {
  final String path;
  AppFile(this.path);
  int lengthSync() {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }
}
