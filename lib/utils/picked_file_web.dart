import 'dart:convert';
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';
import 'file_compat.dart';

Future<AppFile?> resolveToFile(PlatformFile platformFile) async {
  final bytes = platformFile.bytes;
  if (bytes == null || bytes.isEmpty) return null;
  // Web 写入内存 blob URL，供后续读取
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  // 额外缓存文本内容，方便 restoreFromRaw
  final key = 'qm_pick_${DateTime.now().millisecondsSinceEpoch}';
  try {
    html.window.sessionStorage[key] = utf8.decode(bytes);
  } catch (_) {}
  return AppFile('webblob://$key|$url|${platformFile.name}');
}
