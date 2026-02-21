import 'package:flutter/material.dart';

/// Zynk Design Tokens - Source of Truth for Design System v2.0
/// "Playful Precision"
class AppTokens {
  // ─────────────────────────────────────────────────────────────────────────
  // 1. PALETTE (Private Primitives)
  // ─────────────────────────────────────────────────────────────────────────

  // Brand
  static const Color _electricBlue = Color(0xFF2E69FF); // Core Action
  static const Color _neonLime = Color(0xFFD4FC45); // Success / Growth
  static const Color _hotPink = Color(0xFFFF4D8F);
  static const Color _basedGray = Color.fromARGB(255, 212, 208, 229);

  // Neutrals - Cool Blue Tints
  static const Color _midnight = Color(0xFF0D1117); // Canvas Base
  static const Color _surface = Color(0xFF161B22); // Card Base
  static const Color _surfaceHighlight = Color(
    0xFF1C2333,
  ); // Card Hover / Input Fill
  static const Color _borderSubtle = Color(0xFF30363D); // Dividers
  static const Color _textPrimary = Color(0xFFE6EDF3); // Almost White
  static const Color _textMuted = Color(0xFF8B949E); // Muted Grey-Blue

  // Light Mode Equivalents (For future-proofing)
  static const Color _lightCanvas = Color(0xFFFFFFFF);
  static const Color _lightSurface = Color(0xFFF3F4F6);
  static const Color _lightBorder = Color(0xFFE5E7EB);
  static const Color _lightTextPrimary = Color(0xFF111827);

  // ─────────────────────────────────────────────────────────────────────────
  // 2. SEMANTIC COLORS (Public Usage)
  // ─────────────────────────────────────────────────────────────────────────

  static const Color brandPrimary = _electricBlue;
  static const Color brandSecondary = _neonLime;
  static const Color brandTertiary = _basedGray;
  static const Color brandAccent = _hotPink;

  // Backgrounds
  static const Color bgCanvasDark = _midnight;
  static const Color bgSurfaceDark = _surface;
  static const Color bgSurfaceHighlightDark = _surfaceHighlight;

  static const Color bgCanvasLight = _lightCanvas;
  static const Color bgSurfaceLight = _lightSurface;

  // Text
  static const Color textPrimaryDark = _textPrimary;
  static const Color textMutedDark = _textMuted;
  static const Color textPrimaryLight = _lightTextPrimary;

  // Borders
  static const Color borderSubtleDark = _borderSubtle;
  static const Color borderSubtleLight = _lightBorder;
  static const Color borderFocus = _electricBlue;

  // ─────────────────────────────────────────────────────────────────────────
  // 3. SHAPES (Radii)
  // ─────────────────────────────────────────────────────────────────────────

  static const double radiusSoft = 8.0;
  static const double radiusCard = 16.0;
  static const double radiusPill = 100.0;

  static const BorderRadius roundedSoft = BorderRadius.all(
    Radius.circular(radiusSoft),
  );
  static const BorderRadius roundedCard = BorderRadius.all(
    Radius.circular(radiusCard),
  );
  static const BorderRadius roundedPill = BorderRadius.all(
    Radius.circular(radiusPill),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // 4. DEPTH (Shadows & Outlines)
  // ─────────────────────────────────────────────────────────────────────────

  static const List<BoxShadow> shadowGlow = [
    BoxShadow(
      color: Color(0x332E69FF), // brandBlue with ~20% opacity
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowSubtle = [
    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
  ];
}
