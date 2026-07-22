import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';

/// Neutral, high-contrast palette for repeated central-kitchen operations.
/// Brand green remains the primary action color; other hues communicate state.
abstract final class KitchenColors {
  static const canvas = Color(0xFFF2F4F3);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF6F8F6);
  static const border = Color(0xFFD5DDD7);
  static const ink = Color(0xFF18211B);
  static const inkMuted = Color(0xFF637068);

  static const primary = Color(0xFF176B3A);
  static const primarySoft = Color(0xFFE2F0E6);
  static const success = Color(0xFF237A46);
  static const warning = Color(0xFFAD6C13);
  static const danger = Color(0xFFB63D3D);
  static const info = Color(0xFF2E68A1);
  static const inProgress = Color(0xFF31758B);
  static const completed = Color(0xFF68756D);

  static const darkCanvas = Color(0xFF111713);
  static const darkSurface = Color(0xFF19211C);
  static const darkSurfaceMuted = Color(0xFF212B24);
  static const darkBorder = Color(0xFF354239);
  static const darkInk = Color(0xFFEDF2EE);
  static const darkInkMuted = Color(0xFFAAB6AD);
}

abstract final class KitchenTheme {
  static ThemeData light() => _build(
        base: BananTheme.light(),
        brightness: Brightness.light,
        canvas: KitchenColors.canvas,
        surface: KitchenColors.surface,
        surfaceMuted: KitchenColors.surfaceMuted,
        border: KitchenColors.border,
        ink: KitchenColors.ink,
        inkMuted: KitchenColors.inkMuted,
        primary: KitchenColors.primary,
        onPrimary: Colors.white,
      );

  static ThemeData dark() => _build(
        base: BananTheme.dark(),
        brightness: Brightness.dark,
        canvas: KitchenColors.darkCanvas,
        surface: KitchenColors.darkSurface,
        surfaceMuted: KitchenColors.darkSurfaceMuted,
        border: KitchenColors.darkBorder,
        ink: KitchenColors.darkInk,
        inkMuted: KitchenColors.darkInkMuted,
        primary: const Color(0xFF72BE87),
        onPrimary: const Color(0xFF08210F),
      );

  static ThemeData _build({
    required ThemeData base,
    required Brightness brightness,
    required Color canvas,
    required Color surface,
    required Color surfaceMuted,
    required Color border,
    required Color ink,
    required Color inkMuted,
    required Color primary,
    required Color onPrimary,
  }) {
    final selection = brightness == Brightness.light
        ? KitchenColors.primarySoft
        : const Color(0xFF254D31);
    final secondaryContainer = brightness == Brightness.light
        ? const Color(0xFFE5EEF6)
        : const Color(0xFF24394C);
    final surfaceHighest = brightness == Brightness.light
        ? const Color(0xFFE9EEEA)
        : const Color(0xFF2B352E);
    final scheme = base.colorScheme.copyWith(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: selection,
      onPrimaryContainer: ink,
      secondary: KitchenColors.info,
      onSecondary: Colors.white,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: ink,
      error: KitchenColors.danger,
      surface: surface,
      onSurface: ink,
      outline: border,
      outlineVariant: border,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surfaceMuted,
      surfaceContainer: surfaceMuted,
      surfaceContainerHigh: surfaceMuted,
      surfaceContainerHighest: surfaceHighest,
      surfaceBright: surface,
      surfaceDim: surfaceMuted,
      surfaceTint: primary,
    );
    final baseText = base.textTheme.apply(bodyColor: ink, displayColor: ink);
    final uiFamily = baseText.bodyMedium?.fontFamily;
    final uiFallback = baseText.bodyMedium?.fontFamilyFallback;
    TextStyle? operationalHeading(TextStyle? style) => style?.copyWith(
          fontFamily: uiFamily,
          fontFamilyFallback: uiFallback,
          letterSpacing: 0,
        );
    final textTheme = baseText.copyWith(
      displayLarge: operationalHeading(baseText.displayLarge),
      displayMedium: operationalHeading(baseText.displayMedium),
      displaySmall: operationalHeading(baseText.displaySmall),
      headlineLarge: operationalHeading(baseText.headlineLarge),
      headlineMedium: operationalHeading(baseText.headlineMedium),
      headlineSmall: operationalHeading(baseText.headlineSmall),
      bodySmall: baseText.bodySmall?.copyWith(color: inkMuted),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BananRadii.rmd,
      borderSide: BorderSide(color: border),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      textTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: surface,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: border,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BananRadii.rmd,
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: surface,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: inkMuted),
        hintStyle: TextStyle(color: inkMuted),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: selection,
        side: BorderSide(color: border),
        shape: const RoundedRectangleBorder(borderRadius: BananRadii.rsm),
        labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w600),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: surface,
          side: BorderSide(color: border),
          shape: const RoundedRectangleBorder(borderRadius: BananRadii.rsm),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: const RoundedRectangleBorder(borderRadius: BananRadii.rsm),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: surface,
        indicatorColor: selection,
      ),
    );
  }
}
