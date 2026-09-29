// Web 条件导入实现文件，需使用平台 Web API
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

String get pathSeparator => '/';

Future<void> writeBytes(String path, Uint8List bytes) async {}

String? windowsDesktopPath() => null;

String? macDesktopPath() => null;

Future<void> downloadBytes(
  String fileName,
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) async {
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
