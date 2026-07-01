// MiValta Design Tokens — SOURCE OF TRUTH for the app's visual system.
// Screens/widgets read these by name; they never hard-code colours/type/space.
// Okapion's Figma is a DONOR (values were lifted from it), not a live authority.
// LOCKED tokens stay in their canonical files: lib/theme/source_tier.dart, lib/copy/f1.dart.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central color tokens.
abstract final class MivaltaColors {
  // Surfaces — dark-first, four luminance levels (UI_UX §5.3).
  static const surfaceBackground = Color(0xFF0B0B0D);
  static const surface1 = Color(0xFF141417);
  static const surface2 = Color(0xFF1E1E22);
  static const overlay = Color(0xFF26262B);

  // On-surface text.
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xB3FFFFFF); // 70%
  static const textMuted = Color(0x80FFFFFF);     // 50%

  // Viterbi state palette — muted at the alarm end (UI_UX §5.2).
  static const stateRecovered = Color(0xFF7FE3B0);
  static const stateProductive = Color(0xFF00C6A7);
  static const stateAccumulated = Color(0xFFE8C547);
  static const stateOverreached = Color(0xFFCE7B5A);
  static const stateIllnessRisk = Color(0xFFB85C63);

  // Readiness level (engine decides the level; UI only renders the colour).
  static const levelGreen = Color(0xFF2BD974);
  static const levelYellow = Color(0xFFE8C547);
  static const levelOrange = Color(0xFFE6872F);
  static const levelRed = Color(0xFFE5484D);

  // Okapion brand anchors (UI_UX §5.1).
  static const primaryGreen = Color(0xFF1DBF60);
  static const tertiaryTeal = Color(0x6120B7BA); // rgba(32,183,186,0.38)
  static const cautionYellow = Color(0xFFFFCE2E);
  static const glassFocusTeal = Color(0xFF007166);
}

/// Typography tokens. Faces: Inter (main), Zen Dots (brand wordmark only).
/// All numeric displays use tabular + lining figures for alignment.
abstract final class MivaltaType {
  // Font feature tags for numeric alignment.
  static const _tabularLining = [
    FontFeature.tabularFigures(),
    FontFeature.liningFigures(),
  ];

  /// Hero readiness number — 88px Inter w400.
  static TextStyle get hero => GoogleFonts.inter(
        fontSize: 88,
        fontWeight: FontWeight.w400,
        height: 1.05,
        letterSpacing: -1.76,
        fontFeatures: _tabularLining,
      );

  /// Display headlines — 40px Inter w600.
  static TextStyle get display => GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        height: 1.05,
        letterSpacing: -0.80,
        fontFeatures: _tabularLining,
      );

  /// Large title — 24px Inter w700.
  static TextStyle get titleL => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.20,
        letterSpacing: 0,
        fontFeatures: _tabularLining,
      );

  /// Medium title / state word — 20px Inter w600. Colour applied by caller.
  static TextStyle get titleM => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.20,
        letterSpacing: 0,
        fontFeatures: _tabularLining,
      );

  /// Large body — 17px Inter w400.
  static TextStyle get bodyL => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.50,
        letterSpacing: 0,
        fontFeatures: _tabularLining,
      );

  /// Default prose / Josi voice — 15px Inter w400.
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.50,
        letterSpacing: 0,
        fontFeatures: _tabularLining,
      );

  /// Card titles (Today module cards) — 13px Inter w600.
  static TextStyle get cardTitle => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.30,
        letterSpacing: 0,
        fontFeatures: _tabularLining,
      );

  /// Captions / metric labels — 13px Inter w500.
  static TextStyle get small => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.40,
        letterSpacing: 0,
        fontFeatures: _tabularLining,
      );

  /// Section eyebrows — 11px Inter w700, uppercase applied at call site.
  static TextStyle get label => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.20,
        letterSpacing: 1.2,
        fontFeatures: _tabularLining,
      );

  /// Brand wordmark — Zen Dots. Use sparingly (hero brand only).
  static TextStyle brandWordmark({double fontSize = 24}) => GoogleFonts.zenDots(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
      );
}

/// StateField glow composition constants — lifted from design component.
/// The field colour comes from fatigueStateColor(state).
// composition constants defined; exact Flutter blur/gradient render is
// DR-verified, not guaranteed pixel-equal to CSS.
abstract final class MivaltaGlow {
  // Field geometry — DR-005: increased from 240 to 280 for fuller breathing field.
  static const fieldSize = 280.0;
  static const calibratingScale = 0.62;

  // Outer halo: scale 1.30, alpha 0.26, blur sigma 14, gradient stop 66%.
  static const outerScale = 1.30;
  static const outerAlpha = 0.26;
  static const outerBlur = 14.0;
  static const outerStop = 0.66;

  // Mid halo: scale 0.92, alpha 0.40, blur sigma 8, gradient stop 66%.
  static const midScale = 0.92;
  static const midAlpha = 0.40;
  static const midBlur = 8.0;
  static const midStop = 0.66;

  // Inner halo: scale 0.50, alpha 0.64, blur sigma 3, gradient stop 72%.
  static const innerScale = 0.50;
  static const innerAlpha = 0.64;
  static const innerBlur = 3.0;
  static const innerStop = 0.72;

  // Typography gap between number and state word.
  static const wordGap = 8.0;

  // Breathe animation: 7 seconds with standard ease.
  static const breatheDuration = Duration(seconds: 7);
  static const breatheCurve = Curves.ease;
}

/// Spacing scale tokens.
abstract final class MivaltaSpace {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 24.0;
  static const x6 = 32.0;
}

/// Border radius tokens.
abstract final class MivaltaRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 20.0;
}

/// Glass effect tokens (§15.5: ONE surface (Josi), never nested, never animated).
abstract final class MivaltaGlass {
  static const blurSigma = 18.0;
  static const fallbackOpacity = 0.86;
}

/// Motion duration tokens.
abstract final class MivaltaMotion {
  static const fast = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 280);
}

/// Map an engine readiness level string → the token colour. The engine DECIDES
/// the level; this only renders it (no thresholds in Dart).
Color readinessLevelColor(String? level) =>
    switch ((level ?? '').toLowerCase()) {
      'green' => MivaltaColors.levelGreen,
      'yellow' => MivaltaColors.levelYellow,
      'orange' => MivaltaColors.levelOrange,
      'red' => MivaltaColors.levelRed,
      _ => MivaltaColors.textMuted,
    };

/// The ONE canonical zone → colour map (audit #8). Zone *colour* is the Viterbi
/// state-scale palette used as an intensity ramp (recovered → illness) — it is
/// NOT a separate energy-system palette. The energy system is the *label* (see
/// copy/zone_labels.dart, e.g. "VO₂max / aerobic power"); the colour is the
/// state scale. Engine decides the zone; Dart only renders its colour. Every
/// zone-colour call site (advisor screen, time-in-zone chart) routes here so the
/// screens can never diverge. Unknown/empty → muted (never a raw code).
Color zoneColor(String? zone) =>
    switch ((zone ?? '').trim().toUpperCase()) {
      'R' || 'Z1' => MivaltaColors.stateRecovered,
      'Z2' => MivaltaColors.stateProductive,
      'Z3' => MivaltaColors.stateAccumulated,
      'Z4' || 'Z5' => MivaltaColors.stateOverreached,
      'Z6' || 'Z7' || 'Z8' => MivaltaColors.stateIllnessRisk,
      _ => MivaltaColors.textMuted,
    };

/// Map an engine Viterbi state string → its palette colour.
Color fatigueStateColor(String? state) =>
    switch ((state ?? '').toLowerCase()) {
      'recovered' => MivaltaColors.stateRecovered,
      'productive' => MivaltaColors.stateProductive,
      'accumulated' => MivaltaColors.stateAccumulated,
      'overreached' => MivaltaColors.stateOverreached,
      'illnessrisk' => MivaltaColors.stateIllnessRisk,
      _ => MivaltaColors.textMuted,
    };

/// The app's dark-first ThemeData, built from tokens. Screens read
/// Theme.of(context); they never hard-code colours/type.
ThemeData mivaltaDarkTheme() {
  const scheme = ColorScheme.dark(
    surface: MivaltaColors.surfaceBackground,
    primary: MivaltaColors.primaryGreen,
    secondary: MivaltaColors.tertiaryTeal,
    error: MivaltaColors.levelRed,
    onSurface: MivaltaColors.textPrimary,
  );
  final base = ThemeData.from(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: MivaltaColors.surfaceBackground,
    textTheme: base.textTheme.copyWith(
      displayLarge: MivaltaType.hero,
      displayMedium: MivaltaType.display,
      headlineLarge: MivaltaType.titleL,
      headlineMedium: MivaltaType.titleM,
      bodyLarge: MivaltaType.bodyL,
      bodyMedium: MivaltaType.body,
      labelLarge: MivaltaType.cardTitle,
      labelMedium: MivaltaType.small,
      labelSmall: MivaltaType.label,
    ),
  );
}
