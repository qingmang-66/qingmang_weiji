import 'dart:io';

import '../utils/import_text.dart';

Future<String?> readText(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  // 读字节再自行解码：需要剥掉 UTF-8 BOM，并在不是 UTF-8 时给出
  // "请另存为 UTF-8" 这种可操作的提示（见 decodeImportTextBytes）
  return decodeImportTextBytes(await file.readAsBytes());
}

/// 读取文件字节数；文件不存在返回 null。
/// 用于「先判大小再读内容」，避免把超大文件整体读入内存。
Future<int?> fileSize(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.length();
}
