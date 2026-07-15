import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'file_compat.dart';

Future<AppFile?> resolveToFile(PlatformFile platformFile) async {
  final path = platformFile.path;
  if (path != null && path.isNotEmpty) {
    final file = File(path);
    if (await file.exists()) return AppFile(path);
  }
  final bytes = platformFile.bytes;
  if (bytes == null || bytes.isEmpty) return null;
  final dir = await getTemporaryDirectory();
  final name = platformFile.name.isNotEmpty
      ? platformFile.name
      : 'picked_file.bin';
  final safeName = p.basename(name);
  final file = File(
    p.join(
      dir.path,
      'qingmang_pick_${DateTime.now().millisecondsSinceEpoch}_$safeName',
    ),
  );
  await file.writeAsBytes(bytes, flush: true);
  return AppFile(file.path);
}
