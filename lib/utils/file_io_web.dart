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
