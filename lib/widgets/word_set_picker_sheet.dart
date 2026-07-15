import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/repositories/custom_word_set_repository.dart';
import '../utils/error_handler.dart';
import '../utils/translations.dart';
import 'fluid_dialog.dart';

/// 弹出"加入单词集"选择器。
///
/// 适用场景：
/// - 单词详情页加入收藏夹后立即入库
/// - 搜索结果列表项加入词集
/// - 后续收藏夹、错词页加入词集时也可复用
///
/// 行为：
/// - 如果没有任何自定义词集，直接弹创建对话框
/// - 如果已有词集，弹居中菜单让用户选择或创建新词集
/// - 成功加入后通过 [ErrorHandler.showSuccess] 提示
/// - 异常时通过 [ErrorHandler.handleException] 统一处理
///
/// 返回 [Future<bool>]：true 表示已成功加入某个词集，false 表示用户取消或失败。
Future<bool> showWordSetPickerSheet(
  BuildContext context, {
  required int wordId,
}) async {
  final repo = context.read<DIContainer>().customWordSetRepository;
  final tr = context.tr;
  try {
    final sets = await repo.getAllSets();
    if (!context.mounted) return false;
    final wordSetId = await _showChooser(context, sets, repo);
    if (wordSetId == null || !context.mounted) return false;

    // 阶段三：自定义词集增强 - 重复加入检测，给用户明确反馈
    final already = await repo.isWordInSet(wordSetId, wordId);
    if (!context.mounted) return false;
    if (already) {
      ErrorHandler.showSuccess(context, tr.wordAlreadyInSet);
      return true;
    }

    await repo.addWords(wordSetId, [wordId]);
    if (!context.mounted) return true;
    ErrorHandler.showSuccess(context, tr.addedToSet);
    return true;
  } catch (e) {
    if (context.mounted) {
      ErrorHandler.handleException(
        context,
        e,
        fallbackMessage: tr.addToSetFailed,
      );
    }
    return false;
  }
}

/// 显示选择器：居中菜单（已有词集）或创建对话框（无词集）
///
/// 返回选中的 wordSetId；用户取消返回 null。
Future<int?> _showChooser(
  BuildContext context,
  List<CustomWordSet> sets,
  CustomWordSetRepository repo,
) async {
  final tr = context.tr;
  if (sets.isEmpty) {
    // 没有词集时直接弹创建对话框
    final name = await _showCreateSetDialog(context);
    if (name == null || name.trim().isEmpty) return null;
    if (!context.mounted) return null;
    return await repo.createSet(name: name.trim());
  }

  // 已有词集：弹居中菜单
  final selected = await showFluidDialog<_SetChoice>(
    context: context,
    title: tr.addToSet,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(tr.createNewSet),
          onTap: () => Navigator.pop(context, _SetChoice.createNew()),
        ),
        ...sets.map(
          (set) => ListTile(
            leading: const Icon(Icons.folder_special),
            title: Text(set.name),
            onTap: () => Navigator.pop(context, _SetChoice.existing(set)),
          ),
        ),
      ],
    ),
  );
  if (selected == null) return null;
  if (selected.isCreateNew) {
    if (!context.mounted) return null;
    final name = await _showCreateSetDialog(context);
    if (name == null || name.trim().isEmpty) return null;
    return await repo.createSet(name: name.trim());
  }
  return selected.setId;
}

Future<String?> _showCreateSetDialog(BuildContext context) {
  final controller = TextEditingController();
  final tr = context.tr;
  return showFluidDialog<String>(
    context: context,
    title: tr.createWordSet,
    content: TextField(
      controller: controller,
      autofocus: true,
      decoration: InputDecoration(hintText: tr.setNameHint),
      onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr.cancel),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: Text(tr.create),
      ),
    ],
  );
}

/// 菜单返回值：用户选了某个已有词集或选择创建新词集。
class _SetChoice {
  final int? setId;
  final bool isCreateNew;

  _SetChoice.createNew() : setId = null, isCreateNew = true;

  _SetChoice.existing(CustomWordSet set) : setId = set.id, isCreateNew = false;
}
