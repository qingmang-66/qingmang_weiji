import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_io.dart'
    as impl;

bool get isWindowsPlatform => impl.isWindowsPlatform;
bool get isLinuxPlatform => impl.isLinuxPlatform;
bool get isAndroidPlatform => impl.isAndroidPlatform;
bool get isIOSPlatform => impl.isIOSPlatform;
bool get isMacOSPlatform => impl.isMacOSPlatform;
bool get isMobilePlatform => impl.isMobilePlatform;
bool get isDesktopPlatform => impl.isDesktopPlatform;
bool get isWebPlatform => impl.isWebPlatform;
