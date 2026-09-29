import 'package:flutter/widgets.dart';
import 'file_compat.dart';

//Web端不支持本地图片背景，空实现
Future<String?> saveReaderBackground(AppFile file, String ext) async => null;

/// 清理旧壁纸（Web 无本地文件，空实现）
Future<void> cleanOldReaderBackgrounds({String? keepPath}) async {}

bool readerBgFileExists(String path) => false;

/// Web 无本地文件，返回空占位。
/// 返回类型必须与 reader_bg_io.dart 的 `Widget readerBgImage` 保持一致：
/// 条件导入下两侧签名不一致时，调用点的三元表达式会被推断成 `Widget?`，
/// flutter analyze 看不见（它只解析 io 侧），只有 flutter build web 才报。
Widget readerBgImage(String path, {int? cacheWidth}) => const SizedBox.shrink();
