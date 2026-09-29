import 'package:flutter/widgets.dart';
import 'file_compat.dart';

//Web端不支持本地图片背景，空实现
Future<String?> saveReaderBackground(AppFile file, String ext) async => null;

/// 清理旧壁纸（Web 无本地文件，空实现）
Future<void> cleanOldReaderBackgrounds({String? keepPath}) async {}

bool readerBgFileExists(String path) => false;

Widget? readerBgImage(String path, {int? cacheWidth}) => null;
