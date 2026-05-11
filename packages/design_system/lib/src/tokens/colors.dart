import 'package:flutter/material.dart';

/// Brand palette — luxury patisserie. Soft pastel cream backdrop, deep cocoa
/// for ink, rose primary, gold accent. All values picked for AA contrast on
/// the cream surface (≥ 4.5:1 for body text).
class BananColors {
  const BananColors._();

  // Primary
  static const Color primary = Color(0xFFC9405C);   // rose
  static const Color primaryDark = Color(0xFF9F2D45);
  static const Color primaryLight = Color(0xFFE6839A);

  // Accent
  static const Color gold = Color(0xFFC7A24A);
  static const Color goldLight = Color(0xFFE6CB87);

  // Neutrals — light theme
  static const Color cream = Color(0xFFFAF6F1);     // app background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF3EDE5);
  static const Color cocoa = Color(0xFF3B2A22);     // ink / headlines
  static const Color cocoaSoft = Color(0xFF6B5A52);
  static const Color outline = Color(0xFFE0D7CC);

  // Neutrals — dark theme
  static const Color darkBg = Color(0xFF1A130F);
  static const Color darkSurface = Color(0xFF221814);
  static const Color darkSurfaceDim = Color(0xFF2D2017);
  static const Color darkInk = Color(0xFFF5EFE6);
  static const Color darkInkSoft = Color(0xFFB8AB9C);
  static const Color darkOutline = Color(0xFF3D2D24);

  // Semantic
  static const Color success = Color(0xFF2E7D5B);
  static const Color warning = Color(0xFFD08A1F);
  static const Color danger = Color(0xFFB3261E);
  static const Color info = Color(0xFF3F6FB0);
}
