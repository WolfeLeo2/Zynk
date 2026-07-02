import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';
import 'app_typography.dart';

/// Zynk Design System — "Corporate Minimalism" Implementation
class AppTheme {
  // ─────────────────────────────────────────────────────────────────────────
  // THEME FACTORIES
  // ─────────────────────────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    final colorScheme = const ColorScheme.dark(
      primary: AppTokens.brandPrimary,
      secondary: AppTokens.brandSecondary,
      tertiary: AppTokens.brandTertiary,
      surface: AppTokens.bgSurfaceDark,
      error: Colors.redAccent, // Fallback
      onPrimary: Colors.white,
      onSecondary: Colors.white, // Teal needs white text
      onSurface: AppTokens.textPrimaryDark,
      outline: AppTokens.borderSubtleDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppTokens.bgCanvasDark,

      // COLORS
      colorScheme: colorScheme,

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
          side: BorderSide(color: AppTokens.borderSubtleDark, width: 0.75),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: const DividerThemeData(
        color: AppTokens.borderSubtleDark,
        thickness: 0.5,
      ),

      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.roundedCard,
          side: BorderSide(color: AppTokens.borderSubtleDark, width: 0.5),
        ),
      ),

      chipTheme: const ChipThemeData(
        side: BorderSide(color: AppTokens.borderSubtleDark, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: AppTokens.roundedButton),
      ),

      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
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
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTokens.roundedCard,
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTokens.roundedCard,
          borderSide: const BorderSide(
            color: AppTokens.brandPrimary,
            width: 1.5,
          ),
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
            borderRadius: AppTokens.roundedButton,
          ), // Rounded Rect Buttons
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
    final colorScheme = const ColorScheme.light(
      primary: AppTokens.brandPrimary,
      secondary: AppTokens.brandSecondaryLight,
      surface: AppTokens.bgSurfaceLight,
      tertiary: AppTokens.brandTertiary,
      onTertiary: Colors.black87,
      error: Colors.redAccent,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppTokens.textPrimaryLight,
      outline: AppTokens.borderSubtleLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppTokens.bgCanvasLight,

      // COLORS
      colorScheme: colorScheme,

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
        elevation: 0, // Very soft minimal
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.roundedCard,
          side: BorderSide(color: AppTokens.borderSubtleLight, width: 0.75),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppTokens.borderSubtleLight,
        thickness: 0.5,
      ),

      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.roundedCard,
          side: BorderSide(color: AppTokens.borderSubtleLight, width: 0.5),
        ),
      ),

      chipTheme: const ChipThemeData(
        side: BorderSide(color: AppTokens.borderSubtleLight, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: AppTokens.roundedButton),
      ),

      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
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
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTokens.roundedCard,
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTokens.roundedCard,
          borderSide: const BorderSide(
            color: AppTokens.brandPrimary,
            width: 1.5,
          ),
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
            borderRadius: AppTokens.roundedButton,
          ),
        ),
      ),
    );
  }
}
