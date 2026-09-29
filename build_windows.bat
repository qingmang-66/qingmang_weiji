@echo off
setlocal
cd /d "%~dp0"

rem ===================================================================
rem  Build Windows release EXE  (Flutter desktop)
rem  Usage:  build_windows.bat            normal build
rem          build_windows.bat --clean    flutter clean first
rem          build_windows.bat --open     open output folder on success
rem ===================================================================

set "APP_NAME=qingmang_weiji"
set "OUT_DIR=%CD%\build\windows\x64\runner\Release"
set "DO_CLEAN="
set "DO_OPEN="
if /i "%~1"=="--clean" set "DO_CLEAN=1"
if /i "%~1"=="-c"      set "DO_CLEAN=1"
if /i "%~1"=="--open"  set "DO_OPEN=1"
if /i "%~2"=="--open"  set "DO_OPEN=1"

echo ================================
echo   Build Windows EXE (Release)
echo ================================
echo.

rem ---------------- locate flutter ----------------
set "FLUTTER="
for /f "delims=" %%i in ('where flutter 2^>nul') do if not defined FLUTTER set "FLUTTER=%%i"

if not defined FLUTTER (
    for %%p in (
        "D:\Flutter\sdk\flutter\bin\flutter.bat"
        "C:\Flutter\sdk\flutter\bin\flutter.bat"
        "%LOCALAPPDATA%\flutter\bin\flutter.bat"
        "%USERPROFILE%\flutter\bin\flutter.bat"
        "%ProgramFiles%\flutter\bin\flutter.bat"
    ) do if not defined FLUTTER if exist "%%~p" set "FLUTTER=%%~p"
)

if not defined FLUTTER (
    echo [ERROR] flutter was not found.
    echo         Add the Flutter SDK "bin" folder to PATH, or edit the
    echo         fallback list inside this script.
    goto :fail
)
echo [info] flutter = %FLUTTER%
echo.

rem ---------------- optional clean ----------------
if defined DO_CLEAN (
    echo [1/3] flutter clean ...
    call "%FLUTTER%" clean
    if errorlevel 1 goto :fail_clean
    echo.
)

rem ---------------- dependencies ----------------
echo [*] flutter pub get ...
call "%FLUTTER%" pub get
if errorlevel 1 goto :fail_pubget
echo.

rem ---------------- build ----------------
echo [*] flutter build windows --release ...
call "%FLUTTER%" build windows --release
if errorlevel 1 goto :fail_build
echo.

rem ---------------- verify result ----------------
if not exist "%OUT_DIR%\%APP_NAME%.exe" (
    echo [ERROR] The build reported success but %APP_NAME%.exe was not found.
    echo         Expected at: %OUT_DIR%
    goto :fail
)

echo ================================
echo   BUILD SUCCESS
echo ================================
echo EXE: %OUT_DIR%\%APP_NAME%.exe
echo DIR: %OUT_DIR%
echo.
if defined DO_OPEN start "" "%OUT_DIR%"
echo Done.
pause
endlocal & exit /b 0

rem ================= error handlers =================

:fail_pubget
echo.
echo [ERROR] flutter pub get failed.
echo   Common causes on Windows:
echo     * plugin symlink refresh failed  -^> run this script with --clean
echo     * no symlink privilege           -^> turn ON Developer Mode
echo         Settings ^> System ^> For developers ^> Developer Mode
echo     * network / mirror problem       -^> check PUB_HOSTED_URL
goto :fail

:fail_clean
echo.
echo [ERROR] flutter clean failed.
goto :fail

:fail_build
echo.
echo [ERROR] flutter build windows failed - see the log above.
echo   Common causes:
echo     * Visual Studio 2022 missing the "Desktop development with C++" workload
echo     * stale build cache -^> re-run with --clean
goto :fail

:fail
echo.
echo ================================
echo   BUILD FAILED
echo ================================
echo.
pause
endlocal & exit /b 1
