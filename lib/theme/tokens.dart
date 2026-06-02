// MiValta Design Tokens — PLACEHOLDER values, swap for Okapion's final tokens
// in this ONE file during the design pass; screens never change.
//
// Names are semantic (by meaning, not value) so call sites stay stable.
// See docs/THEME_TOKENS_CONTRACT.md for the full contract.
//
// LOCKED tokens (SourceTier colours, F1 copy) stay in their canonical files:
// - lib/theme/source_tier.dart
// - lib/copy/f1.dart

import 'package:flutter/material.dart';

/// Central color tokens. PLACEHOLDER values — swap for Okapion's final tokens.
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
    // TextTheme roles (display = the readiness number/state; body = prose).
    // Placeholder: refine faces/sizes in the design pass (§5.4).
    textTheme: base.textTheme.apply(
      bodyColor: MivaltaColors.textPrimary,
      displayColor: MivaltaColors.textPrimary,
    ),
  );
}
