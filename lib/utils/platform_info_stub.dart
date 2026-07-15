import 'package:flutter/foundation.dart' show kIsWeb;

bool get isWindowsPlatform => false;
bool get isLinuxPlatform => false;
bool get isAndroidPlatform => false;
bool get isIOSPlatform => false;
bool get isMacOSPlatform => false;
bool get isMobilePlatform => false;
bool get isDesktopPlatform => false;
bool get isWebPlatform => kIsWeb;
