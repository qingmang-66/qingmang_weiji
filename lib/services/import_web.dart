// Web 条件导入实现文件，需使用平台 Web API
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<String?> readText(String path) async {
  if (path.startsWith('webblob://')) {
    final body = path.substring('webblob://'.length);
    final key = body.split('|').first;
    return html.window.sessionStorage[key];
  }
  if (path.startsWith('webmemory://')) {
    return Uri.decodeComponent(path.substring('webmemory://'.length));
  }
  return null;
}

/// Web 端内容直接驻留内存，没有独立的磁盘文件大小，返回 null 表示「无法预检」。
Future<int?> fileSize(String path) async => null;
