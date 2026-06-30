// Glow Hero — the readiness state centrepiece.
//
// Per Today-Modular.html: radial gradient glow, state number in Inter
// (NOT Zen Dots — that's brand/wordmark only), state word below.
// The engine DECIDES the state; this only renders it.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// State→colour mapping. Recovered is #7FE3B0 (the DR-001 correction),
/// productive is #00C6A7. Engine decides the state; we render the token.
Color _stateColor(String? fatigueState) =>
    switch ((fatigueState ?? '').toLowerCase()) {
      'recovered' => MivaltaColors.stateRecovered,
      'productive' => MivaltaColors.stateProductive,
      'accumulated' => MivaltaColors.stateAccumulated,
      'overreached' => MivaltaColors.stateOverreached,
      'illnessrisk' => MivaltaColors.stateIllnessRisk,
      _ => MivaltaColors.stateProductive, // neutral fallback
    };

/// The glow hero — radial gradient centrepiece with readiness number and state word.
class GlowHero extends StatelessWidget {
  const GlowHero({
    super.key,
    required this.score,
    required this.fatigueState,
    this.insufficientData = false,
  });

  /// Readiness score (0-100). Null or insufficientData → no number.
  final int? score;

  /// Viterbi fatigue state (Recovered, Productive, Accumulated, etc.).
  final String? fatigueState;

  /// When true, show honest-absence instead of score.
  final bool insufficientData;

  @override
  Widget build(BuildContext context) {
    final color = _stateColor(fatigueState);
    const heroSize = 140.0;
    const innerSize = heroSize * 0.61; // ~86px

    // Display: score number when data, state word only when insufficient.
    final showScore = !insufficientData && score != null;
    final stateWord = _formatState(fatigueState);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x3),
      child: Center(
        child: SizedBox(
          width: heroSize,
          height: heroSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: heroSize,
                height: heroSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha:0.26),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.62],
                  ),
                ),
              ),
              // Inner glow (blur simulated with lower opacity gradient)
              Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha:0.6),
                      color.withValues(alpha:0.14),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.56, 0.72],
                  ),
                ),
              ),
              // Number + state word
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showScore)
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 38,
                        letterSpacing: -0.03 * 38, // tracking tight
                        height: 1.05,
                        color: MivaltaColors.textPrimary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    )
                  else
                    // No score — show state word as hero
                    Text(
                      stateWord,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 26,
                        letterSpacing: -0.02 * 26,
                        color: color,
                      ),
                    ),
                  if (showScore && stateWord.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        stateWord,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Capitalize state for display.
  String _formatState(String? state) {
    if (state == null || state.isEmpty) return '';
    // 'illnessRisk' → 'Illness Risk'
    final s = state.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    return s[0].toUpperCase() + s.substring(1);
  }
}
