import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

bool get isWindowsPlatform => !kIsWeb && Platform.isWindows;
bool get isLinuxPlatform => !kIsWeb && Platform.isLinux;
bool get isAndroidPlatform => !kIsWeb && Platform.isAndroid;
bool get isIOSPlatform => !kIsWeb && Platform.isIOS;
bool get isMacOSPlatform => !kIsWeb && Platform.isMacOS;
bool get isMobilePlatform => isAndroidPlatform || isIOSPlatform;
bool get isDesktopPlatform =>
    isWindowsPlatform || isLinuxPlatform || isMacOSPlatform;
bool get isWebPlatform => kIsWeb;
