part of '../wordbook_reader_screen.dart';

/// 书签列表面板：在居中弹窗内展示，删除/重命名后即时刷新
class _BookmarkPanel extends StatefulWidget {
  final _WordbookReaderScreenState state;
  final ReaderSettingsProvider settings;

  const _BookmarkPanel({required this.state, required this.settings});

  @override
  State<_BookmarkPanel> createState() => _BookmarkPanelState();
}

class _BookmarkPanelState extends State<_BookmarkPanel> {
  _WordbookReaderScreenState get _st => widget.state;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);
    final bookmarks = _st._bookmarks;
    if (bookmarks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.tr.noBookmarksHint,
          style: TextStyle(color: textSecondary),
        ),
      );
    }
    //玻璃模式下列表面板包一层玻璃容器（嵌套时自动降级为果冻片）
    final list = SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.45,
      child: ListView.builder(
        // 父级 SizedBox 已经给出紧约束高度，shrinkWrap 只会强迫 viewport
        // 先把全部条目测量一遍（书签可能上百条），最终尺寸完全相同
        itemCount: bookmarks.length,
        itemBuilder: (_, i) {
          final b = bookmarks[i];
          final wordText = b.wordIndex < _st._words.length
              ? _st._words[b.wordIndex].word
              : '';
          return ListTile(
            leading: Icon(
              Icons.bookmark,
              color: FluidTheme.primaryFluidGradient[0],
            ),
            title: Text(
              _st._bookmarkName(b, i + 1, widget.settings),
              style: TextStyle(color: textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${_st._fmtDate(b.createdAt)} · $wordText',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _showMenu(b),
            ),
            onTap: () {
              Navigator.pop(context);
              _st._jumpToWord(b.wordIndex);
            },
          );
        },
      ),
    );
    if (!context.isLiquidGlass) return list;
    return GlassSurface(borderRadius: 24, grain: true, child: list);
  }

  Future<void> _showMenu(ReaderBookmark b) async {
    final v = await showFluidDialog<String>(
      context: context,
      maxWidth: 320,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _st._menuAction(
            icon: Icons.edit_outlined,
            label: context.tr.renameBookmarkBtn,
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          _st._menuAction(
            icon: Icons.delete_outline,
            label: context.tr.deleteBookmarkBtn,
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    );
    if (v == null || !mounted) return;
    final dao = DatabaseService.readerDao;
    if (v == 'rename') {
      final name = await _st._promptName(
        b.customName?.isNotEmpty == true
            ? b.customName
            : _st._defaultName(b.wordIndex),
      );
      if (name == null || name.trim().isEmpty) return;
      await dao.renameBookmark(b.id, name.trim());
    } else if (v == 'delete') {
      await dao.deleteBookmark(b.id);
    } else {
      return;
    }
    //重新拉取并立即刷新列表：交给宿主刷新，避免面板自身 setState 直接改写
    //宿主私有字段（两者生命周期不一致）；但弹窗 content 不随宿主重建，
    //面板也要自绘一次才能立刻反映删除/重命名结果
    final bookId = _st.widget.bookId;
    final list = await dao.getBookmarks(bookId);
    _st.refreshBookmarks(list);
    if (mounted) setState(() {});
  }
}
