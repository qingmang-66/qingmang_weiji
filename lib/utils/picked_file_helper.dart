import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'file_compat.dart';
import 'picked_file_io.dart'
    if (dart.library.html) 'picked_file_web.dart'
    as impl;

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
      // 必须 withData: false：Android 端 file_picker 会把 withData 映射成
      // "把整个文件读进 byte[]"，一个上百 MB 的备份/词库文件会在下游
      // 任何大小校验执行之前就把进程打爆（OOM 属 Error，插件内部兜不住）。
      // 三个调用方（导入词库 / 恢复备份 / 选壁纸）本来就只使用文件路径。
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return resolveToFile(result.files.first);
  }

  static String basename(String path) => p.basename(path);
}
