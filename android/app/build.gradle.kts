import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

//读取正式签名配置。
//
//注意：**绝不静默回退 debug 签名**。debug keystore 是口令公开的固定密钥，
//用它签署的 release 包任何人都能签发"同签名"的伪造更新，且与已发布版本
//签名不一致会导致无法覆盖升级、应用商店拒收。
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

/// 仅本地验证用的逃生开关：-PallowDebugSigning=true
val allowDebugSigning = (findProperty("allowDebugSigning") as String?) == "true"

// 本地快速构建开关（正式发布不加这两个参数，行为与产物完全不变）：
//   -PquickAbiOnly=true  只编 arm64-v8a：Dart AOT 与 CMake 从 ×3 套降到 ×1 套，
//                        冷构建最大的一笔提速（真机都是 arm64）
//   -PfastRelease=true   跳过 lintVitalRelease 与资源收缩（资源收缩会强制 R8
//                        多跑一遍；发布前保留全量检查，日常本地验证不需要）
val quickAbiOnly = (findProperty("quickAbiOnly") as String?) == "true"
val fastRelease = (findProperty("fastRelease") as String?) == "true"

//只在真正要执行 release 任务时拦截，debug 构建不受影响
val isReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}
if (isReleaseBuild && !hasReleaseKey && !allowDebugSigning) {
    error(
        "缺少 android/key.properties，拒绝用 debug 签名生成 release 包。" +
            "请复制 key.properties.example 并填入正式签名；" +
            "仅本地验证时可临时加 -PallowDebugSigning=true。"
    )
}

android {
    namespace = "com.qingmang.qingmang_weiji"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.qingmang.qingmang_weiji"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            if (quickAbiOnly) {
                // --fast 快速通道：只编 arm64-v8a，见文件顶部开关说明
                abiFilters += listOf("arm64-v8a")
            } else {
            // 64 位 ARM 是主流机型；再带一个 32 位 ARM 覆盖老设备，
            // 以及 x86_64 供模拟器调试 —— 只留 arm64-v8a 时，
            // x86_64 模拟器与 32 位机型会因 INSTALL_FAILED_NO_MATCHING_ABIS 装不上。
            // 如果确定只发 arm64（体积优先），可以删掉后两项。
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
            }
        }
    }

    lint {
        // --fast 快速通道跳过 release 关键性 lint 全量分析（每次冷构建约 1~3 分钟）；
        // 正式发布不带该参数，lintVitalRelease 照常执行
        checkReleaseBuilds = !fastRelease
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                //缺键时给出可读的报错，而不是 as String 抛出的
                //NullPointerException / ClassCastException
                fun required(key: String): String = keystoreProperties.getProperty(key)
                    ?: error("android/key.properties 缺少字段：$key")
                keyAlias = required("keyAlias")
                keyPassword = required("keyPassword")
                storeFile = file(required("storeFile"))
                storePassword = required("storePassword")
            }
        }
    }

    buildTypes {
        release {
            //正式签名缺失时只可能是走了 -PallowDebugSigning 的本地验证分支
            //（配置阶段已拦截真正的 release 构建，见文件顶部校验）
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            // 资源收缩会强制 R8 跑两遍，--fast 时关掉（见文件顶部开关说明）；
            // 正式发布保持开启，APK 体积不受影响
            isShrinkResources = !fastRelease
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-splashscreen:1.0.1")
}

flutter {
    source = "../.."
}
