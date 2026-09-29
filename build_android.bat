@echo off
rem Switch to UTF-8 so the Chinese APK file name below is parsed correctly.
chcp 65001 >nul
setlocal
cd /d "%~dp0"

rem ===================================================================
rem  Build Android release APK
rem  Usage:  build_android.bat              normal build
rem          build_android.bat --clean      flutter clean first
rem          build_android.bat --check      fast config check only (~2 min,
rem                                         Gradle --dry-run, no download/compile)
rem          build_android.bat --require-sign
rem                                         (kept for compatibility; strict
rem                                         signing is now the default)
rem          build_android.bat --allow-debug-sign
rem                                         explicitly allow signing with the
rem                                         DEBUG key when no real key exists
rem          build_android.bat --no-install
rem                                         build only, do not touch the phone
rem          build_android.bat --no-open
rem                                         do not open the output folder
rem                                         (handy when scripting)
rem          build_android.bat --fast      FAST local build: only arm64-v8a,
rem                                         skip lintVitalRelease and resource
rem                                         shrinking (R8 runs once).
rem                                         NEVER publish a --fast APK - it is
rem                                         missing 32-bit/x86 ABIs and is not
rem                                         size-optimised. Full release build
rem                                         = run without --fast as usual.
rem
rem  Just double-click the script: it builds the APK, and if a phone is attached
rem  with USB debugging on it installs the APK onto it; otherwise it opens the
rem  output folder so you can copy the file over.
rem
rem  Signing: uses android\key.properties when it exists. Without it the build
rem  is REFUSED by default - pass --allow-debug-sign to sign with the DEBUG key
rem  anyway (fine for installing on your own device, same key as earlier local
rem  builds so it installs over them and keeps your data - never publish it).
rem  The debug keystore password is public: a debug-signed APK can be faked by
rem  anyone, which is why it must never be the silent default.
rem ===================================================================

set "APK_OUT=%CD%\build\app\outputs\flutter-apk"
set "DO_CLEAN="
set "DO_CHECK="
set "REQUIRE_SIGN="
set "ALLOW_DEBUG_SIGN="
set "NO_INSTALL="
set "NO_OPEN="
set "DO_FAST="
rem Parse every argument, not just the first: "--check --clean" must work.
rem (Only `set` happens inside the loop, so no delayed expansion is needed.)
for %%a in (%*) do (
    if /i "%%a"=="--clean"            set "DO_CLEAN=1"
    if /i "%%a"=="-c"                 set "DO_CLEAN=1"
    if /i "%%a"=="--check"            set "DO_CHECK=1"
    if /i "%%a"=="-k"                 set "DO_CHECK=1"
    if /i "%%a"=="--require-sign"     set "REQUIRE_SIGN=1"
    if /i "%%a"=="--signed"           set "REQUIRE_SIGN=1"
    if /i "%%a"=="--allow-debug-sign" set "ALLOW_DEBUG_SIGN=1"
    if /i "%%a"=="-d"                 set "ALLOW_DEBUG_SIGN=1"
    if /i "%%a"=="--no-install"       set "NO_INSTALL=1"
    if /i "%%a"=="--no-open"          set "NO_OPEN=1"
    if /i "%%a"=="--fast"             set "DO_FAST=1"
    if /i "%%a"=="-f"                 set "DO_FAST=1"
)

echo ================================
echo   Build Android APK (Release)
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

rem ---------------- preflight: android sdk path ----------------
rem AGP reads sdk.dir from android\local.properties first, then ANDROID_HOME.
set "SDK_DIR="
if not exist "android\local.properties" goto :sdk_fallback
for /f "usebackq tokens=1,* delims==" %%a in ("android\local.properties") do if /i "%%a"=="sdk.dir" set "SDK_DIR=%%b"

:sdk_fallback
if not defined SDK_DIR if defined ANDROID_HOME     set "SDK_DIR=%ANDROID_HOME%"
if not defined SDK_DIR if defined ANDROID_SDK_ROOT set "SDK_DIR=%ANDROID_SDK_ROOT%"

if not defined SDK_DIR goto :sdk_unknown
echo [info] sdk     = %SDK_DIR%
if exist "%SDK_DIR%\platforms" goto :java_check
echo [WARN] "%SDK_DIR%" has no "platforms" folder - the SDK path is wrong or the
echo        SDK is incomplete, so the build will almost certainly fail.
echo        Fix:  flutter config --android-sdk "D:\path\to\android-sdk"
echo.
goto :java_check

:sdk_unknown
echo [WARN] Android SDK path not found in android\local.properties, nor in
echo        ANDROID_HOME / ANDROID_SDK_ROOT.
echo        Fix:  flutter config --android-sdk "D:\path\to\android-sdk"
echo.

rem ---------------- preflight: jdk version ----------------
rem AGP 8.x needs Java 17+. flutter picks the JDK as:
rem   1) "flutter config --jdk-dir"   2) JAVA_HOME env var
rem Only JAVA_HOME is checked here, and only when jdk-dir is not configured.
:java_check
set "JDK_CFG="
if not exist "%APPDATA%\.flutter_settings" goto :jdk_cfg_done
findstr /i /c:"jdk-dir" "%APPDATA%\.flutter_settings" >nul 2>&1
if not errorlevel 1 set "JDK_CFG=1"
:jdk_cfg_done

if not defined JDK_CFG goto :jdk_use_java_home
echo [info] jdk     = set via "flutter config --jdk-dir" ^(JAVA_HOME is ignored^)
echo.
goto :preflight_done

:jdk_use_java_home
if not defined JAVA_HOME goto :jdk_no_home
if not exist "%JAVA_HOME%\release" goto :preflight_done

set "JAVA_VER="
for /f "usebackq tokens=1,* delims==" %%a in ("%JAVA_HOME%\release") do if /i "%%a"=="JAVA_VERSION" set "JAVA_VER=%%~b"
if not defined JAVA_VER goto :preflight_done

set "JAVA_MAJOR=0"
for /f "tokens=1,2 delims=." %%a in ("%JAVA_VER%") do if "%%a"=="1" (set "JAVA_MAJOR=%%b") else (set "JAVA_MAJOR=%%a")
echo [info] jdk     = %JAVA_HOME%  ^(Java %JAVA_VER%^)
if %JAVA_MAJOR% LSS 17 (
    echo [WARN] Java %JAVA_MAJOR% is too old: the Android Gradle Plugin needs Java 17+.
    echo        Fix:  flutter config --jdk-dir="D:\path\to\jdk-17"
)
echo.
goto :preflight_done

:jdk_no_home
echo [info] jdk     = JAVA_HOME is not set, flutter will search for one itself.
echo.

:preflight_done
rem ---------------- release signing ----------------
rem android\app\build.gradle.kts guards release builds: without
rem android\key.properties a release APK is refused outright. This script is the
rem everyday entry point and the default here is STRICT as well - with no real
rem key the build stops with instructions. Pass --allow-debug-sign explicitly to
rem sign with the debug key anyway (same key as earlier local builds, so it
rem installs over them and keeps study data) - never publish or share it.
set "SIGN_ARGS="
set "DEBUG_SIGNED="
if defined ALLOW_DEBUG_SIGN set "SIGN_ARGS=-PallowDebugSigning=true"
rem Fast local build flags, consumed by android\app\build.gradle.kts (see there).
set "FAST_ARGS="
if defined DO_FAST set "FAST_ARGS=-PquickAbiOnly=true -PfastRelease=true"

if exist "android\key.properties" goto :key_ok

if not defined ALLOW_DEBUG_SIGN (
    echo [ERROR] android\key.properties is missing - release build refused.
    echo.
    echo   Create your signing key and fill in the template. Back up the .jks file
    echo   AND its passwords: without them you can never publish an update that
    echo   installs over the current version.
    echo.
    echo      keytool -genkeypair -v -keystore android\qingmang-release.jks -alias qingmang -keyalg RSA -keysize 2048 -validity 10000
    echo      copy android\key.properties.example android\key.properties
    echo.
    echo   For a local-only build signed with the DEBUG key, re-run with:
    echo      build_android.bat --allow-debug-sign
    echo.
    goto :fail
)

set "DEBUG_SIGNED=1"
echo [WARN] --allow-debug-sign: android\key.properties not found - signing with
echo        the DEBUG key. Fine for installing on your own device; do NOT
echo        publish or share it (the debug keystore password is public).
echo.
goto :key_ok

:key_ok

rem ---------------- fast config check mode (--check) ----------------
rem Gradle's --dry-run runs the configure phase only - exactly where
rem "plugin project failed to configure" problems surface. Takes ~2 min,
rem downloads nothing and compiles nothing.
if not defined DO_CHECK goto :do_build

if not exist ".dart_tool\package_config.json" goto :check_need_build
if not exist "android\gradlew.bat" goto :check_need_build

rem --check invokes gradlew directly, and Gradle only honours JAVA_HOME
rem (flutter's "jdk-dir" config only applies when flutter launches Gradle).
rem So JAVA_HOME must be checked separately here, otherwise --check would
rem report a misleading failure.
set "CK_JAVA_VER="
set "CK_JAVA_MAJOR=0"
if defined JAVA_HOME if exist "%JAVA_HOME%\release" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%JAVA_HOME%\release") do if /i "%%a"=="JAVA_VERSION" set "CK_JAVA_VER=%%~b"
)
if defined CK_JAVA_VER for /f "tokens=1,2 delims=." %%a in ("%CK_JAVA_VER%") do if "%%a"=="1" (set "CK_JAVA_MAJOR=%%b") else (set "CK_JAVA_MAJOR=%%a")
if %CK_JAVA_MAJOR% LSS 17 (
    echo [ERROR] --check calls gradlew directly, and Gradle only honours JAVA_HOME.
    echo         ^(flutter's "jdk-dir" config only applies when flutter launches Gradle.^)
    echo         Current JAVA_HOME is Java %CK_JAVA_VER%  "%JAVA_HOME%"
    echo         Do this first:  set "JAVA_HOME=D:\path\to\jdk-17"
    echo         Or just run the full build:  build_android.bat
    goto :fail
)

echo [*] gradle :app:assembleRelease --dry-run  ^(configure only, no compile^) ...
pushd android
call "gradlew.bat" :app:assembleRelease --dry-run --console=plain %SIGN_ARGS%
set "CHECK_RC=%errorlevel%"
popd
echo.
if not "%CHECK_RC%"=="0" goto :fail_check

echo ================================
echo   CONFIG CHECK OK
echo ================================
echo Configure phase passed. Now run the full build:  build_android.bat
echo.
pause
endlocal & exit /b 0

:check_need_build
echo [ERROR] Flutter has not generated the Android project files yet.
echo         Run a normal build first:  build_android.bat
goto :fail

:fail_check
echo.
echo [ERROR] Configure phase failed - see the error above.
echo   If it says "does not specify compileSdk" together with
echo   "java.util.concurrent.TimeoutException" or "GenerateProjectAccessors":
echo     Gradle's Kotlin DSL timed out while generating the type-safe project
echo     accessors, so the plugins' "compileSdk = flutter.compileSdkVersion"
echo     line never took effect. Things to try, in order:
echo       1) turn off your antivirus / security suite real-time file scanning
echo       2) move the project to a shorter path, no non-ASCII chars, not on C:
echo       3) android\gradlew.bat --stop   to drop the stale daemon, then retry
goto :fail

:do_build
rem ---------------- optional clean ----------------
if defined DO_CLEAN (
    echo [*] flutter clean ...
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
rem %SIGN_ARGS% tells Gradle to accept the debug key when no real key exists
rem (see android/app/build.gradle.kts); it is empty when --require-sign was
rem given, or harmless when android\key.properties is present.
rem %FAST_ARGS% is the --fast quick path, empty for normal/release builds.
echo [*] flutter build apk --release %SIGN_ARGS% %FAST_ARGS% ...
call "%FLUTTER%" build apk --release %SIGN_ARGS% %FAST_ARGS%
if errorlevel 1 goto :fail_build
echo.

rem ---------------- verify result ----------------
if not exist "%APK_OUT%\app-release.apk" (
    echo [ERROR] The build reported success but app-release.apk was not found.
    echo         Expected at: %APK_OUT%
    goto :fail
)

echo ================================
echo   BUILD SUCCESS
echo ================================
if defined DO_FAST echo NOTE: --fast build (arm64-v8a only, no lint/resource shrinking) - install locally, do not publish.
rem The APK is renamed to 清茫微记.apk at the very end of the script (see
rem :finalize_apk), so it is reported there - together with the folder path.
if defined DEBUG_SIGNED echo NOTE: debug-signed (no key.properties) - install only, do not distribute.
echo.

rem ---------------- install to the phone (or open the folder) ----------------
rem With a phone attached and USB debugging on, install the APK onto it right
rem away; otherwise open the output folder so the file can be copied over.
rem --no-install skips this whole step.
rem IMPORTANT for this file: never end a line with a non-ASCII character.
rem cmd.exe in the UTF-8 code page (chcp 65001, set at the top) swallows the
rem line break after a multi-byte char and then runs the next line as a
rem command - that is how a harmless Chinese comment once turned into
rem "'<mojibake>' is not recognized as an internal or external command".
if defined NO_INSTALL goto :skip_install
call :install_to_device

:skip_install
rem Rename the APK before opening the folder, so Explorer shows the final name.
rem adb has already finished above, and it used the plain ASCII app-release.apk.
call :finalize_apk
if defined INSTALLED goto :build_all_done

:show_dir
if defined NO_OPEN goto :build_all_done
start "" explorer "%APK_OUT%"

:build_all_done
echo.
echo Done.
pause
endlocal & exit /b 0

rem ================= optional step: install onto a connected phone =================
rem Subroutine: sets INSTALLED=1 when the APK was pushed to the phone; any other
rem outcome falls back quietly to the manual-install hint.
rem adb is taken from the project SDK's platform-tools first, then from PATH.
:install_to_device
set "ADB="
if defined SDK_DIR if exist "%SDK_DIR%\platform-tools\adb.exe" set "ADB=%SDK_DIR%\platform-tools\adb.exe"
if not defined ADB for /f "delims=" %%i in ('where adb 2^>nul') do if not defined ADB set "ADB=%%i"
if not defined ADB (
    echo [info] adb not found - skipping auto install, opening the folder instead.
    goto :eof
)

"%ADB%" start-server >nul 2>&1
rem Device list goes through a temp file: an adb path containing spaces cannot
rem be quoted reliably inside a for /f command.
set "QM_ADB_LIST=%TEMP%\qm_adb_devices.txt"
"%ADB%" devices > "%QM_ADB_LIST%" 2>nul
set "DEVCOUNT=0"
set "DEVNAME="
for /f "skip=1 tokens=1,2" %%a in ("%QM_ADB_LIST%") do (
    if "%%b"=="device" set /a DEVCOUNT+=1
    if "%%b"=="device" set "DEVNAME=%%a"
)

if %DEVCOUNT%==0 (
    echo [info] no phone detected - opening the folder so you can copy the APK.
    goto :eof
)
if %DEVCOUNT% GTR 1 (
    echo [WARN] %DEVCOUNT% devices connected - skipping auto install. Install manually:
    rem Leave the friendly name here, not app-release.apk: this hint is meant to be
    rem copy-pasted after the script has finished, and by then the file is renamed.
    echo          "%ADB%" install -r "%APK_OUT%\清茫微记.apk"
    goto :eof
)

echo [*] installing to the connected device %DEVNAME% ...
set "QM_INSTALL_LOG=%TEMP%\qm_adb_install.txt"
rem Install from the Gradle name: the rename to 清茫微记.apk happens afterwards on
rem purpose, so adb never has to deal with a non-ASCII path.
"%ADB%" install -r "%APK_OUT%\app-release.apk" > "%QM_INSTALL_LOG%" 2>&1
findstr /i /c:"Success" "%QM_INSTALL_LOG%" >nul 2>&1
if errorlevel 1 goto :install_failed

echo     Installed. You can open 清茫微记 on your phone now.
set "INSTALLED=1"
goto :eof

:install_failed
echo [WARN] adb install did not succeed. adb said:
type "%QM_INSTALL_LOG%"
findstr /i /c:"UPDATE_INCOMPATIBLE" /c:"SIGNATURE" "%QM_INSTALL_LOG%" >nul 2>&1
if not errorlevel 1 (
    echo        The app already on the phone was signed with a different key.
    echo        Uninstall it first ^(export a backup inside the app first if you
    echo        want to keep your study data^), then run this script again.
)
goto :eof

rem ================= optional step: rename the APK for sharing =================
rem Gradle only ever emits app-release.apk. Rename it (do NOT copy) to
rem 清茫微记.apk so the output folder ends up with a single, shareable file:
rem the old "copy" behaviour left app-release.apk and 清茫微记.apk next to each
rem other, which looked like two separate builds of the same app.
rem This runs AFTER the install step on purpose - adb then only ever handles a
rem plain ASCII path, so no adb version can trip over the Chinese file name.
:finalize_apk
set "APK_FRIENDLY=%APK_OUT%\清茫微记.apk"
set "APK_FINAL=%APK_FRIENDLY%"
if not exist "%APK_OUT%\app-release.apk" goto :finalize_report

move /y "%APK_OUT%\app-release.apk" "%APK_FRIENDLY%" >nul 2>&1
if not errorlevel 1 goto :finalize_sha1

rem Rename refused (file still open elsewhere, antivirus scanning it...):
rem fall back to "copy, then delete the original" - same single-file result.
copy /y "%APK_OUT%\app-release.apk" "%APK_FRIENDLY%" >nul 2>&1
if errorlevel 1 (
    echo [WARN] could not create 清茫微记.apk ^(keeping app-release.apk^).
    set "APK_FINAL=%APK_OUT%\app-release.apk"
    goto :finalize_report
)
del /f /q "%APK_OUT%\app-release.apk" >nul 2>&1

:finalize_sha1
rem Gradle writes app-release.apk.sha1 next to the APK. Rename it along with the
rem APK so nothing is left pointing at a file name that no longer exists.
if not exist "%APK_OUT%\app-release.apk.sha1" goto :finalize_report
move /y "%APK_OUT%\app-release.apk.sha1" "%APK_OUT%\清茫微记.apk.sha1" >nul 2>&1
if errorlevel 1 del /f /q "%APK_OUT%\app-release.apk.sha1" >nul 2>&1

:finalize_report
echo APK: %APK_FINAL%
echo DIR: %APK_OUT%
goto :eof

rem ================= error handlers =================

:fail_pubget
echo.
echo [ERROR] flutter pub get failed.
echo   Common causes:
echo     * network / mirror problem -^> check PUB_HOSTED_URL
echo     * stale cache              -^> run this script with --clean
goto :fail

:fail_clean
echo.
echo [ERROR] flutter clean failed.
goto :fail

:fail_build
echo.
echo [ERROR] flutter build apk failed - see the log above.
echo   Common causes:
echo     * "does not specify compileSdk" + "TimeoutException"
echo         Gradle Kotlin DSL timed out generating project accessors, so the
echo         plugins' compileSdk line never took effect (antivirus real-time
echo         scanning or slow disk IO is the usual cause).
echo         Reproduce fast with:  build_android.bat --check
echo         Then disable real-time scanning and retry; if needed run
echo         android\gradlew.bat --stop to drop the stale daemon.
echo     * Android SDK platform missing for the required compileSdk
echo         check :  sdkmanager --list_installed
echo         install:  sdkmanager "platforms;android-36"
echo     * wrong SDK path    -^> flutter config --android-sdk "D:\path\to\android-sdk"
echo     * Java too old      -^> flutter config --jdk-dir="D:\path\to\jdk-17"
echo     * NDK missing       -^> sdkmanager "ndk;28.2.13676358"
echo     * stale build cache -^> re-run this script with --clean
goto :fail

:fail
echo.
echo ================================
echo   BUILD FAILED
echo ================================
echo.
pause
endlocal & exit /b 1
