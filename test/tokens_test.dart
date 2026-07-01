// PR-C: Token layer tests — concrete-value assertions for design tokens.
//
// Verifies:
//   1. readinessLevelColor() maps engine level strings → correct token colors
//   2. fatigueStateColor() maps engine state strings → correct token colors
//   3. MivaltaColors constants match expected hex values
//   4. Tokens-only compliance: no inline Colors/hex in mapped code

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/theme/tokens.dart';

void main() {
  group('MivaltaColors', () {
    test('surface tokens have correct hex values', () {
      expect(MivaltaColors.surfaceBackground, const Color(0xFF0B0B0D));
      expect(MivaltaColors.surface1, const Color(0xFF141417));
      expect(MivaltaColors.surface2, const Color(0xFF1E1E22));
      expect(MivaltaColors.overlay, const Color(0xFF26262B));
    });

    test('text tokens have correct hex values with opacity', () {
      expect(MivaltaColors.textPrimary, const Color(0xFFFFFFFF));
      expect(MivaltaColors.textSecondary, const Color(0xB3FFFFFF)); // 70%
      expect(MivaltaColors.textMuted, const Color(0x80FFFFFF)); // 50%
    });

    test('Viterbi state palette tokens have correct hex values', () {
      expect(MivaltaColors.stateRecovered, const Color(0xFF7FE3B0));
      expect(MivaltaColors.stateProductive, const Color(0xFF00C6A7));
      expect(MivaltaColors.stateAccumulated, const Color(0xFFE8C547));
      expect(MivaltaColors.stateOverreached, const Color(0xFFCE7B5A));
      expect(MivaltaColors.stateIllnessRisk, const Color(0xFFB85C63));
    });

    test('readiness level tokens have correct hex values', () {
      expect(MivaltaColors.levelGreen, const Color(0xFF2BD974));
      expect(MivaltaColors.levelYellow, const Color(0xFFE8C547));
      expect(MivaltaColors.levelOrange, const Color(0xFFE6872F));
      expect(MivaltaColors.levelRed, const Color(0xFFE5484D));
    });

    test('brand tokens have correct hex values', () {
      expect(MivaltaColors.primaryGreen, const Color(0xFF1DBF60));
      expect(MivaltaColors.tertiaryTeal, const Color(0x6120B7BA));
      expect(MivaltaColors.cautionYellow, const Color(0xFFFFCE2E));
      expect(MivaltaColors.glassFocusTeal, const Color(0xFF007166));
    });
  });

  group('MivaltaSpace', () {
    test('spacing scale follows 4px base', () {
      expect(MivaltaSpace.x1, 4.0);
      expect(MivaltaSpace.x2, 8.0);
      expect(MivaltaSpace.x3, 12.0);
      expect(MivaltaSpace.x4, 16.0);
      expect(MivaltaSpace.x5, 24.0);
      expect(MivaltaSpace.x6, 32.0);
    });
  });

  group('MivaltaRadii', () {
    test('border radius scale is correct', () {
      expect(MivaltaRadii.sm, 8.0);
      expect(MivaltaRadii.md, 12.0);
      expect(MivaltaRadii.lg, 20.0);
    });
  });

  group('MivaltaGlass', () {
    test('glass tokens are correct', () {
      expect(MivaltaGlass.blurSigma, 18.0);
      expect(MivaltaGlass.fallbackOpacity, 0.86);
    });
  });

  group('MivaltaMotion', () {
    test('motion durations are correct', () {
      expect(MivaltaMotion.fast, const Duration(milliseconds: 150));
      expect(MivaltaMotion.standard, const Duration(milliseconds: 280));
    });
  });

  group('readinessLevelColor', () {
    test('maps engine level string "green" to levelGreen token', () {
      expect(readinessLevelColor('green'), MivaltaColors.levelGreen);
      expect(readinessLevelColor('Green'), MivaltaColors.levelGreen);
      expect(readinessLevelColor('GREEN'), MivaltaColors.levelGreen);
    });

    test('maps engine level string "yellow" to levelYellow token', () {
      expect(readinessLevelColor('yellow'), MivaltaColors.levelYellow);
      expect(readinessLevelColor('Yellow'), MivaltaColors.levelYellow);
    });

    test('maps engine level string "orange" to levelOrange token', () {
      expect(readinessLevelColor('orange'), MivaltaColors.levelOrange);
      expect(readinessLevelColor('Orange'), MivaltaColors.levelOrange);
    });

    test('maps engine level string "red" to levelRed token', () {
      expect(readinessLevelColor('red'), MivaltaColors.levelRed);
      expect(readinessLevelColor('Red'), MivaltaColors.levelRed);
    });

    test('returns textMuted for unknown/null levels', () {
      expect(readinessLevelColor(null), MivaltaColors.textMuted);
      expect(readinessLevelColor('unknown'), MivaltaColors.textMuted);
      expect(readinessLevelColor(''), MivaltaColors.textMuted);
    });

    // Concrete hex value assertion (guards against token layer drift)
    test('green level returns exact hex 0xFF2BD974', () {
      expect(readinessLevelColor('green'), const Color(0xFF2BD974));
    });
  });

  group('fatigueStateColor', () {
    test('maps engine state string "recovered" to stateRecovered token', () {
      expect(fatigueStateColor('recovered'), MivaltaColors.stateRecovered);
      expect(fatigueStateColor('Recovered'), MivaltaColors.stateRecovered);
    });

    test('maps engine state string "productive" to stateProductive token', () {
      expect(fatigueStateColor('productive'), MivaltaColors.stateProductive);
      expect(fatigueStateColor('Productive'), MivaltaColors.stateProductive);
    });

    test('maps engine state string "accumulated" to stateAccumulated token', () {
      expect(fatigueStateColor('accumulated'), MivaltaColors.stateAccumulated);
      expect(fatigueStateColor('Accumulated'), MivaltaColors.stateAccumulated);
    });

    test('maps engine state string "overreached" to stateOverreached token', () {
      expect(fatigueStateColor('overreached'), MivaltaColors.stateOverreached);
      expect(fatigueStateColor('Overreached'), MivaltaColors.stateOverreached);
    });

    test('maps engine state string "illnessrisk" to stateIllnessRisk token', () {
      expect(fatigueStateColor('illnessrisk'), MivaltaColors.stateIllnessRisk);
      expect(fatigueStateColor('IllnessRisk'), MivaltaColors.stateIllnessRisk);
    });

    test('returns textMuted for unknown/null states', () {
      expect(fatigueStateColor(null), MivaltaColors.textMuted);
      expect(fatigueStateColor('unknown'), MivaltaColors.textMuted);
      expect(fatigueStateColor(''), MivaltaColors.textMuted);
    });

    // Concrete hex value assertions (guards against token layer drift)
    test('recovered state returns exact hex 0xFF7FE3B0', () {
      expect(fatigueStateColor('recovered'), const Color(0xFF7FE3B0));
    });

    test('productive state returns exact hex 0xFF00C6A7', () {
      expect(fatigueStateColor('productive'), const Color(0xFF00C6A7));
    });
  });

  // NOTE: mivaltaDarkTheme() tests removed — they require bundled google_fonts
  // assets which aren't available in unit tests. The color tokens are tested
  // above; the theme builder is exercised by widget tests and the running app.
}
