import 'package:flutter/material.dart';

class BananShadows {
  const BananShadows._();

  /// Subtle card lift on cream surface.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Used by floating bars / sticky CTA.
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];
}
