import 'package:flutter/material.dart';
import '../utils/color_utils.dart';

/// 词库徽章
///
/// 全部词库统一使用同一枚图标（粉紫 → 天蓝渐变 + 书本），保持词库列表
/// 视觉一致；「（乱序）」词库在右下角加一枚青色洗牌角标以示区分。
///
/// 质感来自三层叠加：双色渐变底 → 顶部受光高光 + 细白描边 → 同色柔光投影，
/// 让它看起来像一枚小 App 图标，而不是灰底上的一枚线性图标。
class WordBookBadge extends StatelessWidget {
  /// 词库名称，仅用于识别是否为乱序词库
  final String name;

  /// 徽章边长
  final double size;

  /// 选中态：光晕与描边更强
  final bool selected;

  const WordBookBadge({
    super.key,
    required this.name,
    this.size = 44,
    this.selected = false,
  });

  /// 统一配色：粉紫 -> 天蓝
  static const List<Color> _gradient = [Color(0xFFF093FB), Color(0xFF4FACFE)];

  /// 乱序角标配色：青色
  static const List<Color> _shuffleGradient = [
    Color(0xFF5AD1C0),
    Color(0xFF35B3A4),
  ];

  bool get _isShuffled =>
      name.contains('乱序') || name.toLowerCase().contains('shuffled');

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.3;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: _gradient[1].withValues(alpha: selected ? 0.40 : 0.26),
            blurRadius: selected ? 16 : 11,
            spreadRadius: selected ? -2 : -3,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        //角标稍微溢出色块，允许越界绘制
        clipBehavior: Clip.none,
        children: [
          //顶部受光高光 + 细描边：让色块像有厚度的玻璃标牌
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: selected ? 0.42 : 0.32),
                    Colors.white.withValues(alpha: 0.05),
                    transparentLike(Colors.white),
                  ],
                  stops: const [0, 0.5, 1],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: selected ? 0.45 : 0.30),
                  width: 0.9,
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.menu_book_rounded,
              size: size * 0.5,
              color: Colors.white,
            ),
          ),
          //乱序词库角标
          if (_isShuffled)
            Positioned(
              right: -size * 0.08,
              bottom: -size * 0.08,
              child: Container(
                padding: EdgeInsets.all(size * 0.08),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _shuffleGradient,
                  ),
                  //白色描边把角标与底色块隔开，避免糊在一起
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.92),
                    width: size * 0.045,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _shuffleGradient[1].withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.shuffle_rounded,
                  size: size * 0.26,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
