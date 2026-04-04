import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLORS — every design token, translated 1-to-1 from the original spec.
// Touch this when branding/palette changes.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppColors {
  static const primary = Color(0xFF006C51);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF57FDC8);
  static const primaryFixedDim = Color(0xFF2CE0AD);

  static const secondary = Color(0xFF006688);
  static const secondaryContainer = Color(0xFFC2E8FF);
  static const onSecondaryContainer = Color(0xFF004D67);
  static const secondaryFixedDim = Color(0xFF75D1FF);

  static const tertiary = Color(0xFF735C00);
  static const tertiaryContainer = Color(0xFFFFE087);
  static const onTertiaryContainer = Color(0xFF574500);

  static const background = Color(0xFFF7FAF9);
  static const onSurface = Color(0xFF181C1C);
  static const onSurfaceVariant = Color(0xFF354C42);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF1F4F3);

  static const outlineVariant = Color(0xFFB3CCBF);
  static const outline = Color(0xFF647C71);
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT STYLES — named styles using Plus Jakarta Sans.
// Touch this when typography changes.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppTextStyles {
  static const _font = GoogleFonts.plusJakartaSans;

  static TextStyle heroDisplay({bool mobile = false}) => _font(
        fontSize: mobile ? 42 : 64,
        fontWeight: FontWeight.w800,
        color: AppColors.onSurface,
        height: 1.05,
        letterSpacing: mobile ? -1.0 : -1.5,
      );

  static TextStyle get sectionHeading => _font(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        color: AppColors.onSurface,
        letterSpacing: -0.5,
      );

  static TextStyle get cardHeading => _font(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
        height: 1.3,
      );

  static TextStyle get bodyLarge => _font(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurfaceVariant,
        height: 1.6,
      );

  static TextStyle get bodyBase => _font(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurfaceVariant,
        height: 1.6,
      );

  static TextStyle get buttonLabel => _font(
        fontSize: 17,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get labelCaps => _font(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      );

  static TextStyle get navBrand => _font(
        fontSize: 21,
        fontWeight: FontWeight.w900,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME — MaterialApp wiring.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primaryContainer,
          secondary: AppColors.secondary,
          secondaryContainer: AppColors.secondaryContainer,
          tertiary: AppColors.tertiary,
          tertiaryContainer: AppColors.tertiaryContainer,
          surface: AppColors.background,
          onSurface: AppColors.onSurface,
          onSurfaceVariant: AppColors.onSurfaceVariant,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      );
}
