import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../theme/fluid_theme.dart';
import '../widgets/fluid_dialog.dart';
import 'translations.dart';

/// 错误处理工具类
class ErrorHandler {
  /// 显示错误提示（居中弹窗）
  static void showError(BuildContext context, String message) {
    // 必须先判存活再读 context.tr：context.tr 内部是
    // dependOnInheritedWidgetOfExactType，element 已 deactivate/dispose 时
    // debug 下直接断言崩溃、release 下可能抛 ProviderNotFoundException
    if (!context.mounted) return;
    final tr = context.tr;
    showFluidDialog<void>(
      context: context,
      title: tr.errorTitle,
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr.confirm),
        ),
      ],
    );
  }

  /// 显示成功提示（顶部轻提示，自动消失）
  ///
  /// 原先是一个居中弹窗 + 「确定」按钮：收藏、备份这类**结果已经写在界面上**的
  /// 操作还要用户再点一次确认，纯属打断（用户反馈"弹出卡片然后消失就行了，
  /// 不需要手动确认"）。现在统一走 [showTransientToast]。
  static void showSuccess(BuildContext context, String message) {
    showTransientToast(context, message);
  }

  /// 轻提示：顶部滑入的小胶囊，约 1.6 秒后自动淡出
  ///
  /// 选顶部而不是底部：底部浮层会压住阅读器 / 学习页的工具栏按钮
  /// （用户反馈"提示挡住按钮"）；顶部只在导航栏附近，不遮挡任何操作区。
  /// 提示层挂在 root overlay 上，页面被 pop 时不会残留。
  static void showTransientToast(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!context.mounted) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TransientToast(
        message: message,
        isError: isError,
        onDismissed: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  /// 显示加载提示
  static void showLoading(BuildContext context, String message) {
    // 这里可以扩展为显示加载对话框
    debugPrint('Loading: $message');
  }

  /// 处理异常并显示真实错误（保留异常原文，必要时附带分类前缀）
  static void handleException(
    BuildContext context,
    Object e, {
    String? fallbackMessage,
  }) {
    //调用点大量出现在 await 之后，页面可能已经销毁
    if (!context.mounted) return;
    final tr = context.tr;
    // 收敛异常原文：Release 下不向用户暴露内部路径/主机名等实现细节
    // （FileSystemException 会带绝对路径、SocketException 会带主机名），
    // debug 构建保留完整原文便于排查
    var detail = _sanitizeDetail(e.toString().replaceAll('Exception: ', ''));
    if (detail.trim().isEmpty) {
      detail = fallbackMessage ?? tr.unknownError;
    }
    String message = detail;
    if (detail.contains('FileSystemException') ||
        detail.contains('PathNotFoundException')) {
      message = '${fallbackMessage ?? tr.fileOpFailed}\n$detail';
    } else if (detail.contains('SocketException') ||
        detail.contains('Network')) {
      message = '${fallbackMessage ?? tr.networkError}\n$detail';
    } else if (detail.contains('DatabaseException') ||
        detail.contains('SQLite') ||
        detail.contains('no such table')) {
      message = '${fallbackMessage ?? tr.dbError}\n$detail';
    }
    showError(context, message);
  }

  /// 异常原文脱敏（仅 Release 生效，debug 保留原文）
  static String _sanitizeDetail(String detail) {
    if (kDebugMode) return detail;
    var s = detail
        // Windows 绝对路径（C:\...）：支持带空格的路径（到引号/空白/行尾为止）
        .replaceAll(
          RegExp(r'''[A-Za-z]:[\\/][^'"<>\s]*(?:\s+[^'"<>\s]+)*'''),
          '<path>',
        )
        // UNC 路径（\\server\share\...）
        .replaceAll(
          RegExp(r'''\\\\[^'"<>\s]+(?:\\[^'"<>\s]+)+'''),
          '<path>',
        )
        // Unix/Android 目录（/data/user/0/... 等）
        .replaceAll(
          RegExp(r'''/(?:data|storage|Users|home)(?:/[^'"<>\s]+)*'''),
          '<path>',
        )
        // IP 主机（含端口）
        .replaceAll(RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?\b'), '<host>')
        // URL 主机名
        .replaceAll(RegExp(r'https?://[^/\s]+'), '<url>');
    return _safeTruncate(s, 160);
  }

  /// 按 Unicode 标量值截断，避免 substring 切在代理对上产生乱码 �
  static String _safeTruncate(String s, int maxChars) {
    if (s.length <= maxChars) return s;
    final runes = s.runes.take(maxChars).toList();
    // 如果最后一个 rune 是高代理对的一半，退一个 rune
    if (runes.isNotEmpty &&
        runes.last >= 0xD800 &&
        runes.last <= 0xDBFF &&
        runes.length > 1) {
      runes.removeLast();
    }
    return '${String.fromCharCodes(runes)}…';
  }
}

/// 顶部轻提示的实现：滑入 + 停留 + 淡出，无需用户操作
class _TransientToast extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismissed;

  const _TransientToast({
    required this.message,
    required this.onDismissed,
    this.isError = false,
  });

  @override
  State<_TransientToast> createState() => _TransientToastState();
}

class _TransientToastState extends State<_TransientToast>
    with SingleTickerProviderStateMixin {
  static const Duration _visibleDuration = Duration(milliseconds: 1600);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward());
    _timer = Timer(_visibleDuration, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.isError ? FluidTheme.error : FluidTheme.success;
    final background = isDark
        ? FluidTheme.getElevatedSurfaceColor(true)
        : const Color(0xF21A1A2E);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, child) => Opacity(
              opacity: _progress.value,
              child: Transform.translate(
                offset: Offset(0, -18 * (1 - _progress.value)),
                child: child,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
