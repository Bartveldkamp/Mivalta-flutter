// MiValta Design Tokens — exact values from mivalta-design/tokens/*.css
//
// Names are semantic (by meaning, not value) so call sites stay stable.
// See docs/THEME_TOKENS_CONTRACT.md for the full contract.
//
// LOCKED tokens (SourceTier colours, F1 copy) stay in their canonical files:
// - lib/theme/source_tier.dart
// - lib/copy/f1.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central color tokens — exact values from tokens/colors.css.
abstract final class MivaltaColors {
  // Surfaces — dark-first, four luminance levels (§5.3).
  static const surfaceBackground = Color(0xFF0B0B0D); // --surface-background
  static const surface1 = Color(0xFF141417);          // --surface-1
  static const surface2 = Color(0xFF1E1E22);          // --surface-2
  static const overlay = Color(0xFF26262B);           // --surface-overlay

  // On-surface text (white at three opacities).
  static const textPrimary = Color(0xFFFFFFFF);       // --text-primary
  static const textSecondary = Color(0xB3FFFFFF);     // --text-secondary (70%)
  static const textMuted = Color(0x80FFFFFF);         // --text-muted (50%)

  // Viterbi state palette — the intensity ramp. Muted at the alarm end (§5.2).
  static const stateRecovered = Color(0xFF7FE3B0);    // --state-recovered
  static const stateProductive = Color(0xFF00C6A7);   // --state-productive
  static const stateAccumulated = Color(0xFFE8C547);  // --state-accumulated
  static const stateOverreached = Color(0xFFCE7B5A);  // --state-overreached
  static const stateIllnessRisk = Color(0xFFB85C63);  // --state-illness-risk

  // Readiness level band (engine decides; UI renders the colour).
  static const levelGreen = Color(0xFF2BD974);        // --level-green
  static const levelYellow = Color(0xFFE8C547);       // --level-yellow
  static const levelOrange = Color(0xFFE6872F);       // --level-orange
  static const levelRed = Color(0xFFE5484D);          // --level-red

  // Okapion brand anchors (§5.1).
  static const primaryGreen = Color(0xFF1DBF60);      // --brand-green
  static const tertiaryTeal = Color(0x6120B7BA);      // --brand-teal (38%)
  static const tertiaryTealSolid = Color(0xFF20B7BA); // --brand-teal-solid
  static const cautionYellow = Color(0xFFFFCE2E);     // --brand-caution
  static const glassFocusTeal = Color(0xFF007166);    // --brand-glass-teal

  // Card styling (from Today-Modular.html).
  static const cardBackground = Color(0x08FFFFFF);    // rgba(255,255,255,.03)
  static const cardBorder = Color(0x14FFFFFF);        // rgba(255,255,255,.08)
}

/// Typography tokens — exact values from tokens/typography.css.
///
/// REAL BRAND TYPE SYSTEM (Okapion "MIV — Library" Figma, confirmed 2026-06-29):
///   fontBrand   = **Zen Dots** — wordmark / hero brand display ONLY.
///   fontDisplay = **Inter**    — state word, screen titles, big numbers.
///   fontBody    = **Inter**    — prose, UI, Josi.
/// Inter is the single working face for display + body; weight, size and
/// tracking create the hierarchy. Zen Dots is a brand accent, never body.
/// Numbers use tabular figures so compared data lines up.
abstract final class MivaltaTypography {
  // Font families
  static const fontBrand = 'Zen Dots';   // --font-brand (hero brand display)
  static const fontDisplay = 'Inter';    // --font-display (state word, titles)
  static const fontBody = 'Inter';       // --font-body (prose, UI, Josi)
  static const fontMono = 'SF Mono';     // --font-mono

  // Font weights
  static const weightRegular = FontWeight.w400;
  static const weightMedium = FontWeight.w500;
  static const weightSemibold = FontWeight.w600;
  static const weightBold = FontWeight.w700;

  // Type scale (px → double). Mobile-first; hero is the largest.
  static const sizeHero = 88.0;          // --text-hero (readiness number)
  static const sizeDisplay = 40.0;       // --text-display (state word, titles)
  static const sizeTitleLg = 24.0;       // --text-title-lg
  static const sizeTitle = 20.0;         // --text-title (card titles)
  static const sizeBodyLg = 17.0;        // --text-body-lg
  static const sizeBody = 15.0;          // --text-body (prose / Josi)
  static const sizeSmall = 13.0;         // --text-small (captions)
  static const sizeLabel = 11.0;         // --text-label (ALL-CAPS eyebrows)

  // Line heights
  static const leadingTight = 1.05;      // --leading-tight (hero number)
  static const leadingSnug = 1.2;        // --leading-snug (titles)
  static const leadingNormal = 1.5;      // --leading-normal (prose)

  // Letter spacing
  static const trackingEyebrow = 1.2;    // --tracking-eyebrow (ALL-CAPS)
  static const trackingTight = -0.02;    // --tracking-tight (hero/display)
  static const trackingNormal = 0.0;     // --tracking-normal
}

/// Spacing scale tokens — exact values from tokens/spacing.css.
abstract final class MivaltaSpace {
  static const x1 = 4.0;   // --space-1
  static const x2 = 8.0;   // --space-2
  static const x3 = 12.0;  // --space-3
  static const x4 = 16.0;  // --space-4
  static const x5 = 24.0;  // --space-5
  static const x6 = 32.0;  // --space-6
}

/// Border radius tokens — exact values from tokens/spacing.css.
abstract final class MivaltaRadii {
  static const sm = 8.0;    // --radius-sm (chips, swatches)
  static const md = 12.0;   // --radius-md (cards)
  static const lg = 20.0;   // --radius-lg (pill badges, sheets)
  static const pill = 999.0; // --radius-pill
  static const card = 15.0; // card border-radius from Today-Modular.html
}

/// Border tokens.
abstract final class MivaltaBorders {
  static const width = 1.0;     // --border-width
  static const widthLead = 1.5; // --border-width-lead (lead card emphasis)
}

/// Glass effect tokens (§15.5: ONE surface (Josi), never nested, never animated).
abstract final class MivaltaGlass {
  static const blurSigma = 18.0;            // --glass-blur
  static const fallbackOpacity = 0.86;
  static const fillColor = Color(0x8C1E1E22); // --glass-fill (~55% surface-2)
  static const fillFallback = Color(0xEB141417); // --glass-fill-fallback
  static const borderColor = Color(0x14FFFFFF); // --glass-border (8%)
}

/// Motion duration tokens — exact values from tokens/spacing.css.
abstract final class MivaltaMotion {
  static const fast = Duration(milliseconds: 150);    // --motion-fast
  static const standard = Duration(milliseconds: 280); // --motion-standard
}

/// Text style helpers using Google Fonts (Zen Dots + Inter).
/// These are the canonical way to create styled text in the design system.
abstract final class MivaltaTextStyles {
  /// Hero number style (Zen Dots, 88px). The readiness score.
  static TextStyle heroNumber({Color? color}) => GoogleFonts.zenDots(
    fontSize: MivaltaTypography.sizeHero,
    fontWeight: MivaltaTypography.weightMedium,
    height: MivaltaTypography.leadingTight,
    letterSpacing: MivaltaTypography.sizeHero * MivaltaTypography.trackingTight,
    color: color ?? MivaltaColors.textPrimary,
  );

  /// State word style (Inter, display size). "Productive", "Recovered", etc.
  static TextStyle stateWord({Color? color}) => GoogleFonts.inter(
    fontSize: 14.0, // per Today-Modular.html .glow .word
    fontWeight: MivaltaTypography.weightSemibold,
    color: color ?? MivaltaColors.stateProductive,
  );

  /// App bar title style (Inter, 24px bold).
  static TextStyle appBarTitle({Color? color}) => GoogleFonts.inter(
    fontSize: MivaltaTypography.sizeTitleLg,
    fontWeight: MivaltaTypography.weightBold,
    letterSpacing: MivaltaTypography.sizeTitleLg * MivaltaTypography.trackingTight,
    color: color ?? MivaltaColors.textPrimary,
  );

  /// Card header style (Inter, 10px ALL-CAPS).
  static TextStyle cardHeader({Color? color}) => GoogleFonts.inter(
    fontSize: 10.0,
    fontWeight: MivaltaTypography.weightBold,
    letterSpacing: 0.7,
    color: color ?? MivaltaColors.textMuted,
  );

  /// Section eyebrow style (Inter, 11px ALL-CAPS with wide tracking).
  static TextStyle eyebrow({Color? color}) => GoogleFonts.inter(
    fontSize: MivaltaTypography.sizeLabel,
    fontWeight: MivaltaTypography.weightBold,
    letterSpacing: MivaltaTypography.trackingEyebrow,
    color: color ?? MivaltaColors.textMuted,
  );

  /// Body text style (Inter, 15px).
  static TextStyle body({Color? color, FontWeight? weight}) => GoogleFonts.inter(
    fontSize: MivaltaTypography.sizeBody,
    fontWeight: weight ?? MivaltaTypography.weightRegular,
    height: MivaltaTypography.leadingNormal,
    color: color ?? MivaltaColors.textPrimary,
  );

  /// Small text style (Inter, 13px).
  static TextStyle small({Color? color}) => GoogleFonts.inter(
    fontSize: MivaltaTypography.sizeSmall,
    fontWeight: MivaltaTypography.weightRegular,
    height: MivaltaTypography.leadingNormal,
    color: color ?? MivaltaColors.textSecondary,
  );

  /// Metric value style (Inter, 19px semibold). Numbers on cards.
  static TextStyle metricValue({Color? color}) => GoogleFonts.inter(
    fontSize: 19.0,
    fontWeight: MivaltaTypography.weightSemibold,
    color: color ?? MivaltaColors.textPrimary,
  );

  /// Metric unit style (Inter, 11px muted). "min", "W", etc.
  static TextStyle metricUnit({Color? color}) => GoogleFonts.inter(
    fontSize: 11.0,
    fontWeight: MivaltaTypography.weightRegular,
    color: color ?? MivaltaColors.textMuted,
  );

  /// Josi line style (Inter, 15px). The Josi prose.
  static TextStyle josiLine({Color? color}) => GoogleFonts.inter(
    fontSize: MivaltaTypography.sizeBody,
    fontWeight: MivaltaTypography.weightRegular,
    height: 1.45,
    color: color ?? MivaltaColors.textPrimary,
  );

  /// Josi emphasis style (Inter, 15px semibold green). Bold parts of Josi line.
  static TextStyle josiEmphasis() => GoogleFonts.inter(
    fontSize: MivaltaTypography.sizeBody,
    fontWeight: MivaltaTypography.weightSemibold,
    height: 1.45,
    color: MivaltaColors.stateRecovered, // #7FE3B0
  );

  /// Edit button style (Inter, 12px semibold green).
  static TextStyle editButton() => GoogleFonts.inter(
    fontSize: 12.0,
    fontWeight: MivaltaTypography.weightSemibold,
    color: MivaltaColors.stateRecovered, // #7FE3B0
  );
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

  // Text theme using exact design tokens.
  final textTheme = TextTheme(
    // Display styles (state word, screen titles)
    displayLarge: const TextStyle(
      fontFamily: MivaltaTypography.fontDisplay,
      fontSize: MivaltaTypography.sizeDisplay,
      fontWeight: MivaltaTypography.weightBold,
      height: MivaltaTypography.leadingSnug,
      letterSpacing: MivaltaTypography.sizeDisplay * MivaltaTypography.trackingTight,
      color: MivaltaColors.textPrimary,
    ),
    displayMedium: const TextStyle(
      fontFamily: MivaltaTypography.fontDisplay,
      fontSize: MivaltaTypography.sizeTitleLg,
      fontWeight: MivaltaTypography.weightBold,
      height: MivaltaTypography.leadingSnug,
      letterSpacing: MivaltaTypography.sizeTitleLg * MivaltaTypography.trackingTight,
      color: MivaltaColors.textPrimary,
    ),
    // Title styles
    titleLarge: const TextStyle(
      fontFamily: MivaltaTypography.fontDisplay,
      fontSize: MivaltaTypography.sizeTitleLg,
      fontWeight: MivaltaTypography.weightBold,
      height: MivaltaTypography.leadingSnug,
      color: MivaltaColors.textPrimary,
    ),
    titleMedium: const TextStyle(
      fontFamily: MivaltaTypography.fontDisplay,
      fontSize: MivaltaTypography.sizeTitle,
      fontWeight: MivaltaTypography.weightSemibold,
      height: MivaltaTypography.leadingSnug,
      color: MivaltaColors.textPrimary,
    ),
    titleSmall: const TextStyle(
      fontFamily: MivaltaTypography.fontDisplay,
      fontSize: MivaltaTypography.sizeBodyLg,
      fontWeight: MivaltaTypography.weightSemibold,
      height: MivaltaTypography.leadingSnug,
      color: MivaltaColors.textPrimary,
    ),
    // Body styles (prose, Josi)
    bodyLarge: const TextStyle(
      fontFamily: MivaltaTypography.fontBody,
      fontSize: MivaltaTypography.sizeBodyLg,
      fontWeight: MivaltaTypography.weightRegular,
      height: MivaltaTypography.leadingNormal,
      color: MivaltaColors.textPrimary,
    ),
    bodyMedium: const TextStyle(
      fontFamily: MivaltaTypography.fontBody,
      fontSize: MivaltaTypography.sizeBody,
      fontWeight: MivaltaTypography.weightRegular,
      height: MivaltaTypography.leadingNormal,
      color: MivaltaColors.textPrimary,
    ),
    bodySmall: const TextStyle(
      fontFamily: MivaltaTypography.fontBody,
      fontSize: MivaltaTypography.sizeSmall,
      fontWeight: MivaltaTypography.weightRegular,
      height: MivaltaTypography.leadingNormal,
      color: MivaltaColors.textSecondary,
    ),
    // Label styles (ALL-CAPS eyebrows, chips)
    labelLarge: const TextStyle(
      fontFamily: MivaltaTypography.fontBody,
      fontSize: MivaltaTypography.sizeSmall,
      fontWeight: MivaltaTypography.weightSemibold,
      height: MivaltaTypography.leadingSnug,
      color: MivaltaColors.textPrimary,
    ),
    labelMedium: const TextStyle(
      fontFamily: MivaltaTypography.fontBody,
      fontSize: MivaltaTypography.sizeLabel,
      fontWeight: MivaltaTypography.weightBold,
      letterSpacing: MivaltaTypography.trackingEyebrow,
      height: MivaltaTypography.leadingSnug,
      color: MivaltaColors.textMuted,
    ),
    labelSmall: const TextStyle(
      fontFamily: MivaltaTypography.fontBody,
      fontSize: 10.0,
      fontWeight: MivaltaTypography.weightBold,
      letterSpacing: 0.7,
      height: MivaltaTypography.leadingSnug,
      color: MivaltaColors.textMuted,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: MivaltaColors.surfaceBackground,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: MivaltaColors.surfaceBackground,
      foregroundColor: MivaltaColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: MivaltaTypography.fontDisplay,
        fontSize: MivaltaTypography.sizeTitleLg,
        fontWeight: MivaltaTypography.weightBold,
        letterSpacing: MivaltaTypography.sizeTitleLg * MivaltaTypography.trackingTight,
        color: MivaltaColors.textPrimary,
      ),
    ),
  );
}
