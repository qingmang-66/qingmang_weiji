import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/di_container.dart';
import '../services/providers/study_settings_provider.dart';
import '../services/providers/theme_provider.dart';
import '../services/tts_service.dart';
import '../utils/platform_info.dart';
import '../utils/translations.dart';
import 'fluid_dialog.dart';

/// 监听 TTS 错误事件并弹出居中提示框
class TtsErrorHandler extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const TtsErrorHandler({super.key, required this.child, this.navigatorKey});

  @override
  State<TtsErrorHandler> createState() => _TtsErrorHandlerState();
}

class _TtsErrorHandlerState extends State<TtsErrorHandler> {
  StreamSubscription<TtsErrorEvent>? _subscription;
  bool _isHandling = false;

  BuildContext? get _dialogContext =>
      widget.navigatorKey?.currentContext ?? (mounted ? context : null);

  @override
  void initState() {
    super.initState();
    final ttsService = context.read<DIContainer>().ttsService;
    _subscription = ttsService.errorStream.listen(_handleError);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handleError(TtsErrorEvent event) async {
    // 避免初始化阶段无 Navigator 时重复弹窗
    if (!mounted || _isHandling) return;
    final dialogContext = _dialogContext;
    if (dialogContext == null || widget.navigatorKey?.currentState == null) {
      return;
    }

    _isHandling = true;
    try {
      final tr = Translations(context.read<ThemeProvider>().isEnglishLocale);
      final ttsService = context.read<DIContainer>().ttsService;
      final settings = context.read<StudySettingsProvider>();

      switch (event.type) {
        case TtsErrorType.localFailed:
          // Windows 本地 TTS 会原生崩溃且永久不可用，自动切在线保证可发音
          if (isWindowsPlatform) {
            await ttsService.switchToOnline();
            await settings.setAudioSource('online');
            if (event.word.isNotEmpty) {
              await ttsService.playWordAfterSwitch(event.word);
            }
            break;
          }
          // 无英文引擎时用更明确的提示（国产 ROM 常见）
          final localMsg = ttsService.hasEnglishEngine
              ? tr.ttsLocalFailedMessage
              : tr.ttsMissingEngineMessage;
          await _showAlertDialog(
            title: tr.ttsLocalFailedTitle,
            message: localMsg,
          );
          if (!mounted) return;
          await _showConfirmDialog(
            title: tr.switchVoiceSourceTitle,
            message: tr.confirmSwitchToOnlineMessage,
            confirmText: tr.switchToOnline,
            onConfirm: () async {
              await ttsService.switchToOnline();
              await settings.setAudioSource('online');
              if (event.word.isNotEmpty) {
                await ttsService.playWordAfterSwitch(event.word);
              }
            },
          );
        case TtsErrorType.onlineFailed:
          await _showAlertDialog(
            title: tr.ttsOnlineFailedTitle,
            message: tr.ttsOnlineFailedMessage,
          );
          if (!mounted) return;
          await _showConfirmDialog(
            title: tr.switchVoiceSourceTitle,
            message: tr.confirmSwitchToLocalMessage,
            confirmText: tr.switchToLocalTts,
            onConfirm: () async {
              await ttsService.switchToLocal();
              await settings.setAudioSource('tts');
              if (event.word.isNotEmpty) {
                await ttsService.playWordAfterSwitch(event.word);
              }
            },
          );
        case TtsErrorType.bothUnavailable:
          await _showAlertDialog(
            title: tr.ttsBothUnavailableTitle,
            message: tr.ttsBothUnavailableMessage,
          );
      }
    } finally {
      _isHandling = false;
    }
  }

  Future<void> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Future<void> Function() onConfirm,
  }) {
    final dialogContext = _dialogContext;
    if (dialogContext == null) return Future.value();
    final tr = Translations(context.read<ThemeProvider>().isEnglishLocale);
    return showFluidDialog<void>(
      context: dialogContext,
      title: title,
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(tr.cancel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await onConfirm();
          },
          child: Text(confirmText),
        ),
      ],
    );
  }

  Future<void> _showAlertDialog({
    required String title,
    required String message,
  }) {
    final dialogContext = _dialogContext;
    if (dialogContext == null) return Future.value();
    final tr = Translations(context.read<ThemeProvider>().isEnglishLocale);
    return showFluidDialog<void>(
      context: dialogContext,
      title: title,
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(tr.gotIt),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
