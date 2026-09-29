#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Registers the "qingmang_weiji/keyboard" channel, which switches the
  // keyboard layout to English while the user types answers in the spelling
  // and listening exercise modes.
  void RegisterKeyboardChannel();

  // Switches this thread's keyboard layout to en-US and asks the window to
  // adopt the same input language. The layout in use before the first switch is
  // remembered so it can be restored later.
  void SwitchToEnglishLayout();

  // Restores the keyboard layout captured by SwitchToEnglishLayout, so text
  // fields outside the spelling/listening exercises keep using the user's own
  // input language. No-op when nothing was captured. Also called from
  // OnDestroy() as a safety net: closing the window skips the Dart-side
  // dispose() callbacks, so the restore request may never arrive.
  void RestoreLayout();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Keyboard layout channel; its lifetime follows the window.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      keyboard_channel_;

  // KLID (registry layout name, e.g. L"00000804" / L"E0010804") of the layout
  // that was active before the English switch; empty when not switched.
  std::wstring previous_klid_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
