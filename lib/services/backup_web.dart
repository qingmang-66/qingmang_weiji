import 'dart:convert';
import 'dart:html' as html;

Future<void> ensureDir(String path) async {}

Future<void> ensureParentDir(String filePath) async {}

Future<void> writeString(String path, String content) async {}

Future<String> readString(String path) async {
  throw Exception('Web端请通过文件选择器恢复备份');
}

Future<void> deleteIfExists(String path) async {}

Future<void> atomicReplace(String tempPath, String targetPath) async {}

Future<List<String>> listJsonFiles(String directory) async => [];

Future<void> downloadText(
  String fileName,
  String content, {
  String mimeType = 'text/plain',
}) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
