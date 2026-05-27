import 'package:flutter/material.dart';
import '../utils/animations/fluid_curves.dart';
import '../utils/translations.dart';

/// 统一 UI 组件展示页面
class UIShowcaseScreen extends StatefulWidget {
  const UIShowcaseScreen({super.key});

  @override
  State<UIShowcaseScreen> createState() => _UIShowcaseScreenState();
}

class _UIShowcaseScreenState extends State<UIShowcaseScreen>
    with TickerProviderStateMixin {
  // 卡片弹簧动画控制器
  final List<AnimationController> _cardControllers = [];

  // 按钮弹簧动画控制器
  final List<AnimationController> _btnControllers = [];

  // 涟漪效果列表
  final List<_RippleState> _ripples = [];

  // 背景 shimmer 动画
  late AnimationController _bgShimmerController;

  @override
  void initState() {
    super.initState();

    // 初始化3个卡片控制器
    for (int i = 0; i < 3; i++) {
      _cardControllers.add(
        AnimationController(
          vsync: this,
          value: 1.0,
          lowerBound: 0.5,
          upperBound: 1.5,
        ),
      );
    }

    // 初始化4个按钮控制器
    for (int i = 0; i < 4; i++) {
      _btnControllers.add(
        AnimationController(
          vsync: this,
          value: 1.0,
          lowerBound: 0.5,
          upperBound: 1.5,
        ),
      );
    }

    // 背景 shimmer 动画
    _bgShimmerController = AnimationController(
      duration: FluidCurves.shimmerDuration,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    for (final c in _cardControllers) {
      c.dispose();
    }
    for (final c in _btnControllers) {
      c.dispose();
    }
    for (final ripple in _ripples) {
      ripple.controller.dispose();
    }
    _bgShimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr.uiShowcaseTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context.tr.buttonComponents),
            const SizedBox(height: 16),
            _buildButtonShowcase(),
            const SizedBox(height: 32),
            _buildSectionTitle(context.tr.cardComponents),
            const SizedBox(height: 16),
            _buildCardShowcase(),
            const SizedBox(height: 32),
            _buildSectionTitle(context.tr.dialogComponents),
            const SizedBox(height: 16),
            _buildDialogShowcase(),
            const SizedBox(height: 32),
            _buildSectionTitle(context.tr.loadingComponents),
            const SizedBox(height: 16),
            _buildLoadingShowcase(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildButtonShowcase() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        ElevatedButton(onPressed: () {}, child: Text(context.tr.primaryBtn)),
        OutlinedButton(
          onPressed: () {},
          child: Text(context.tr.secondaryBtn),
        ),
        TextButton(onPressed: () {}, child: Text(context.tr.textBtn)),
      ],
    );
  }

  Widget _buildCardShowcase() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: List.generate(3, (index) {
        return Card(
          child: Container(
            width: 200,
            height: 120,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr.cardComponents} ${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.tr.cardComponents} ${index + 1}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDialogShowcase() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(context.tr.dialogTitle),
                content: Text(context.tr.dialogContent),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr.confirm),
                  ),
                ],
              ),
            );
          },
          child: Text(context.tr.showDialogBtn),
        ),
      ],
    );
  }

  Widget _buildLoadingShowcase() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// 涟漪状态
class _RippleState {
  final AnimationController controller;
  final Offset position;

  _RippleState({required this.controller, required this.position});
}
