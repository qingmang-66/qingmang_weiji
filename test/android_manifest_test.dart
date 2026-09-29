import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('AndroidManifest', () {
    test('声明 TTS 服务查询能力，允许 Android 11+ 发现本地语音引擎', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android.intent.action.TTS_SERVICE'));
    });

    test('声明通知与开机相关权限', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    });

    test('启用了 enableOnBackInvokedCallback（Android 14+ 预测性返回手势）', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:enableOnBackInvokedCallback="true"'));
    });

    test('未声明 roundIcon（minSdk 24 上会解析不到资源）', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      // ic_launcher_round 只存在于 mipmap-anydpi-v26，而 minSdk = 24：
      // Android 7.0/7.1 上该资源没有匹配配置会抛 NotFoundException。
      // 不声明 roundIcon 时系统回退到 android:icon，圆形图标桌面同样正常。
      expect(manifest, isNot(contains('android:roundIcon')));
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    });

    test('声明了 supportsRtl', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:supportsRtl="true"'));
    });

    test('声明了 largeHeap', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:largeHeap="true"'));
    });

    test('声明了 networkSecurityConfig', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:networkSecurityConfig'));
    });

    test('声明了 backup 配置', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:fullBackupContent'));
      expect(manifest, contains('android:dataExtractionRules'));
    });
  });

  group('Adaptive Icon', () {
    test('存在 mipmap-anydpi-v26/ic_launcher.xml', () {
      expect(
        File(
          'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
        ).existsSync(),
        isTrue,
      );
    });

    test('存在 mipmap-anydpi-v26/ic_launcher_round.xml', () {
      expect(
        File(
          'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml',
        ).existsSync(),
        isTrue,
      );
    });

    test('存在 foreground 背景 drawable', () {
      expect(
        File(
          'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          'android/app/src/main/res/drawable/ic_launcher_background.xml',
        ).existsSync(),
        isTrue,
      );
    });
  });

  group('网络安全备份配置', () {
    test('存在 network_security_config.xml', () {
      expect(
        File(
          'android/app/src/main/res/xml/network_security_config.xml',
        ).existsSync(),
        isTrue,
      );
    });

    test('存在 backup_rules.xml', () {
      expect(
        File('android/app/src/main/res/xml/backup_rules.xml').existsSync(),
        isTrue,
      );
    });

    test('存在 data_extraction_rules.xml', () {
      expect(
        File(
          'android/app/src/main/res/xml/data_extraction_rules.xml',
        ).existsSync(),
        isTrue,
      );
    });
  });

  group('Android release 签名配置', () {
    test('build.gradle.kts 支持 key.properties 正式签名', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('key.properties'));
      expect(gradle, contains('signingConfigs'));
      expect(gradle, contains('create("release")'));
    });

    test('release 开启 minify 与 abi 裁剪', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('isMinifyEnabled = true'));
      //资源压缩受 fastRelease 开关控制（构建优化：本地快构建跳过 shrink），
      //硬编码断言 '= true' 已不符合真实契约
      expect(gradle, contains('isShrinkResources = !fastRelease'));
      expect(gradle, contains('arm64-v8a'));
      expect(gradle, contains('proguard-rules.pro'));
    });

    test('添加了 SplashScreen 依赖', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('core-splashscreen'));
    });
  });

  group('Gradle 属性', () {
    test('启用了 R8 fullMode', () {
      final props = File('android/gradle.properties').readAsStringSync();
      expect(props, contains('android.enableR8.fullMode=true'));
    });

    test('启用了 kotlin.incremental', () {
      final props = File('android/gradle.properties').readAsStringSync();
      expect(props, contains('kotlin.incremental=true'));
    });
  });

  group('Edge-to-edge', () {
    test('MainActivity 启用 WindowCompat edge-to-edge', () {
      final main = File(
        'android/app/src/main/kotlin/com/qingmang/qingmang_weiji/MainActivity.kt',
      ).readAsStringSync();
      expect(main, contains('setDecorFitsSystemWindows'));
      expect(main, contains('WindowCompat'));
    });

    test('MainActivity 启用 SplashScreen API', () {
      final main = File(
        'android/app/src/main/kotlin/com/qingmang/qingmang_weiji/MainActivity.kt',
      ).readAsStringSync();
      expect(main, contains('installSplashScreen'));
      expect(main, contains('androidx.core.splashscreen'));
    });
  });

  group('Styles.xml 集成 SplashScreen', () {
    test('values/styles.xml 使用 Theme.SplashScreen', () {
      final s = File(
        'android/app/src/main/res/values/styles.xml',
      ).readAsStringSync();
      expect(s, contains('Theme.SplashScreen'));
      expect(s, contains('windowSplashScreenBackground'));
      expect(s, contains('windowSplashScreenAnimatedIcon'));
      expect(s, contains('postSplashScreenTheme'));
    });

    test('values-night/styles.xml 使用 Theme.SplashScreen', () {
      final s = File(
        'android/app/src/main/res/values-night/styles.xml',
      ).readAsStringSync();
      expect(s, contains('Theme.SplashScreen'));
      expect(s, contains('windowSplashScreenBackground'));
      expect(s, contains('windowSplashScreenAnimatedIcon'));
      expect(s, contains('postSplashScreenTheme'));
    });
  });

  group('Windows 端优化', () {
    test('窗口标题使用中文', () {
      final main = File('windows/runner/main.cpp').readAsStringSync();
      // 使用 unicode escape 避免 MSVC C4819
      expect(main, contains(r'\u6e05\u832b\u5fae\u8bb0'));
    });

    test('窗口居中显示（基于目标显示器 DPI）', () {
      final main = File('windows/runner/main.cpp').readAsStringSync();
      // 用鼠标所在显示器的工作区与 DPI 计算，避免多屏/高 DPI 下偏移
      expect(main, contains('MonitorFromPoint'));
      expect(main, contains('FlutterDesktopGetDpiForMonitor'));
      expect(main, contains('GetMonitorInfo'));
    });

    test('单实例检查', () {
      final main = File('windows/runner/main.cpp').readAsStringSync();
      expect(main, contains('CheckSingleInstance'));
      expect(main, contains('CreateMutexW'));
    });

    test('最小窗口尺寸限制', () {
      final cpp = File('windows/runner/win32_window.cpp').readAsStringSync();
      expect(cpp, contains('WM_GETMINMAXINFO'));
      expect(cpp, contains('ptMinTrackSize'));
    });

    test('Mica 背景效果', () {
      final cpp = File('windows/runner/win32_window.cpp').readAsStringSync();
      expect(cpp, contains('DWMWA_SYSTEMBACKDROP_TYPE'));
      expect(cpp, contains('DWMSBT_MAINWINDOW'));
    });

    test('Runner.rc 产品名为清茫微记', () {
      final rc = File('windows/runner/Runner.rc').readAsStringSync();
      expect(rc, contains('"ProductName", "清茫微记"'));
    });
  });

  group('版本号', () {
    // 不再硬编码具体版本号（升版时测试会连带红一片，历史多次踩坑）：
    // 这里只钉住"pubspec 与 constants 两处版本必须一致"的真实契约
    test('pubspec.yaml 与 constants.dart 版本号一致', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final constants = File('lib/utils/constants.dart').readAsStringSync();
      final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
          .firstMatch(pubspec);
      expect(match, isNotNull, reason: 'pubspec.yaml 找不到 version 字段');
      final version = match!.group(1)!;
      expect(version, matches(RegExp(r'^\d+\.\d+\.\d+$')));
      expect(
        constants,
        contains("appVersion = '$version'"),
        reason: 'constants.dart 的 appVersion 与 pubspec 不一致（$version）',
      );
    });
  });

  group('导航位置用户偏好', () {
    test('ThemeProvider 包含 navPosition 字段', () {
      final tp = File(
        'lib/services/providers/theme_provider.dart',
      ).readAsStringSync();
      expect(tp, contains('NavPosition'));
      expect(tp, contains('navPosition'));
      expect(tp, contains('setNavPosition'));
    });

    test('HomeScreen 使用用户偏好而非窗口宽度', () {
      final home = File('lib/screens/home_screen.dart').readAsStringSync();
      expect(home, contains('navPosition'));
      // 侧栏支持左侧与右侧（右侧仅 Windows 提供该选项）
      expect(home, contains('NavPosition.bottom'));
      expect(home, contains('NavPosition.right'));
      // 不再依赖 LayoutBuilder 宽度判断
      expect(home, isNot(contains('constraints.maxWidth >= 900')));
    });

    test('设置页面包含导航位置选项（仅桌面/Web）', () {
      //扁平化重构后导航位置选项内联在设置一级页，不再是二级分组
      final ss = File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(ss, contains('PlatformAdapt.isDesktop'));
      expect(ss, contains('kIsWeb'));
      expect(ss, contains('NavPosition'));
      // 右侧导航仅在 Windows 桌面端出现
      expect(ss, contains('PlatformAdapt.isWindows'));
      expect(ss, contains('NavPosition.right'));
    });

    test('翻译字符串包含导航位置相关文案', () {
      final tr = File('lib/utils/translations.dart').readAsStringSync();
      expect(tr, contains('navPosition'));
      expect(tr, contains('navBottom'));
      expect(tr, contains('navLeft'));
      expect(tr, contains('navRight'));
    });
  });
}
