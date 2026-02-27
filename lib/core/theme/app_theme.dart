import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// Zynk Design System — "Playful Precision" Implementation
class AppTheme {
  // ─────────────────────────────────────────────────────────────────────────
  // THEME FACTORIES
  // ─────────────────────────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppTokens.bgCanvasDark,

      // COLORS
      colorScheme: const ColorScheme.dark(
        primary: AppTokens.brandPrimary,
        secondary: AppTokens.brandSecondary,
        tertiary: AppTokens.brandTertiary,
        surface: AppTokens.bgSurfaceDark,
        error: Colors.redAccent, // Fallback
        onPrimary: Colors.white,
        onSecondary: Colors.black, // Neon Lime needs black text
        onSurface: AppTokens.textPrimaryDark,
        outline: AppTokens.borderSubtleDark,
      ),

      // TYPOGRAPHY
      textTheme: AppTypography.darkTextTheme,

      // COMPONENT THEMES
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTokens.bgCanvasDark,
        foregroundColor: AppTokens.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      cardTheme: const CardThemeData(
        color: AppTokens.bgSurfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.roundedCard,
          side: BorderSide(color: AppTokens.borderSubtleDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: const DividerThemeData(
        color: AppTokens.borderSubtleDark,
        thickness: 1,
      ),

      // INPUTS (Active / Focused states)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.bgSurfaceHighlightDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: AppTokens.roundedCard,
          borderSide: const BorderSide(color: AppTokens.borderSubtleDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTokens.roundedCard,
          borderSide: const BorderSide(color: AppTokens.borderSubtleDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTokens.roundedCard,
          borderSide: const BorderSide(color: AppTokens.borderFocus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppTokens.roundedCard,
          borderSide: const BorderSide(color: AppTokens.brandAccent),
        ),
        hintStyle: const TextStyle(color: AppTokens.textMutedDark),
      ),

      // BUTTONS (Squishy & Bouncy)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.brandPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 52), // Touch Target
          textStyle: AppTypography.darkTextTheme.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: AppTokens.roundedPill,
          ), // Pill Buttons
        ),
      ),

      iconTheme: const IconThemeData(color: AppTokens.textPrimaryDark),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppTokens.bgSurfaceDark,
        selectedItemColor: AppTokens.brandPrimary,
        unselectedItemColor: AppTokens.textMutedDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppTokens.bgCanvasLight,

      // COLORS
      colorScheme: const ColorScheme.light(
        primary: AppTokens.brandPrimary,
        secondary: AppTokens.brandSecondaryLight,
        surface: AppTokens.bgSurfaceLight,
        tertiary: AppTokens.brandTertiary,
        onTertiary: Colors.black87,
        error: Colors.redAccent,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: AppTokens.textPrimaryLight,
        outline: AppTokens.borderSubtleLight,
      ),

      // TYPOGRAPHY
      textTheme: AppTypography.lightTextTheme,

      // COMPONENT THEMES
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTokens.bgCanvasLight,
        foregroundColor: AppTokens.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      cardTheme: const CardThemeData(
        color: AppTokens.bgSurfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.roundedCard,
          side: BorderSide(color: AppTokens.borderSubtleLight, width: 1),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.bgSurfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: AppTokens.roundedCard,
          borderSide: const BorderSide(color: AppTokens.borderSubtleLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTokens.roundedCard,
          borderSide: const BorderSide(color: AppTokens.borderSubtleLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTokens.roundedCard,
          borderSide: const BorderSide(color: AppTokens.brandPrimary, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.brandPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 52),
          textStyle: AppTypography.lightTextTheme.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: AppTokens.roundedPill,
          ),
        ),
      ),
    );
  }
}
