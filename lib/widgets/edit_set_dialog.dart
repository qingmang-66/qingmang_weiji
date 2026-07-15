import 'package:flutter/material.dart';
import '../utils/translations.dart';

/// 自定义词集创建/编辑对话框
///
/// 接收初始名称和描述（编辑模式），返回非空 record 表示用户确认。
/// record 字段：
///   - name: 用户输入的名称（去首尾空格）
///   - description: 用户输入的描述；空字符串规范化为 null
Future<({String name, String? description})?> showEditSetDialog(
  BuildContext context, {
  required String title,
  required String confirmText,
  String initialName = '',
  String? initialDescription,
}) {
  final nameController = TextEditingController(text: initialName);
  final descController = TextEditingController(text: initialDescription ?? '');
  final tr = context.tr;
  return showDialog<({String name, String? description})>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: tr.setNameLabel,
                hintText: tr.setNameHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 2,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: tr.setDescriptionLabel,
                hintText: tr.setDescriptionHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr.cancel),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              final desc = descController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, (
                name: name,
                description: desc.isEmpty ? null : desc,
              ));
            },
            child: Text(confirmText),
          ),
        ],
      );
    },
  );
}
