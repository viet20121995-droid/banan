import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Display family: Cormorant Garamond (serif, premium feel).
/// UI family: Inter (sans, neutral, high legibility).
///
/// On web/desktop, prefer self-hosting these in production for performance —
/// we use google_fonts during development for speed of iteration.
class BananTypography {
  const BananTypography._();

  static TextTheme textTheme({required Color ink, required Color inkSoft}) {
    final display = GoogleFonts.cormorantGaramond(color: ink, height: 1.1);
    final body = GoogleFonts.inter(color: ink, height: 1.4);

    return TextTheme(
      displayLarge: display.copyWith(
        fontSize: 56,
        fontWeight: FontWeight.w500,
        letterSpacing: -1,
      ),
      displayMedium: display.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w500,
      ),
      displaySmall: display.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w500,
      ),
      headlineLarge: display.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
      headlineMedium: display.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
      headlineSmall: display.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: body.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: body.copyWith(fontSize: 16),
      bodyMedium: body.copyWith(fontSize: 14),
      bodySmall: body.copyWith(fontSize: 12, color: inkSoft),
      labelLarge: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: body.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: body.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
    );
  }

  static TextTheme light() =>
      textTheme(ink: BananColors.cocoa, inkSoft: BananColors.cocoaSoft);

  static TextTheme dark() =>
      textTheme(ink: BananColors.darkInk, inkSoft: BananColors.darkInkSoft);
}
