import 'package:flutter/material.dart';

/// 渐变的"淡出端"安全透明色。
///
/// **不要在 `Gradient.colors` 里写 `Colors.transparent`。**
/// 它是**透明黑**（0x00000000），而渐变插值发生在非预乘空间，于是
/// 「亮色 → 透明黑」的中点会插出灰色：一条 0 → 40px 的白→透明高光，
/// 会在 20px 附近压出比底色更暗的一横（实测暗 11 级）。
/// 在浅色玻璃、亮色面板这类高亮度表面上，就会被看成"组件内部横着一条灰带"，
/// 而且越亮的面越明显。
///
/// 需要淡出时请用同一个颜色把 alpha 降到 0：
///
/// ```dart
/// colors: [accent, transparentLike(accent)],
/// ```
///
/// 注：直接当 widget 颜色用（如 `backgroundColor: Colors.transparent`）
/// 不涉及插值，不受此影响。
Color transparentLike(Color color) => color.withValues(alpha: 0);
