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
