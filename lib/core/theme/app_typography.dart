import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_tokens.dart';

/// Zynk Typography System
/// Headings: Clash Display (Variable)
/// Body: Outfit (Geometric)
class AppTypography {
  static TextTheme get darkTextTheme => _buildTextTheme(Colors.white);
  static TextTheme get lightTextTheme =>
      _buildTextTheme(AppTokens.textPrimaryLight);

  static TextTheme _buildTextTheme(Color baseColor) {
    // We start with Outfit as the base for everything
    final baseTheme = GoogleFonts.outfitTextTheme().apply(
      displayColor: baseColor,
      bodyColor: baseColor,
    );

    return baseTheme.copyWith(
      // DISPLAY (Clash Display)
      displayLarge: _clashDisplay(
        //fontSize: 57,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      displayMedium: _clashDisplay(
        //fontSize: 45,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      displaySmall: _clashDisplay(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),

      // HEADLINES (Clash Display)
      headlineLarge: _clashDisplay(
        //fontSize: 32,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineMedium: _clashDisplay(
        //fontSize: 28,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineSmall: _clashDisplay(
        //fontSize: 24,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),

      // TITLES (Outfit - Geometric, readable)
      titleLarge: GoogleFonts.outfit(
        //fontSize: 22,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleMedium: GoogleFonts.outfit(
        //fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: baseColor,
      ),
      titleSmall: GoogleFonts.outfit(
        //fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: baseColor,
      ),

      // BODY (Outfit)
      bodyLarge: GoogleFonts.outfit(
        //fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: baseColor,
      ),
      bodyMedium: GoogleFonts.outfit(
        //fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: baseColor,
      ),
      bodySmall: GoogleFonts.outfit(
        //fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: baseColor.withValues(alpha: 0.7),
      ),

      // LABELS (Outfit - UI Elements)
      labelLarge: GoogleFonts.outfit(
        //fontSize: 14,
        fontWeight: FontWeight.w600, // Important for buttons
        letterSpacing: 0.1,
        color: baseColor,
      ),
      labelMedium: GoogleFonts.outfit(
        //fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: baseColor,
      ),
      labelSmall: GoogleFonts.outfit(
        //fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: baseColor,
      ),
    );
  }

  // Helper for Custom Font Assets
  static TextStyle _clashDisplay({
    double? fontSize,
    required FontWeight fontWeight,
    required Color color,
  }) {
    return TextStyle(
      fontFamily: 'ClashDisplay',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      // Ensure height is not wacky for custom fonts
      height: 1.1,
    );
  }
}