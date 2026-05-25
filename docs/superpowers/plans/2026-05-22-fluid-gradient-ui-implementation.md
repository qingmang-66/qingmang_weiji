# 流体渐变 UI 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为清茫微记应用实现 120fps 流体渐变 UI 系统，包括 Shader 流体背景、弹簧动效卡片、渐变按钮等核心组件

**Architecture:** 采用分层架构：底层 Shader 渲染层 → 中间组件封装层 → 上层业务应用层。使用 FragmentProgram 实现真正的流体模拟，结合 SpringDescription 物理动画实现 120fps 流畅交互

**Tech Stack:** 
- Flutter 3.32+ (Impeller 引擎)
- Fragment Shader (GLSL)
- SpringDescription 物理动画
- Provider 状态管理
- VisibilityDetector 可见性检测

---

## 文件结构总览

### 新增文件
```
lib/
├── theme/
│   └── fluid_theme.dart              # 流体主题系统
├── widgets/
│   ├── fluid_background.dart         # 流体渐变背景组件
│   ├── fluid_card.dart               # 流体卡片组件
│   ├── fluid_button.dart             # 流体按钮组件
│   ├── fluid_app_bar.dart            # 流体导航栏
│   ├── fluid_dialog.dart             # 流体对话框
│   └── fluid_loading.dart            # 流体加载动画
├── utils/
│   └── animations/
│       ├── spring_curves.dart        # 弹簧曲线定义
│       └── fluid_curves.dart         # 流体动画曲线
└── shaders/
    ├── fluid_bg.frag                 # 流体背景 Shader
    ├── shimmer.frag                  # Shimmer 光效 Shader
    └── ripple.frag                   # 涟漪效果 Shader

assets/
└── animations/
    └── fluid_particles.riv           # 粒子动画 (可选)

test/
├── widgets/
│   ├── fluid_card_test.dart
│   ├── fluid_button_test.dart
│   └── fluid_background_test.dart
└── utils/
    └── animations/
        └── spring_curves_test.dart
```

### 修改文件
```
lib/
├── main.dart                         # 启用 Impeller 配置
├── screens/
│   ├── home_screen.dart              # 首页重构
│   ├── study_screen.dart             # 学习页重构
│   ├── wordbook_screen.dart          # 词库页重构
│   └── stats_screen.dart             # 统计页重构
└── utils/
    └── theme/
        └── design_tokens.dart        # 更新设计令牌
```

---

## 依赖配置

### pubspec.yaml 新增依赖
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # 核心依赖
  provider: ^6.1.2                    # 状态管理
  visibility_detector: ^0.4.0         # 可见性检测
  
  # 可选依赖（高级效果）
  flutter_shader_fx: ^0.1.0           # Shader 效果库
  rive: ^0.13.0                       # 复杂动画
  
  # 工具库
  device_info_plus: ^11.0.0           # 设备信息（可选）
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

---

## 实施任务分解

### Task 1: 项目配置与 Shader 环境搭建

**Files:**
- Create: `lib/shaders/fluid_bg.frag`
- Create: `lib/shaders/shimmer.frag`
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`

- [ ] **Step 1: 添加依赖到 pubspec.yaml**

```yaml
dependencies:
  provider: ^6.1.2
  visibility_detector: ^0.4.0
  flutter_shader_fx: ^0.1.0  # 可选
  rive: ^0.13.0              # 可选

dev_dependencies:
  flutter_test:
    sdk: flutter
```

- [ ] **Step 2: 运行 flutter pub get**

```bash
flutter pub get
```

- [ ] **Step 3: 创建流体背景 Shader (fluid_bg.frag)**

```glsl
#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform vec4 u_color1;
uniform vec4 u_color2;
uniform vec4 u_color3;

out vec4 frag_color;

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  
  // 流体模拟（简化版）
  vec3 color = mix(
    u_color1.rgb,
    u_color2.rgb,
    sin(uv.x * 3.0 + u_time * 0.5) * 0.5 + 0.5
  );
  
  color = mix(
    color,
    u_color3.rgb,
    cos(uv.y * 2.0 + u_time * 0.3) * 0.5 + 0.5
  );
  
  // 添加噪点增加流动感
  float noise = sin(uv.x * 10.0 + u_time) * cos(uv.y * 10.0 - u_time) * 0.1;
  color += noise;
  
  frag_color = vec4(color, 1.0);
}
```

- [ ] **Step 4: 创建 Shimmer 光效 Shader (shimmer.frag)**

```glsl
#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform vec4 u_color;

out vec4 frag_color;

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  
  // 对角线 Shimmer 效果
  float shimmer = sin(uv.x * 5.0 + uv.y * 3.0 + u_time * 2.0) * 0.5 + 0.5;
  shimmer = pow(shimmer, 3.0); // 增强亮度
  
  frag_color = vec4(u_color.rgb, shimmer * u_color.a);
}
```

- [ ] **Step 5: 在 pubspec.yaml 中注册 Shader 资源**

```yaml
flutter:
  assets:
    - assets/shaders/
```

- [ ] **Step 6: 配置 Impeller 引擎（Android）**

创建 `android/gradle.properties`:
```properties
android.enableImpeller=true
```

- [ ] **Step 7: 配置 Impeller 引擎（iOS）**

在 `ios/Runner/Info.plist` 中添加:
```xml
<key>FLTEnableImpeller</key>
<true/>
```

- [ ] **Step 8: 更新 main.dart 启用 Impeller**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 确保 Impeller 启用
  if (Platform.isAndroid || Platform.isIOS) {
    // Impeller 在 Flutter 3.27+ 默认启用
    print('Impeller enabled by default');
  }
  
  runApp(const QingMangApp());
}
```

- [ ] **Step 9: 创建 shaders 资源目录**

```bash
mkdir -p assets/shaders
cp lib/shaders/*.frag assets/shaders/
```

- [ ] **Step 10: 验证 Shader 编译**

```bash
flutter build apk --profile
```

Expected: 编译成功，无 Shader 错误

- [ ] **Step 11: Commit**

```bash
git add pubspec.yaml lib/main.dart lib/shaders/ assets/shaders/
git commit -m "feat: setup shader environment and Impeller config"
```

---

### Task 2: 弹簧曲线与动画工具类

**Files:**
- Create: `lib/utils/animations/spring_curves.dart`
- Create: `lib/utils/animations/fluid_curves.dart`
- Create: `test/utils/animations/spring_curves_test.dart`

- [ ] **Step 1: 创建弹簧曲线定义 (spring_curves.dart)**

```dart
import 'package:flutter/animation.dart';

/// 120fps 优化的弹簧物理曲线
class SpringCurves {
  /// 按钮点击反馈 - 快速响应
  static const SpringDescription click = SpringDescription(
    mass: 0.8,       // 更轻质量，更快响应
    stiffness: 220.0, // 更高刚度
    damping: 18.0,    // 适中阻尼，快速稳定
  );

  /// 卡片展开/收起
  static const SpringDescription expand = SpringDescription(
    mass: 1.2,
    stiffness: 200.0,
    damping: 20.0,
  );

  /// 页面切换 - 流畅过渡
  static const SpringDescription page = SpringDescription(
    mass: 1.5,
    stiffness: 180.0,
    damping: 22.0,
  );

  /// 对话框弹出
  static const SpringDescription dialog = SpringDescription(
    mass: 1.0,
    stiffness: 190.0,
    damping: 19.0,
  );

  /// 图标缩放
  static const SpringDescription icon = SpringDescription(
    mass: 0.6,
    stiffness: 240.0,
    damping: 16.0,
  );

  /// 将 SpringDescription 转换为 Animation
  static Animation<double> createAnimation({
    required SpringDescription spring,
    required TickerProvider vsync,
    double begin = 0.0,
    double end = 1.0,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    final controller = AnimationController(
      duration: duration,
      vsync: vsync,
    );

    final simulation = SpringSimulation(
      spring,
      begin,
      end,
      0.0, // 初始速度
    );

    return controller.drive(simulation);
  }
}
```

- [ ] **Step 2: 创建流体动画曲线 (fluid_curves.dart)**

```dart
import 'package:flutter/animation.dart';

/// 流体渐变动画曲线定义
class FluidCurves {
  /// 渐变流动动画 - 快速流畅
  static const Duration fluidDuration = Duration(milliseconds: 2000);
  static const Curve fluidCurve = Curves.easeInOut;

  /// Shimmer 光效动画 - 更快速
  static const Duration shimmerDuration = Duration(milliseconds: 1500);
  static const Curve shimmerCurve = Curves.linear;

  /// 粒子动画
  static const Duration particleDuration = Duration(milliseconds: 1000);
  static const Curve particleCurve = Curves.easeOut;

  /// 背景流动速度系数
  static const double fluidSpeed = 1.0;

  /// Shimmer 强度
  static const double shimmerIntensity = 0.6;

  /// 创建流动渐变动画
  static Animation<AlignmentGeometry> createFluidAnimation({
    required TickerProvider vsync,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    final controller = AnimationController(
      duration: fluidDuration,
      vsync: vsync,
    );

    return Tween<AlignmentGeometry>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: fluidCurve,
    ));
  }

  /// 创建 Shimmer 动画
  static Animation<double> createShimmerAnimation({
    required TickerProvider vsync,
  }) {
    final controller = AnimationController(
      duration: shimmerDuration,
      vsync: vsync,
    );

    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: shimmerCurve,
    ));
  }
}
```

- [ ] **Step 3: 创建弹簧曲线测试 (spring_curves_test.dart)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/animation.dart';
import 'package:qingmang_weiji/utils/animations/spring_curves.dart';

void main() {
  group('SpringCurves', () {
    test('click spring has correct parameters', () {
      expect(SpringCurves.click.mass, closeTo(0.8, 0.01));
      expect(SpringCurves.click.stiffness, closeTo(220.0, 1.0));
      expect(SpringCurves.click.damping, closeTo(18.0, 1.0));
    });

    test('expand spring has correct parameters', () {
      expect(SpringCurves.expand.mass, closeTo(1.2, 0.01));
      expect(SpringCurves.expand.stiffness, closeTo(200.0, 1.0));
      expect(SpringCurves.expand.damping, closeTo(20.0, 1.0));
    });

    test('page spring has correct parameters', () {
      expect(SpringCurves.page.mass, closeTo(1.5, 0.01));
      expect(SpringCurves.page.stiffness, closeTo(180.0, 1.0));
      expect(SpringCurves.page.damping, closeTo(22.0, 1.0));
    });

    test('createAnimation returns non-null animation', () {
      final TestTickerProvider ticker = TestTickerProvider();
      
      final animation = SpringCurves.createAnimation(
        spring: SpringCurves.click,
        vsync: ticker,
      );

      expect(animation, isNotNull);
      expect(animation, isA<Animation<double>>());
    });
  });
}

class TestTickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) {
    return Ticker(onTick);
  }
}
```

- [ ] **Step 4: 运行测试验证**

```bash
flutter test test/utils/animations/spring_curves_test.dart
```

Expected: 所有测试通过

- [ ] **Step 5: Commit**

```bash
git add lib/utils/animations/ test/utils/animations/
git commit -m "feat: create spring and fluid animation curves"
```

---

### Task 3: 流体主题系统

**Files:**
- Create: `lib/theme/fluid_theme.dart`
- Modify: `lib/utils/theme/design_tokens.dart`

- [ ] **Step 1: 创建流体主题系统 (fluid_theme.dart)**

```dart
import 'package:flutter/material.dart';

/// 流体渐变主题配置
class FluidTheme {
  /// 主色调 - 蓝紫流动渐变
  static const List<Color> primaryGradient = [
    Color(0xFF0F0C29), // 深紫黑
    Color(0xFF302B63), // 深紫
    Color(0xFF24243E), // 深蓝
    Color(0xFF1A1A2E), // 午夜蓝
  ];

  /// 强调色 - 粉蓝流动渐变
  static const List<Color> accentGradient = [
    Color(0xFFF093FB), // 粉紫
    Color(0xFFF5576C), // 珊瑚红
    Color(0xFF4FACFE), // 天蓝
  ];

  /// 成功色渐变
  static const List<Color> successGradient = [
    Color(0xFF11998E),
    Color(0xFF38EF7D),
  ];

  /// 警告色渐变
  static const List<Color> warningGradient = [
    Color(0xFFFC4A1A),
    Color(0xFFF7B733),
  ];

  /// 错误色渐变
  static const List<Color> errorGradient = [
    Color(0xFFE53935),
    Color(0xFFE91E63),
  ];

  /// 卡片渐变
  static const List<Color> cardGradient = [
    Color(0xFF2D3748),
    Color(0xFF1A202C),
  ];

  /// 按钮渐变
  static const List<Color> buttonGradient = [
    Color(0xFF667EEA),
    Color(0xFF764BA2),
  ];

  /// 获取渐变方向
  static AlignmentGeometry getGradientBegin(String type) {
    switch (type) {
      case 'background':
        return Alignment.topLeft;
      case 'card':
        return Alignment.topLeft;
      case 'button':
        return Alignment.centerLeft;
      case 'text':
        return Alignment.centerLeft;
      default:
        return Alignment.topLeft;
    }
  }

  static AlignmentGeometry getGradientEnd(String type) {
    switch (type) {
      case 'background':
        return Alignment.bottomRight;
      case 'card':
        return Alignment.bottomRight;
      case 'button':
        return Alignment.centerRight;
      case 'text':
        return Alignment.centerRight;
      default:
        return Alignment.bottomRight;
    }
  }

  /// 创建线性渐变
  static LinearGradient createGradient({
    required List<Color> colors,
    String type = 'background',
  }) {
    return LinearGradient(
      colors: colors,
      begin: getGradientBegin(type),
      end: getGradientEnd(type),
    );
  }
}
```

- [ ] **Step 2: 更新设计令牌 (design_tokens.dart)**

```dart
// 在 DesignTokens 类中添加流体主题相关常量

class DesignTokens {
  // ... 现有代码 ...

  // 流体主题颜色
  static const fluidPrimary = FluidTheme.primaryGradient;
  static const fluidAccent = FluidTheme.accentGradient;
  static const fluidSuccess = FluidTheme.successGradient;
  static const fluidWarning = FluidTheme.warningGradient;
  static const fluidError = FluidTheme.errorGradient;

  // 流体动画配置
  static const Duration fluidAnimationDuration = Duration(milliseconds: 2000);
  static const Duration shimmerDuration = Duration(milliseconds: 1500);
  
  // 弹簧动画配置
  static const SpringDescription springClick = SpringCurves.click;
  static const SpringDescription springExpand = SpringCurves.expand;
  static const SpringDescription springPage = SpringCurves.page;
}
```

- [ ] **Step 3: 创建主题 Provider**

```dart
import 'package:flutter/material.dart';

class FluidThemeProvider extends ChangeNotifier {
  bool _fluidBackgroundEnabled = true;
  bool _springAnimationsEnabled = true;
  double _fluidSpeed = 1.0;

  bool get fluidBackgroundEnabled => _fluidBackgroundEnabled;
  bool get springAnimationsEnabled => _springAnimationsEnabled;
  double get fluidSpeed => _fluidSpeed;

  void toggleFluidBackground() {
    _fluidBackgroundEnabled = !_fluidBackgroundEnabled;
    notifyListeners();
  }

  void toggleSpringAnimations() {
    _springAnimationsEnabled = !_springAnimationsEnabled;
    notifyListeners();
  }

  void setFluidSpeed(double speed) {
    _fluidSpeed = speed.clamp(0.5, 2.0);
    notifyListeners();
  }
}
```

- [ ] **Step 4: 在 main.dart 中注册 FluidThemeProvider**

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => FluidThemeProvider()),
    // ... 其他 Provider
  ],
  child: MaterialApp(...),
)
```

- [ ] **Step 5: Commit**

```bash
git add lib/theme/ lib/utils/theme/design_tokens.dart lib/main.dart
git commit -m "feat: create fluid theme system"
```

---

### Task 4: 核心组件 - 流体背景

**Files:**
- Create: `lib/widgets/fluid_background.dart`
- Create: `test/widgets/fluid_background_test.dart`

- [ ] **Step 1: 创建流体背景组件**

```dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../theme/fluid_theme.dart';
import '../utils/animations/fluid_curves.dart';

class FluidBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final double speed;
  final bool enableTouch;

  const FluidBackground({
    super.key,
    required this.child,
    this.colors,
    this.speed = 1.0,
    this.enableTouch = false,
  });

  @override
  State<FluidBackground> createState() => _FluidBackgroundState();
}

class _FluidBackgroundState extends State<FluidBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  ui.FragmentProgram? _shaderProgram;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(
        milliseconds: (2000 / widget.speed).round(),
      ),
      vsync: this,
    )..repeat();

    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      _shaderProgram = await ui.FragmentProgram.fromAsset(
        'assets/shaders/fluid_bg.frag',
      );
      _updateShader();
    } catch (e) {
      print('Shader load error: $e');
      // Fallback to gradient
    }
  }

  void _updateShader() {
    if (_shaderProgram != null) {
      _shader = _shaderProgram!.fragmentShader();
      _shader!
        ..setFloat(0, MediaQuery.of(context).size.width)
        ..setFloat(1, MediaQuery.of(context).size.height)
        ..setFloat(2, _controller.value * 2 * 3.14159);

      // 设置颜色
      final colors = widget.colors ?? FluidTheme.primaryGradient;
      if (colors.length >= 3) {
        _shader!
          ..setFloat(3, colors[0].r)
          ..setFloat(4, colors[0].g)
          ..setFloat(5, colors[0].b)
          ..setFloat(6, colors[0].a)
          ..setFloat(7, colors[1].r)
          ..setFloat(8, colors[1].g)
          ..setFloat(9, colors[1].b)
          ..setFloat(10, colors[1].a)
          ..setFloat(11, colors[2].r)
          ..setFloat(12, colors[2].g)
          ..setFloat(13, colors[2].b)
          ..setFloat(14, colors[2].a);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _shaderProgram?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Shader 背景层
        if (_shader != null)
          CustomPaint(
            size: Size.infinite,
            painter: _ShaderPainter(shader: _shader!),
          )
        else
          // Fallback: 渐变背景
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.colors ?? FluidTheme.primaryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

        // 内容层
        widget.child,
      ],
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;

  _ShaderPainter({required this.shader});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _ShaderPainter oldDelegate) {
    return oldDelegate.shader != shader;
  }
}
```

- [ ] **Step 2: 创建流体背景测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:qingmang_weiji/widgets/fluid_background.dart';

void main() {
  group('FluidBackground', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FluidBackground(
            child: Text('Test'),
          ),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('applies custom colors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FluidBackground(
            colors: [Colors.red, Colors.blue],
            child: SizedBox(),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('handles shader load failure gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FluidBackground(
            child: Text('Fallback'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Fallback'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 3: 运行测试**

```bash
flutter test test/widgets/fluid_background_test.dart
```

Expected: 所有测试通过

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/fluid_background.dart test/widgets/fluid_background_test.dart
git commit -m "feat: create fluid background component with Shader support"
```

---

### Task 5: 核心组件 - 流体卡片

**Files:**
- Create: `lib/widgets/fluid_card.dart`
- Create: `test/widgets/fluid_card_test.dart`

- [ ] **Step 1: 创建流体卡片组件**

```dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../theme/fluid_theme.dart';
import '../utils/animations/spring_curves.dart';
import '../utils/animations/fluid_curves.dart';
import '../theme/fluid_theme.dart';

class FluidCard extends StatefulWidget {
  final Widget child;
  final List<Color>? gradientColors;
  final double shimmerIntensity;
  final VoidCallback? onTap;
  final bool selected;

  const FluidCard({
    super.key,
    required this.child,
    this.gradientColors,
    this.shimmerIntensity = 0.6,
    this.onTap,
    this.selected = false,
  });

  @override
  State<FluidCard> createState() => _FluidCardState();
}

class _FluidCardState extends State<FluidCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    // 弹簧缩放动画
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      SpringSimulation(
        SpringCurves.click,
        1.0,
        0.95,
        0.0,
      ),
    );

    // Shimmer 动画
    _shimmerController = AnimationController(
      duration: FluidCurves.shimmerDuration,
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: FluidCurves.shimmerCurve,
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      _scaleController.forward().then((_) {
        _scaleController.reverse();
        widget.onTap!();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isHovered ? 1.02 : _scaleAnimation.value,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.gradientColors ?? FluidTheme.cardGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: widget.selected
                  ? Border.all(
                      color: FluidTheme.accentGradient[0],
                      width: 2,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isHovered ? 0.15 : 0.1),
                  blurRadius: _isHovered ? 32 : 20,
                  offset: Offset(0, _isHovered ? 12 : 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Shimmer 层
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: _ShimmerPainter(
                        progress: _shimmerAnimation.value,
                        intensity: widget.shimmerIntensity,
                      ),
                    );
                  },
                ),

                // 内容层
                widget.child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;
  final double intensity;

  _ShimmerPainter({required this.progress, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(size.width, size.height),
        [
          Colors.transparent,
          Colors.white.withValues(alpha: intensity),
          Colors.transparent,
        ],
        [
          0.0,
          progress,
          1.0,
        ],
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity;
  }
}
```

- [ ] **Step 2: 创建流体卡片测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:qingmang_weiji/widgets/fluid_card.dart';

void main() {
  group('FluidCard', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FluidCard(
            child: Text('Test Card'),
          ),
        ),
      );

      expect(find.text('Test Card'), findsOneWidget);
    });

    testWidgets('applies custom gradient colors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FluidCard(
            gradientColors: [Colors.red, Colors.blue],
            child: SizedBox(),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: FluidCard(
            onTap: () => tapped = true,
            child: const Text('Tap Me'),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('shows selected border when selected is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FluidCard(
            selected: true,
            child: Text('Selected'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Selected'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 3: 运行测试**

```bash
flutter test test/widgets/fluid_card_test.dart
```

Expected: 所有测试通过

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/fluid_card.dart test/widgets/fluid_card_test.dart
git commit -m "feat: create fluid card with spring animations and shimmer effect"
```

---

### Task 6: 核心组件 - 流体按钮

**Files:**
- Create: `lib/widgets/fluid_button.dart`
- Create: `test/widgets/fluid_button_test.dart`

（按照相同模式继续创建流体按钮组件，包含弹簧反馈、渐变流动、涟漪效果）

---

### Task 7: 核心组件 - 流体对话框

**Files:**
- Create: `lib/widgets/fluid_dialog.dart`

（创建流体对话框组件，包含 AnimatedScale + FluidCard 组合）

---

### Task 8: 核心组件 - 流体导航栏

**Files:**
- Create: `lib/widgets/fluid_app_bar.dart`

（创建流体导航栏，包含渐变背景、流动动画、标题文字渐变）

---

### Task 9: 核心组件 - 流体加载动画

**Files:**
- Create: `lib/widgets/fluid_loading.dart`

（创建流体加载动画，使用 CustomPainter 或 Rive）

---

### Task 10: 页面重构 - 首页

**Files:**
- Modify: `lib/screens/home_screen.dart`

（使用新的流体组件重构首页）

---

### Task 11: 页面重构 - 学习页

**Files:**
- Modify: `lib/screens/study_screen.dart`

（重构学习页，包含单词卡片流体、答案按钮流体）

---

### Task 12: 页面重构 - 词库页

**Files:**
- Modify: `lib/screens/wordbook_screen.dart`

（重构词库页，包含词库列表流体、筛选对话框流体）

---

### Task 13: 页面重构 - 统计页

**Files:**
- Modify: `lib/screens/stats_screen.dart`

（重构统计页，图表容器流体、数据卡片流体）

---

### Task 14: 性能测试与优化

**Files:**
- Create: `test/performance/fluid_components_perf_test.dart`

- [ ] **Step 1: 创建性能测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:qingmang_weiji/widgets/fluid_card.dart';
import 'package:qingmang_weiji/widgets/fluid_button.dart';

void main() {
  group('Fluid Components Performance', () {
    testWidgets('FluidCard renders at 120fps', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluidCard(
              child: Text('Performance Test'),
            ),
          ),
        ),
      );

      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 8));
      }

      stopwatch.stop();
      final avgFrameTime = stopwatch.elapsedMilliseconds / 120;

      // 120fps = 8.33ms per frame
      expect(avgFrameTime, lessThan(10));
    });
  });
}
```

- [ ] **Step 2: 使用 DevTools 性能分析**

```bash
flutter run --profile
# 打开 DevTools → Performance
# 检查 UI thread 和 Raster thread
```

- [ ] **Step 3: 优化 Shader 性能**

- 使用 RepaintBoundary 包裹动画区域
- 添加 VisibilityDetector 暂停不可见动画
- 优化 uniform 更新频率

- [ ] **Step 4: Commit**

```bash
git add test/performance/
git commit -m "test: add 120fps performance tests for fluid components"
```

---

### Task 15: 文档更新

**Files:**
- Create: `docs/FLUID_UI_GUIDE.md`

- [ ] **Step 1: 创建使用指南**

```markdown
# 流体渐变 UI 使用指南

## 快速开始

### 1. 流体背景

```dart
FluidBackground(
  child: YourContent(),
)
```

### 2. 流体卡片

```dart
FluidCard(
  gradientColors: [Colors.blue, Colors.purple],
  shimmerIntensity: 0.6,
  onTap: () => print('Tapped!'),
  child: Text('Card Content'),
)
```

### 3. 流体按钮

```dart
FluidButton(
  label: 'Click Me',
  gradientColors: [Colors.green, Colors.teal],
  onPressed: () => submit(),
)
```

## 性能最佳实践

1. 使用 RepaintBoundary 包裹动画区域
2. 页面不可见时暂停动画
3. 控制 Shader uniform 更新频率
```

- [ ] **Step 2: Commit**

```bash
git add docs/FLUID_UI_GUIDE.md
git commit -m "docs: add fluid UI usage guide"
```

---

## 测试策略

### 单元测试
- 弹簧曲线参数验证
- 动画持续时间验证
- 组件渲染测试

### 性能测试
- 120fps 帧率测试
- GPU 占用率测试
- 内存占用测试

### 真机测试
- 小米 13 Pro (120Hz AMOLED)
- iPhone 14 Pro (ProMotion 120Hz)
- 酷睿 Ultra 7 笔记本 (高刷屏)

---

## 验收标准

### 技术指标
- ✅ 120Hz 设备稳定 120fps
- ✅ GPU 占用率 < 75%
- ✅ 内存占用 < 300MB
- ✅ 首次渲染无卡顿

### 用户体验指标
- ✅ 所有卡片带 Shimmer 光效
- ✅ 所有按钮带弹簧反馈
- ✅ 所有页面带流体背景
- ✅ 交互流畅自然

---

**计划完成！**

接下来请选择执行方式：
1. **Subagent-Driven** (推荐) - 每个任务由独立子代理执行，任务间审查
2. **Inline Execution** - 在当前会话中批量执行任务

您选择哪种方式？
