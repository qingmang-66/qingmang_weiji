# 清茫微记 (QingMang WeiJi)

基于艾宾浩斯遗忘曲线的英语单词记忆软件，支持 Windows / Android / iOS / Web 四端。

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Android%20%7C%20iOS%20%7C%20Web-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.0+-cyan)
![License](https://img.shields.io/badge/license-Apache--2.0-green)

## ✨ 特性

- 🧠 **SM-2 + S-MARS 复习算法** - SM-2 间隔调度叠加会话掌握度引擎（Session Mastery），按回忆质量动态微调复习时机
- 📖 **词书阅读模式** - 像翻小说一样背单词，支持书签、目录检索、排版自定义与仿真翻页动画
- 📚 **7 本内置词书** - 初中、高中、CET-4/6、考研、托福、SAT（ECDICT 数据源，含音标/释义/短语/例句）
- 🔊 **TTS 发音 + 在线词典** - 单词发音和在线释义查询
- 📊 **学习统计看板** - 日/周/月/年趋势图、逐日明细、掌握度分布
- 📝 **错词本与收藏夹** - 自动收集错词并记录连续答对次数，单词级收藏跨词库统一管理
- 🔐 **加密备份** - 口令导出，PBKDF2-HMAC-SHA256 + AES-256-GCM
- 🌙 **暗黑模式** + **流体渐变 / 液态玻璃** 双界面风格
- 📱 **跨平台** - Windows 桌面端、Android、iOS 与 GitHub Pages Web 版

## 🎯 核心功能

### 智能复习系统
- 5 级质量评估（忘记 → 模糊 → 困难 → 良好 → 简单）
- 自动计算下次复习时间
- 记忆阶段描述和保持率估算

### 词库管理
- 内置 CET-4 核心词汇（5000 词）
- 支持自定义词库导入
- 词库版本管理

### 学习体验
- 滑动操作（左滑困难，右滑容易）
- 发音播放（TTS + 在线音频缓存）
- 词典查询弹窗
- 每日学习进度跟踪

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.0
- Dart SDK >= 2.17
- Windows 10+

### 安装依赖

```bash
cd qingmang_weiji
flutter pub get
```

### 运行应用

```bash
# 开发模式
flutter run

# 发布版本
flutter build windows --release
```

### 构建 Windows 应用

```bash
flutter build windows --release
```

构建完成后，exe 文件位于 `build/windows/x64/runner/Release/qingmang_weiji.exe`
（整个 `Release\` 目录是一个可独立分发的绿色包，拷走即可运行）。

也可以直接双击仓库根目录下的构建脚本：

| 脚本 | 作用 |
|------|------|
| `build_windows.bat` | 构建 Windows Release exe，支持 `--clean` / `--open` |
| `build_android.bat` | 构建 Android Release APK，支持 `--clean` / `--check` |

```bat
build_windows.bat            :: 常规构建
build_windows.bat --clean    :: 先 flutter clean 再构建（缓存/符号链接异常时用）
build_windows.bat --open     :: 构建成功后打开输出目录
```

> 若 `flutter pub get` 报 `Cannot create link ... .plugin_symlinks\...`，
> 说明 Windows 符号链接权限不足：请开启「设置 → 系统 → 开发者选项 → 开发人员模式」，
> 或先用 `build_windows.bat --clean` 清掉陈旧缓存后重试。

### 构建 Android 应用

```bat
build_android.bat                :: 常规构建（有正式签名时）
build_android.bat --clean        :: 先 flutter clean 再构建
build_android.bat --check        :: 只跑 Gradle 配置阶段做体检（约 2 分钟，不下载不编译）
build_android.bat --allow-debug-sign :: 没有正式签名时用 debug 签名出包（本地自测）
build_android.bat --require-sign :: 没有正式签名就拒绝构建（发布前自查用，已兼容）
```

产物：`build/app/outputs/flutter-apk/app-release.apk`。

**签名**：默认行为是**严格拒绝无签名构建**——没有 `android/key.properties` 时，
`build_android.bat` 会停止并提示创建签名，避免 debug 签名 APK 被误分发。
本地装机自测请显式加 `--allow-debug-sign`，它会用 debug 签名出包，
与之前本地构建的 APK 同签名，可以直接覆盖安装、保留学习数据。
注意 debug 签名的包**不能分发**，也无法覆盖已安装的正式签名版本（需先卸载）。

将来要发布/上架时，配置一次正式签名即可，之后 `build_android.bat` 会自动改用它：

```bat
keytool -genkeypair -v -keystore android\qingmang-release.jks -alias qingmang -keyalg RSA -keysize 2048 -validity 10000
copy android\key.properties.example android\key.properties   :: 再填入口令与别名
```

> 生成的 `.jks` 与 `key.properties` 都要另行备份：签名一旦丢失，就无法再发布能覆盖安装的更新。
> 从 debug 签名切换到正式签名时两者签名不同，**必须先卸载旧版**——
> 换之前建议先用应用内的备份功能导出一次数据，重装后导入。

> `--check` 内部直接调用 `android\gradlew.bat :app:assembleRelease --dry-run`。
> 注意 **Gradle 只认 `JAVA_HOME`**（flutter 的 `jdk-dir` 配置只在 flutter 启动 Gradle 时生效），
> 所以 `--check` 前需要先 `set "JAVA_HOME=D:\path\to\jdk-17"`；
> 脚本会自己检测并在 JAVA_HOME 版本过低时直接提示，不会给出误导性的结果。
> 配置阶段正是各类「插件工程配置失败」的暴露点，比完整构建快一个数量级。

#### ⚠️ 关于 APK 体积：`abiFilters` 不生效

`android/app/build.gradle.kts` 里写了

```kotlin
ndk {
    abiFilters += listOf("arm64-v8a")   // 注释说「仅保留 arm64，减小包体积」
}
```

但**实测无效**：这样打出来的 release APK 里仍然有 **3 套 ABI**（实测 75.6 MB）：

| ABI | 原生库数 | 解压后 |
|-----|---------|--------|
| arm64-v8a | 4 | 19.7 MB |
| armeabi-v7a | 4 | 17.6 MB |
| x86_64 | 4 | 21.1 MB |

原因：`defaultConfig.ndk.abiFilters` 只能过滤**应用自己的**原生代码，
管不到 Flutter 引擎（`libflutter.so`）和插件的预编译库——它们由 Flutter 的 Gradle 插件按
`--target-platform` 打包。要真正只出 arm64：

```bash
flutter build apk --release --target-platform android-arm64     # 只出 arm64，约 25 MB
flutter build apk --release --split-per-abi                     # 每种 ABI 单独出一个 APK
```

> 注意 `armeabi-v7a` 是 32 位老设备、`x86_64` 是模拟器。只出 arm64 会让这两类跑不了，
> 按实际需要取舍。`build_android.bat` 默认不传 `--target-platform`（保持全 ABI）。

脚本在构建前会自检 SDK 路径与 JDK 版本并给出修复提示。若需手动核对：

```bash
flutter doctor -v            # 看 Android toolchain 一行是否为 [√]
sdkmanager --list_installed  # 看已装的 platforms / build-tools
```

**环境要求（本项目当前配置）：**

| 项 | 值 | 说明 |
|----|----|------|
| Android SDK | `D:\edge\qingmang_weiji\.android-sdk` | **项目内专用 SDK**（约 3.3G，已被 `.gitignore` 忽略），含 `cmdline-tools;latest`、`platforms;android-36/36.1`、`build-tools;36.1.0`、`platform-tools`、**`ndk;28.2.13676358`**、`cmake;3.22.1` |
| JDK | `D:\Android\openjdk\jdk-17.0.12` | AGP 8.11 要求 **JDK 17+**；本机 `JAVA_HOME` 指向 JDK 8，因此改用 `flutter config --jdk-dir` 单独指定 |
| compileSdk / targetSdk | 36 | 取自 `flutter.compileSdkVersion` / `flutter.targetSdkVersion`，在 `android/app/build.gradle.kts` 中引用 |
| minSdk | 24 | 同上，取自 `flutter.minSdkVersion` |
| NDK / CMake | 28.2.13676358 / 3.22.1 | `jni`、`jni_flutter` 插件用 CMake 编译原生库，AGP 会自动下载缺失版本（本机网速慢，建议预先装好） |
| 签名 | 无 `key.properties` → debug 签名（每次构建都有提醒） | 正式签名放 `android/key.properties` 即自动启用；发布前可用 `--require-sign` 自查 |

> ⚠️ 项目曾位于 `C:\qingmang_weiji`，迁移到 `D:\edge\qingmang_weiji` 后
> `%APPDATA%\.flutter_settings` 里的 `android-sdk` 仍指向旧路径 `c:\qingmang_weiji\.android-sdk`，
> 导致 Android 构建全线失败。**换目录后必须同步更新该配置。**

**常见故障排查：**

| 报错 | 原因 | 修复 |
|------|------|------|
| `Unable to locate Android SDK` / SDK 路径显示成 `C:\` | `flutter config` 里的 `android-sdk` 指向了不存在的目录（该配置**优先于** `ANDROID_HOME`） | `flutter config --android-sdk "D:\edge\qingmang_weiji\.android-sdk"` |
| `No valid Android SDK platforms found` | `android/local.properties` 的 `sdk.dir` 错误 | 改为 `sdk.dir=D:/edge/qingmang_weiji/.android-sdk` |
| `Failed to find target with hash string 'android-36'` | 缺 `platforms;android-36` | `sdkmanager "platforms;android-36"` |
| `Android SDK file not found: adb` | 缺 `platform-tools` | `sdkmanager "platform-tools"` |
| `Android Gradle plugin requires Java 17` | `JAVA_HOME` 指向 JDK 8 | `flutter config --jdk-dir="D:\Android\openjdk\jdk-17.0.12"` |
| `NDK not configured` | 缺 `ndk;28.2.13676358` | `sdkmanager "ndk;28.2.13676358"` |
| `An error occurred while preparing SDK package CMake 3.22.1` | `dl.google.com/android/repository/cmake-3.22.1-windows.zip` 已 404 | 用镜像手动下载后解压到 `<sdk>/cmake/3.22.1/`（见下方） |
| `Could not download xxx.jar` / `Could not find com.android.tools.build:gradle:x.y.z` | Maven 仓库（`dl.google.com`、`repo.maven.apache.org`）被墙或超时 | 配阿里云 Maven 镜像（见下方） |
| `Android license status unknown` | SDK 的 `cmdline-tools` 缺失或为空（flutter 靠它调 sdkmanager 校验） | 补全 `<sdk>/cmdline-tools/latest`，或 `flutter doctor --android-licenses` |
| `does not specify compileSdk` + `TimeoutException` + `GenerateProjectAccessors` | Gradle 的 Kotlin DSL 生成「类型安全项目访问器」时 IO 超时，插件脚本里 `compileSdk = flutter.compileSdkVersion` 因此没生效。**注意 `does not specify compileSdk` 只是次生现象**，构建日志里那条 AGP 9 / `android.newDsl` 的 Flutter Fix 提示是启发式误报 | 依次试：① 关闭杀毒/安全软件的文件实时防护 ② 项目放到更短、无中文、非系统盘的路径 ③ `android\gradlew.bat --stop` 后重跑。用 `build_android.bat --check` 可在 ~2 分钟内复现验证 |

**跑 `pub get` 一定要带镜像环境变量**（否则 `pubspec.lock` 里的 `url` 会被改写成 `pub.dev`，
并可能把依赖升级到新版本）：

```bat
set PUB_CACHE=D:\dev_cache\.pub-cache
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter pub get --offline
```

> 依赖已全部缓存到本地时，加 `--offline` 只需十几秒；不加会走网络，实测曾挂死 25 分钟。

**Maven 镜像**（国内网络建议加上）——在 `android/settings.gradle.kts` 的 `pluginManagement.repositories`
以及各 `buildscript.repositories` / `allprojects.repositories` 里，把镜像放在 `google()` 之前：

```kotlin
maven { url = uri("https://maven.aliyun.com/repository/google") }
maven { url = uri("https://maven.aliyun.com/repository/public") }
maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
google()
mavenCentral()
```

**手动装 CMake**（`sdkmanager` 因上游 URL 404 装不上时）：

```bash
# 15.4 MiB，实测 ~3 MB/s
curl -L -o cmake.zip https://mirrors.cloud.tencent.com/AndroidSDK/cmake-3.22.1-windows.zip
# 解压到 <sdk>/cmake/3.22.1/，使 <sdk>/cmake/3.22.1/bin/cmake.exe 存在
```

> 注：`flutter_plugin_android_lifecycle` 等官方插件会在自己的 `android/build.gradle.kts` 里
> 硬编码 `classpath("com.android.tools.build:gradle:8.13.1")`，该版本只发布在 Google Maven，
> **Maven Central 上没有**——所以 `google()` 仓库必须可达，镜像也必须是 google 镜像。

> 注：`android/local.properties` 与 `%APPDATA%\.flutter_settings` 都是**本机专属配置**，不会进版本库，
> 换机器后需要重新设置。

## 📦 词库数据

项目内置 7 本词书（v2.0.0 ECDICT 数据源），共计 34,059 词：

| 词书 | 单词数 | 说明 |
|------|--------|------|
| 初中英语词汇 | 1,989 | 初中英语必背词汇 |
| 高中英语词汇 | 3,749 | 高中英语必背词汇 |
| 大学英语四级 | 4,543 | CET-4 考试核心词汇 |
| 大学英语六级 | 3,991 | CET-6 考试核心词汇 |
| 考研英语词汇 | 5,052 | 研究生入学考试词汇 |
| 托福词汇 | 10,284 | TOEFL 考试核心词汇 |
| SAT词汇 | 4,451 | SAT 考试核心词汇 |

每个单词包含：音标、释义、短语搭配、中英对照例句。

词库文件位于 `assets/wordbooks/` 目录。

## 🛠️ 技术架构

### 分层架构

```
lib/
├── models/          # 数据模型
├── services/        # 业务逻辑
├── screens/         # 页面
├── widgets/         # 可复用组件
└── utils/           # 工具类
```

### 核心服务

- `DatabaseService` - SQLite 数据库操作
- `ReviewScheduler` - SM-2 复习算法
- `WrongWordService` - 错词本管理
- `DefinitionService` - 词典查询
- `TtsService` - 文本转语音

### 状态管理

使用 `Provider` 进行状态管理，主要组件：
- `AppProvider` - 应用全局状态
- `WordBookProvider` - 词库状态

## 📊 统计功能

- **词汇量估算** - 基于学习进度估算词汇量
- **连续学习天数** - 打卡记录
- **学习热力图** - GitHub 风格的学习日历
- **记忆阶段分布** - 饼图展示
- **复习趋势图** - 折线图展示

## 🔧 开发指南

### 添加新词库

1. 准备 JSON 格式词库文件
2. 放入 `assets/wordbooks/` 目录
3. 在 `pubspec.yaml` 中注册资源
4. 使用 `SeedService` 导入数据库

### 自定义设置

在 `lib/utils/constants.dart` 中修改：

```dart
class AppConstants {
  static const int defaultDailyNewWords = 20;    // 每日新词上限
  static const int defaultDailyReviewWords = 50; // 每日复习上限
}
```

## 🐛 已知问题

- 在线词典 API 偶尔超时
- 大词库首次加载较慢
- 部分生僻单词无发音

## 📝 版本历史

### v3.2.0
- 📖 新增词书阅读模式：书架进度、翻页阅读器、书签/目录检索、排版与背景自定义、仿真翻页动画
- 🎛️ 回忆模式评分键支持位置与尺寸自定义（锚点 + dp 偏移，换设备不漂移）
- ⭐ 收藏夹重新上线为单词级跨词库模型，错题集/收藏夹各自提供入口级设置
- 🔍 首页顶栏支持搜索全部词库，无需切换 Tab
- 🧭 新增 Coach Mark 功能引导，可跨 Tab 串成主巡览，埋点全部本地
- 🔐 备份导出支持口令加密（PBKDF2-HMAC-SHA256 + AES-256-GCM），历史明文备份兼容恢复
- 📊 首页改为数据看板形态，学习报告支持日/周/月/年与逐日明细表
- 🎨 新增「液态玻璃」界面风格，与流体渐变可在设置中切换；导航改为悬浮胶囊
- 🖥️ Windows 专属：Toast 提示音自播、输入法自动切英文、空闲降频
- 📱 Android 专属：音量键翻页、通知图标资源保活、输入法自动切英文
- 🗄️ 数据库 v14 → v23：新增阅读三表与 `word_favorites`，`wrong_words.correct_streak` 落盘，补建多处索引
- ✂️ 移除成就系统、自定义词组、在线词库下载链路与 `assets/wordlists/` 旧明文词表

完整变更记录见 [CHANGELOG.md](CHANGELOG.md)。

### v3.0.0
- 🐛 数据安全修复：恢复备份不再丢失阅读模式数据，词库升级改为迁移学习记录而非直接清空
- 🎯 复习算法：复习时间归一到日界（跨天后当天即可复习），补全「完全忘记」的难度因子衰减
- ⚡ 性能优化：统计与薄弱词查询改走索引、错词结果批量写入、随机干扰词取样、词库搜索过滤缓存、阅读器分页移出构建路径
- 🔊 发音与词典：修复并发播放互相打断、协议相对音频地址、有道例句解析、音频缓存文件名冲突
- 🧹 清理未启用的内置词库自动升级链路与死代码，统一内置词库清单来源

### v2.1.0
- 🖥️ Windows 端优化：窗口标题、最小尺寸、居中显示、单实例、Mica 效果、键盘快捷键
- 📱 Android 端优化：自适应图标、预测性返回、SplashScreen API、largeHeap、安全配置
-  导航位置用户偏好：桌面端/Web 可切换左侧栏或底部导航栏
- 🎨 Android 启动屏改为流体渐变风格，与 Windows 保持一致
- 📱 Android 端隐藏键盘快捷键提示，改为触控友好文案
- ⚡ 移除冗余 multidex 配置，启用 R8 Full Mode 优化
- 🧪 新增 35 项 Android 适配测试

### v2.0.0
- 🔄 词库数据源全面升级为 ECDICT
- 📚 内置 7 本词书：初中、高中、CET-4、CET-6、考研、托福、SAT
- 📝 每个单词含音标、释义、短语搭配、中英对照例句
- 🎓 成就系统（achievements 表）
-  学习会话记录（study_sessions 表）
- 🗄️ 数据库升级至 v4

### v1.0.0
- ✨ 初始版本发布
- 🧠 SM-2 复习算法实现
- 📚 CET-4 词库支持
- 🔊 TTS 发音功能
- 📊 学习统计图表
- 📝 错词本功能

## 📄 许可证

Apache License 2.0 - 详见 [LICENSE](LICENSE) 文件

## 👥 贡献

欢迎提交 Issue 和 Pull Request！

## 🙏 致谢

- [Flutter](https://flutter.dev/) - UI 框架
- [SuperMemo](https://www.super-memory.com/) - SM-2 算法
- [Free Dictionary API](https://dictionaryapi.dev/) - 在线词典
- [ECDICT](https://github.com/skywind3000/ECDICT) - 词库数据

---

**清茫微记** - 让英语学习更高效 📚
