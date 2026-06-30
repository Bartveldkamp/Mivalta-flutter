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
    const heroSize = 180.0; // Larger for softer field
    const middleSize = heroSize * 0.72; // ~130px
    const innerSize = heroSize * 0.50; // ~90px

    // Display: score number when data, state word only when insufficient.
    final showScore = !insufficientData && score != null;
    final stateWord = _formatState(fatigueState);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x4),
      child: Center(
        child: SizedBox(
          width: heroSize,
          height: heroSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer halo (soft field layer 1)
              Container(
                width: heroSize,
                height: heroSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.12),
                      color.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              // Middle glow (soft field layer 2)
              Container(
                width: middleSize,
                height: middleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.22),
                      color.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              // Inner core glow
              Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.45),
                      color.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
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
                        fontSize: 42,
                        letterSpacing: -0.03 * 42, // tracking tight
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
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        stateWord,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: 0.5,
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
