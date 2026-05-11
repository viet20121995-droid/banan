import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radii.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Builds the Material 3 [ThemeData] for both light and dark modes from the
/// brand tokens. All apps consume this — no theme drift across surfaces.
class BananTheme {
  const BananTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: BananColors.primary,
      primary: BananColors.primary,
      onPrimary: Colors.white,
      secondary: BananColors.gold,
      onSecondary: BananColors.cocoa,
      surface: BananColors.surface,
      onSurface: BananColors.cocoa,
      error: BananColors.danger,
      brightness: Brightness.light,
    );

    return _build(
      colorScheme: colorScheme,
      scaffoldBackground: BananColors.cream,
      surfaceDim: BananColors.surfaceDim,
      ink: BananColors.cocoa,
      inkSoft: BananColors.cocoaSoft,
      outline: BananColors.outline,
      textTheme: BananTypography.light(),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: BananColors.primary,
      primary: BananColors.primaryLight,
      onPrimary: BananColors.cocoa,
      secondary: BananColors.goldLight,
      onSecondary: BananColors.darkBg,
      surface: BananColors.darkSurface,
      onSurface: BananColors.darkInk,
      error: BananColors.danger,
      brightness: Brightness.dark,
    );

    return _build(
      colorScheme: colorScheme,
      scaffoldBackground: BananColors.darkBg,
      surfaceDim: BananColors.darkSurfaceDim,
      ink: BananColors.darkInk,
      inkSoft: BananColors.darkInkSoft,
      outline: BananColors.darkOutline,
      textTheme: BananTypography.dark(),
    );
  }

  static ThemeData _build({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color surfaceDim,
    required Color ink,
    required Color inkSoft,
    required Color outline,
    required TextTheme textTheme,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: ink,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BananRadii.rlg,
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDim,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BananSpacing.lg,
          vertical: BananSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BananRadii.rmd,
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BananRadii.rmd,
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BananRadii.rmd,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BananRadii.rmd,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: inkSoft),
        hintStyle: textTheme.bodyMedium?.copyWith(color: inkSoft),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: BananSpacing.xl,
            vertical: BananSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: BananRadii.rmd),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(
            horizontal: BananSpacing.xl,
            vertical: BananSpacing.md,
          ),
          side: BorderSide(color: outline),
          shape: const RoundedRectangleBorder(borderRadius: BananRadii.rmd),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: ink),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
    );
  }
}
