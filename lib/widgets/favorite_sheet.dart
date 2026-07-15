import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/favorite_word.dart';
import '../services/di_container.dart';
import '../utils/error_handler.dart';
import '../utils/translations.dart';
import 'fluid_dialog.dart';

/// 收藏 / 编辑收藏弹层
///
/// 用法：
/// ```dart
/// final result = await showFavoriteSheet(context, wordId: id);
/// if (result != null) {
///   // 用户确认 - result.groupName / result.note
/// }
/// ```
///
/// [edit] 为 true 时会预填当前分组与备注；为 false 时使用默认分组。
Future<({String groupName, String? note})?> showFavoriteSheet(
  BuildContext context, {
  required int wordId,
  bool edit = false,
}) async {
  final di = context.read<DIContainer>();
  final repo = di.favoriteRepository;
  try {
    final groups = await repo.getGroups();
    FavoriteWord? existing;
    if (edit) {
      existing = await repo.getByWordId(wordId);
    }
    if (!context.mounted) return null;
    return _showChooser(context, groups, existing);
  } catch (e) {
    if (context.mounted) {
      ErrorHandler.handleException(context, e, fallbackMessage: '加载收藏信息失败');
    }
    return null;
  }
}

Future<({String groupName, String? note})?> _showChooser(
  BuildContext context,
  List<MapEntry<String, int>> groups,
  FavoriteWord? existing,
) {
  final key = GlobalKey<_FavoriteSheetState>();
  final tr = context.tr;
  return showFluidDialog<({String groupName, String? note})>(
    context: context,
    title: existing == null ? tr.addToFavorites : tr.editFavorite,
    content: _FavoriteSheet(key: key, groups: groups, existing: existing),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(tr.cancel),
      ),
      TextButton(
        onPressed: () => key.currentState?._confirm(),
        child: Text(tr.confirm),
      ),
    ],
  );
}

class _FavoriteSheet extends StatefulWidget {
  final List<MapEntry<String, int>> groups;
  final FavoriteWord? existing;

  const _FavoriteSheet({super.key, required this.groups, this.existing});

  @override
  State<_FavoriteSheet> createState() => _FavoriteSheetState();
}

class _FavoriteSheetState extends State<_FavoriteSheet> {
  late String _selectedGroup;
  late TextEditingController _noteController;
  late TextEditingController _newGroupController;
  String? _pendingNewGroup;

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.existing?.groupName ?? FavoriteWord.defaultGroup;
    _noteController = TextEditingController(text: widget.existing?.note ?? '');
    _newGroupController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _newGroupController.dispose();
    super.dispose();
  }

  void _confirm() {
    final newGroup = _pendingNewGroup;
    final group = (newGroup != null && newGroup.trim().isNotEmpty)
        ? newGroup.trim()
        : _selectedGroup;
    final note = _noteController.text.trim();
    Navigator.of(
      context,
    ).pop((groupName: group, note: note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr.groupHint,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        _buildGroupChips(isDark),
        const SizedBox(height: 12),
        _buildNewGroupInput(isDark),
        const SizedBox(height: 16),
        Text(
          context.tr.noteHint,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        _buildNoteInput(isDark),
      ],
    );
  }

  Widget _buildGroupChips(bool isDark) {
    // 已有分组：去重
    final names = <String>{
      FavoriteWord.defaultGroup,
      ...widget.groups.map((e) => e.key),
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: names.map((name) {
        final selected = _pendingNewGroup == null && _selectedGroup == name;
        return ChoiceChip(
          label: Text(name),
          selected: selected,
          onSelected: (_) {
            setState(() {
              _pendingNewGroup = null;
              _selectedGroup = name;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildNewGroupInput(bool isDark) {
    return TextField(
      controller: _newGroupController,
      decoration: InputDecoration(
        hintText: context.tr.newGroupNameHint,
        prefixIcon: const Icon(Icons.add, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.black26,
          ),
        ),
      ),
      onChanged: (v) {
        if (v.trim().isNotEmpty) {
          setState(() => _pendingNewGroup = v.trim());
        } else {
          setState(() => _pendingNewGroup = null);
        }
      },
    );
  }

  Widget _buildNoteInput(bool isDark) {
    return TextField(
      controller: _noteController,
      minLines: 2,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: context.tr.noteHint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.black26,
          ),
        ),
      ),
    );
  }
}
