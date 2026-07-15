import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'file_compat.dart';
import 'picked_file_io.dart'
    if (dart.library.html) 'picked_file_web.dart' as impl;

/// 将 FilePicker 结果解析为可读路径文件
class PickedFileHelper {
  static Future<AppFile?> resolveToFile(PlatformFile platformFile) async {
    return impl.resolveToFile(platformFile);
  }

  static Future<AppFile?> pickSingleFile({
    required List<String> extensions,
    String? dialogTitle,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      dialogTitle: dialogTitle,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    return resolveToFile(result.files.first);
  }

  static String basename(String path) => p.basename(path);
}
