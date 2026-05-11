# 清茫微记 (QingMang WeiJi)

基于艾宾浩斯遗忘曲线的英语单词记忆软件，支持 Windows 桌面端。

![Platform](https://img.shields.io/badge/platform-Windows-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.0+-cyan)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ 特性

- 🧠 **SM-2 智能复习算法** - 基于 SuperMemo 2 算法，结合艾宾浩斯遗忘曲线
- 📚 **多词库支持** - CET-4/6、考研、托福等内置词库
- 🔊 **TTS 发音 + 在线词典** - 单词发音和在线释义查询
- 📊 **学习统计图表** - 记忆曲线、掌握度分布、学习热力图
- 📝 **错词本功能** - 自动收集错词，支持专项复习
- 🌙 **暗黑模式** - 舒适的视觉体验
- 📱 **跨平台** - Windows 桌面端，未来支持移动端

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

构建完成后，exe 文件位于 `build/windows/x64/Release/qingmang_weiji/`

## 📦 词库数据

项目包含以下词库：

| 词库 | 单词数 | 说明 |
|------|--------|------|
| CET4-Core | 5000 | 大学英语四级核心词汇 |
| cet4_full | 12409 | 完整版四级词汇 |

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

## 🎓 成就系统

| 成就 | 条件 |
|------|------|
| 初次见面 | 学习任意单词 |
| 3 天连续 | 连续学习 3 天 |
| 7 天连续 | 连续学习 7 天 |
| 学习 100 词 | 累计学习 100 词 |
| 复习达人 | 单日复习 50 词 |

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

### v1.0.0 (2026-05-07)
- ✨ 初始版本发布
- 🧠 SM-2 复习算法实现
- 📚 CET-4 词库支持
- 🔊 TTS 发音功能
- 📊 学习统计图表
- 📝 错词本功能

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 👥 贡献

欢迎提交 Issue 和 Pull Request！

## 🙏 致谢

- [Flutter](https://flutter.dev/) - UI 框架
- [SuperMemo](https://www.super-memory.com/) - SM-2 算法
- [Free Dictionary API](https://dictionaryapi.dev/) - 在线词典
- [ECDICT](https://github.com/skywind3000/ECDICT) - 词库数据

---

**清茫微记** - 让英语学习更高效 📚
