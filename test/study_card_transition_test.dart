import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingmang_weiji/widgets/study_card_transition.dart';

/// 固定在某个进度与方向上的动画，便于直接验证过渡公式，不依赖 ticker 时序
class _FixedAnimation extends Animation<double> {
  const _FixedAnimation(this._value, this._status);

  final double _value;
  final AnimationStatus _status;

  @override
  void addListener(void Function() listener) {}

  @override
  void removeListener(void Function() listener) {}

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  AnimationStatus get status => _status;

  @override
  double get value => _value;
}

/// 渲染一次并返回过渡中的透明度（子树内只有这一层 Opacity）
Future<double> _opacityAt(
  WidgetTester tester, {
  required double value,
  required AnimationStatus status,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: StudyCardTransition(
        animation: _FixedAnimation(value, status),
        child: const Text('apple'),
      ),
    ),
  );
  return tester.widget<Opacity>(find.byType(Opacity)).opacity;
}

void main() {
  testWidgets('新题入场：可见度随进度上升', (tester) async {
    final start = await _opacityAt(
      tester,
      value: 0.0,
      status: AnimationStatus.forward,
    );
    final early = await _opacityAt(
      tester,
      value: 0.1,
      status: AnimationStatus.forward,
    );
    final end = await _opacityAt(
      tester,
      value: 1.0,
      status: AnimationStatus.forward,
    );

    expect(start, 0.0);
    expect(early, greaterThan(start));
    expect(end, closeTo(1.0, 0.001));
  });

  testWidgets('旧题退场：可见度随进度下降，不会反向残留在屏幕上', (tester) async {
    final start = await _opacityAt(
      tester,
      value: 1.0,
      status: AnimationStatus.reverse,
    );
    final mid = await _opacityAt(
      tester,
      value: 0.7,
      status: AnimationStatus.reverse,
    );
    final end = await _opacityAt(
      tester,
      value: 0.0,
      status: AnimationStatus.reverse,
    );

    expect(start, closeTo(1.0, 0.001));
    expect(mid, lessThan(0.95), reason: '退场一开始就要明显变淡');
    expect(mid, lessThan(start));
    expect(end, closeTo(0.0, 0.001));
  });
}
