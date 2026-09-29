#include "flutter_window.h"

#include <cstdio>
#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Window that currently owns keyboard focus.
//
// Posting WM_INPUTLANGCHANGEREQUEST to the top-level window has no effect on the
// IME: the message must reach the window that actually holds focus, which is the
// Flutter child window. The runner drives everything from a single UI thread, so
// GetFocus() returns exactly that window; GetForegroundWindow() is only a
// fallback for the moments where no window has focus yet.
HWND FocusedWindowOr(HWND fallback) {
  HWND focused = GetFocus();
  if (focused == nullptr) {
    focused = GetForegroundWindow();
  }
  return focused != nullptr ? focused : fallback;
}

// The KLID of the layout that was active before the first English switch.
//
// It is captured with GetKeyboardLayoutName (the registered name string), not
// derived from the HKL handle: third-party and Microsoft IMEs (e.g. Microsoft
// Pinyin "E0010804") have KLIDs whose device part is not the HKL's high word,
// so rebuilding "0000" + langid from the handle loads the *plain keyboard*
// layout of that language instead of the user's IME - the restore then
// "succeeds" but the user is left on the wrong input method.
std::wstring CurrentLayoutName() {
  wchar_t name[KL_NAMELENGTH + 1] = {};
  if (!GetKeyboardLayoutName(name)) {
    return std::wstring();
  }
  return std::wstring(name);
}

// Fallback: rebuilds a KLID string from an HKL handle by hand. Only used when
// GetKeyboardLayoutName cannot be called on the target thread. The device part
// is taken from the handle's high word, which is correct for plain keyboard
// layouts but not for every IME (see CurrentLayoutName).
std::wstring KlidFromLayout(HKL layout) {
  const DWORD_PTR raw = reinterpret_cast<DWORD_PTR>(layout);
  const DWORD klid = MAKELONG(static_cast<WORD>(raw & 0xFFFF),
                              static_cast<WORD>((raw >> 16) & 0xFFFF));
  static constexpr wchar_t kHex[] = L"0123456789ABCDEF";
  wchar_t buffer[9] = {};
  for (int i = 0; i < 8; ++i) {
    buffer[i] = kHex[(klid >> ((7 - i) * 4)) & 0xF];
  }
  return std::wstring(buffer, 8);
}

// Best-effort switch of both the thread layout and the focused window's input
// language. Returns false when the layout could not be activated at all.
bool ApplyKeyboardLayout(HKL layout) {
  if (layout == nullptr) {
    return false;
  }
  // Plain ActivateKeyboardLayout(layout, 0) is silently ignored by several
  // IMEs; KLF_ACTIVATE makes the layout current for this thread immediately.
  if (ActivateKeyboardLayout(layout, KLF_ACTIVATE) == nullptr) {
    return false;
  }
  const HWND target = FocusedWindowOr(GetForegroundWindow());
  if (target != nullptr) {
    // WM_INPUTLANGCHANGEREQUEST is a top-level window message: DefWindowProc
    // only performs the switch when it reaches the root window, so posting it
    // to the Flutter child view is silently dropped.
    const HWND root = GetAncestor(target, GA_ROOT);
    PostMessageW(root != nullptr ? root : target, WM_INPUTLANGCHANGEREQUEST, 0,
                 reinterpret_cast<LPARAM>(layout));
  }
  return true;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  RegisterKeyboardChannel();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // Last line of defence for the input language.
  //
  // Closing the window does not run the Dart-side dispose() callbacks, so the
  // "restore the user's layout" request may never arrive and the user would be
  // left on the English layout after the app is gone. Android has the same
  // safety net in MainActivity.onDestroy().
  RestoreLayout();

  // The channel handler captures `this`, so drop it before the window goes
  // away to avoid a dangling callback.
  keyboard_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      // Both controller and engine may be null (OnCreate failed or teardown
      // race); dereferencing directly crashes when WM_FONTCHANGE arrives.
      if (flutter_controller_ && flutter_controller_->engine()) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::RegisterKeyboardChannel() {
  if (!flutter_controller_ || !flutter_controller_->engine()) {
    return;
  }
  keyboard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "qingmang_weiji/keyboard",
          &flutter::StandardMethodCodec::GetInstance());
  keyboard_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "switchToEnglish") {
          SwitchToEnglishLayout();
          result->Success();
        } else if (call.method_name() == "restore") {
          RestoreLayout();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::SwitchToEnglishLayout() {
  if (GetHandle() == nullptr) {
    return;
  }

  // Read the layout in use *before* switching: LoadKeyboardLayout with
  // KLF_ACTIVATE activates immediately, so afterwards the thread already
  // reports en-US and the original layout would be lost.
  //
  // Query the layout of the *focused window's* thread, not this thread's:
  // the runner thread rarely receives keyboard input, so its layout often sits
  // at the process default (en-US) even while the user is visibly on the
  // Chinese IME. Reading "0" here saved nothing and the restore became a no-op -
  // the exact "stuck on English after leaving spelling" symptom.
  //
  // The registered KLID name is captured via GetKeyboardLayoutName rather than
  // derived from the HKL handle: IME layouts (Microsoft Pinyin "E0010804",
  // third-party ones alike) do not round-trip through the handle's high word,
  // and loading the wrong KLID silently restores a plain keyboard instead of
  // the user's IME.
  HWND focused = GetFocus();
  if (focused == nullptr) {
    focused = GetForegroundWindow();
  }
  if (focused != nullptr) {
    focused = GetAncestor(focused, GA_ROOT);
  }
  const DWORD focus_tid = focused != nullptr
                              ? GetWindowThreadProcessId(focused, nullptr)
                              : 0;
  const HKL current = GetKeyboardLayout(focus_tid);
  std::wstring current_name = CurrentLayoutName();
  if (current_name.empty() && focus_tid != 0 && focus_tid != GetCurrentThreadId()) {
    // GetKeyboardLayoutName is per-thread; ask the target thread through its
    // loaded layout handle instead (best effort).
    current_name = KlidFromLayout(current);
  }

  // "00000409" is the locale id of the en-US keyboard layout. The spelling and
  // listening modes expect the user to type English words, but an active
  // Chinese IME swallows the keystrokes and shows candidates first, so the
  // layout is switched to English here.
  //
  // KLF_ACTIVATE loads the layout if needed and activates it right away; if the
  // layout is already loaded the same handle is returned.
  const HKL layout = LoadKeyboardLayoutW(L"00000409", KLF_ACTIVATE);
  if (layout == nullptr) {
    return;
  }

  // Remember the very first non-English layout we replaced. Later calls (one
  // per question) find the thread already on en-US and leave the saved value
  // alone. If the user switches back to Chinese mid-session and we are asked to
  // switch again, the Chinese layout becomes the new restore target, which is
  // what they would expect.
  if (previous_klid_.empty() && !current_name.empty() && current != layout) {
    previous_klid_ = current_name;
  }
  wchar_t log_line[160];
  swprintf_s(log_line, L"[keyboard] switchToEnglish: current=%s saved=%s\n",
             current_name.c_str(), previous_klid_.c_str());
  OutputDebugStringW(log_line);

  // Some IMEs do not react to LoadKeyboardLayout alone, so activate the layout
  // explicitly and post a language change request to the focused window as
  // well. This is best effort only: if it fails the user can still switch
  // manually and answering questions keeps working.
  ApplyKeyboardLayout(layout);
}

void FlutterWindow::RestoreLayout() {
  if (previous_klid_.empty()) {
    OutputDebugStringW(L"[keyboard] restore: nothing saved, skip\n");
    return;
  }
  const std::wstring klid = previous_klid_;
  previous_klid_.clear();

  // The layout can have been unloaded in the meantime (for example the user
  // removed the input language). Re-loading it by KLID brings it back so there
  // is something to activate; without this step ActivateKeyboardLayout can
  // fail silently and the user stays stuck on the English layout.
  const HKL reloaded = LoadKeyboardLayoutW(klid.c_str(), KLF_ACTIVATE);
  wchar_t log_line[160];
  swprintf_s(log_line, L"[keyboard] restore: klid=%s ok=%d\n", klid.c_str(),
             reloaded != nullptr);
  OutputDebugStringW(log_line);
  ApplyKeyboardLayout(reloaded);
}
