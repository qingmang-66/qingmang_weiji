import 'package:flutter/material.dart';

enum WeaknessLevel { solid, normal, shaky, weak, critical }

extension WeaknessLevelX on WeaknessLevel {
  int get priority => switch (this) {
    WeaknessLevel.solid => 0,
    WeaknessLevel.normal => 1,
    WeaknessLevel.shaky => 2,
    WeaknessLevel.weak => 3,
    WeaknessLevel.critical => 4,
  };

  Color get color => switch (this) {
    WeaknessLevel.critical => const Color(0xFFEF4444),
    WeaknessLevel.weak => const Color(0xFFF59E0B),
    WeaknessLevel.shaky => const Color(0xFF3B82F6),
    WeaknessLevel.normal => const Color(0xFF10B981),
    WeaknessLevel.solid => const Color(0xFF10B981),
  };
}
