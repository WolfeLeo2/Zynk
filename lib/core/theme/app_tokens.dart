import 'package:flutter/material.dart';

/// Zynk Design Tokens - Source of Truth for Design System v2.0
/// "Corporate Minimalism"
class AppTokens {
  // ─────────────────────────────────────────────────────────────────────────
  // 1. PALETTE (Private Primitives)
  // ─────────────────────────────────────────────────────────────────────────

  // Brand (Corporate Minimalism - Professional, Softer)
  static const Color _primaryBlue = Color(0xFF2563EB); // Trustworthy blue
  static const Color _secondaryTeal = Color(
    0xFF0F766E,
  ); // Muted teal for success/growth
  static const Color _secondaryTealLight = Color(
    0xFF0D9488,
  ); // Slightly lighter teal
  static const Color _accentCoral = Color(
    0xFFE11D48,
  ); // Soft red/coral for alerts
  static const Color _slateGray = Color(0xFFCBD5E1); // Neutral tone

  // Neutrals - Slate Tints (Dark Mode)
  static const Color _slate900 = Color(0xFF0F172A); // Canvas Base
  static const Color _slate800 = Color(0xFF1E293B); // Card Base
  static const Color _slate700 = Color(0xFF334155); // Card Hover / Input Fill
  static const Color _slate600 = Color(0xFF475569); // Dividers
  static const Color _slate100 = Color(0xFFF1F5F9); // Text Primary
  static const Color _slate400 = Color(0xFF94A3B8); // Text Muted

  // Neutrals - Slate Tints (Light Mode)
  static const Color _slate50 = Color(
    0xFFF8FAFC,
  ); // Soft Minimal off-white canvas
  static const Color _white = Color(0xFFFFFFFF); // Pure white cards
  static const Color _slate200 = Color(0xFFE2E8F0); // Borders
  static const Color _slate950 = Color(0xFF020617); // Text Primary
  static const Color _slate500 = Color(0xFF64748B); // Text Muted

  // ─────────────────────────────────────────────────────────────────────────
  // 2. SEMANTIC COLORS (Public Usage)
  // ─────────────────────────────────────────────────────────────────────────

  static const Color brandPrimary = _primaryBlue;
  static const Color brandSecondary = _secondaryTealLight;
  static const Color brandSecondaryLight = _secondaryTeal;
  static const Color brandTertiary = _slateGray;
  static const Color brandAccent = _accentCoral;

  // Backgrounds
  static const Color bgCanvasDark = _slate900;
  static const Color bgSurfaceDark = _slate800;
  static const Color bgSurfaceHighlightDark = _slate700;

  static const Color bgCanvasLight = _slate50;
  static const Color bgSurfaceLight = _white;

  static const Color textPrimaryDark = _slate100;
  static const Color textMutedDark = _slate400;
  static const Color textPrimaryLight = _slate950;
  static const Color textMutedLight = _slate500;

  // Borders
  static const Color borderSubtleDark = _slate600;
  static const Color borderSubtleLight = _slate200;
  static const Color borderFocus = _primaryBlue;

  // ─────────────────────────────────────────────────────────────────────────
  // 3. SHAPES (Radii)
  // ─────────────────────────────────────────────────────────────────────────

  static const double radiusSoft = 6.0;
  static const double radiusCard = 12.0;
  static const double radiusButton = 8.0;

  static const BorderRadius roundedSoft = BorderRadius.all(
    Radius.circular(radiusSoft),
  );
  static const BorderRadius roundedCard = BorderRadius.all(
    Radius.circular(radiusCard),
  );
  static const BorderRadius roundedButton = BorderRadius.all(
    Radius.circular(radiusButton),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // 4. DEPTH (Shadows & Outlines)
  // ─────────────────────────────────────────────────────────────────────────

  static const List<BoxShadow> shadowGlow = [
    BoxShadow(
      color: Color(0x1A2563EB), // brandBlue with ~10% opacity
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowSubtle = [
    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // 5. TYPOGRAPHY
  // ─────────────────────────────────────────────────────────────────────────

  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.25,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // 6. ALIASES (Convenience)
  // ─────────────────────────────────────────────────────────────────────────

  static const Color electricBlue =
      _primaryBlue; // Kept alias for compatibility
  static const Color neonLime =
      _secondaryTealLight; // Kept alias for compatibility
  static const Color textPrimary = _slate950;
  static const Color textSecondary = _slate500;
  static const Color textTertiary = _slate400;
  static const Color surfaceSecondary = _slate50;
}
