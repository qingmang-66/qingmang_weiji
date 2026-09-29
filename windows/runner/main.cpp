#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

static bool CheckSingleInstance() {
  // "Local\" prefix scopes the mutex to the current logon session: relaunches
  // by the same user are blocked; other users' sessions stay independent.
  // Clear LastError first so a stale code cannot fake ERROR_ALREADY_EXISTS.
  ::SetLastError(ERROR_SUCCESS);
  HANDLE mutex =
      CreateMutexW(nullptr, TRUE, L"Local\\QingmangWeijiSingletonMutex");
  if (mutex == nullptr) {
    // Extremely rare (handle exhaustion): allow startup rather than silently
    // failing; SQLite has its own file locking if two instances ever coexist.
    ::OutputDebugStringW(L"[QingmangWeiji] CreateMutex failed; skipping single-instance check\n");
    return true;
  }
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    CloseHandle(mutex);
    // Already running: bring the existing window to front instead of quitting
    // silently (otherwise a double-click looks like "nothing happened").
    HWND existing = ::FindWindowW(nullptr, L"\u6e05\u832b\u5fae\u8bb0");
    if (existing != nullptr) {
      if (::IsIconic(existing)) {
        ::ShowWindow(existing, SW_RESTORE);
      }
      ::SetForegroundWindow(existing);
    } else {
      ::MessageBoxW(nullptr,
                    L"\u6e05\u832b\u5fae\u8bb0\u5df2\u5728\u8fd0\u884c\u3002",
                    L"\u6e05\u832b\u5fae\u8bb0",
                    MB_OK | MB_ICONINFORMATION);
    }
    return false;
  }
  return true;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  if (!CheckSingleInstance()) {
    return EXIT_FAILURE;
  }

  // COM init result is logged, not fatal: most plugins do not depend on COM,
  // so the app should still run when initialization fails.
  HRESULT com_hr = ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(com_hr)) {
    ::OutputDebugStringW(L"[QingmangWeiji] CoInitializeEx failed\n");
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  const int defW = 1280, defH = 720;

  // Center on the monitor under the cursor, in DPI-aware fashion:
  // Win32Window::Create scales the DIP origin by the target monitor's DPI, so
  // the same monitor must be used here or the window drifts when 100%/200%
  // screens are mixed.
  POINT cursor_pt = {0, 0};
  if (!::GetCursorPos(&cursor_pt)) {
    cursor_pt = {0, 0};
  }
  HMONITOR monitor = ::MonitorFromPoint(cursor_pt, MONITOR_DEFAULTTOPRIMARY);

  UINT monitor_dpi = FlutterDesktopGetDpiForMonitor(monitor);
  if (monitor_dpi == 0) monitor_dpi = 96;
  const double scale = monitor_dpi / 96.0;

  int workW = defW, workH = defH;
  MONITORINFO monitor_info = {sizeof(MONITORINFO)};
  if (::GetMonitorInfo(monitor, &monitor_info)) {
    workW = static_cast<int>(
        (monitor_info.rcWork.right - monitor_info.rcWork.left) / scale);
    workH = static_cast<int>(
        (monitor_info.rcWork.bottom - monitor_info.rcWork.top) / scale);
  }

  int originX = (workW - defW) / 2;
  int originY = (workH - defH) / 2;
  if (originX < 0) originX = 0;
  if (originY < 0) originY = 0;

  Win32Window::Point origin(originX, originY);
  Win32Window::Size size(defW, defH);
  if (!window.Create(L"\u6e05\u832b\u5fae\u8bb0", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
