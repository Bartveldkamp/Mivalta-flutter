// Glow Hero — the readiness state centrepiece.
//
// Per Today-Modular.html: radial gradient glow, state number in Inter
// (NOT Zen Dots — that's brand/wordmark only), state word below.
// The engine DECIDES the state; this only renders it.

import 'dart:ui';

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

    // DR-004 token pass: use MivaltaGlow for 3-layer glow with 240px field.
    // Outer: scale 1.30, alpha 0.26, blur 14, stop 66%
    // Mid: scale 0.92, alpha 0.40, blur 8, stop 66%
    // Inner: scale 0.50, alpha 0.64, blur 3, stop 72%
    const fieldSize = MivaltaGlow.fieldSize; // 240
    final outerSize = fieldSize * MivaltaGlow.outerScale; // ~312
    final midSize = fieldSize * MivaltaGlow.midScale; // ~221
    final innerSize = fieldSize * MivaltaGlow.innerScale; // ~120

    // Display: score number when data, state word only when insufficient.
    final showScore = !insufficientData && score != null;
    final stateWord = _formatState(fatigueState);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x4),
      child: Center(
        child: SizedBox(
          width: fieldSize,
          height: fieldSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow layer (scale 1.30 = ~312px, blur 14)
              ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: MivaltaGlow.outerBlur,
                  sigmaY: MivaltaGlow.outerBlur,
                ),
                child: Container(
                  width: outerSize,
                  height: outerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: MivaltaGlow.outerAlpha),
                        Colors.transparent,
                      ],
                      stops: [0.0, MivaltaGlow.outerStop],
                    ),
                  ),
                ),
              ),
              // Mid glow layer (scale 0.92 = ~221px, blur 8)
              ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: MivaltaGlow.midBlur,
                  sigmaY: MivaltaGlow.midBlur,
                ),
                child: Container(
                  width: midSize,
                  height: midSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: MivaltaGlow.midAlpha),
                        Colors.transparent,
                      ],
                      stops: [0.0, MivaltaGlow.midStop],
                    ),
                  ),
                ),
              ),
              // Inner glow layer (scale 0.50 = ~120px, blur 3)
              ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: MivaltaGlow.innerBlur,
                  sigmaY: MivaltaGlow.innerBlur,
                ),
                child: Container(
                  width: innerSize,
                  height: innerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: MivaltaGlow.innerAlpha),
                        Colors.transparent,
                      ],
                      stops: [0.0, MivaltaGlow.innerStop],
                    ),
                  ),
                ),
              ),
              // Number + state word (unblurred, on top)
              // DR-004: hero w400 (MivaltaType.hero), state word titleM (20px w600)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showScore)
                    Text(
                      '$score',
                      style: MivaltaType.hero.copyWith(
                        color: MivaltaColors.textPrimary,
                      ),
                    )
                  else
                    // No score — show state word as hero
                    Text(
                      stateWord,
                      style: MivaltaType.titleM.copyWith(
                        color: color,
                      ),
                    ),
                  if (showScore && stateWord.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: MivaltaGlow.wordGap),
                      child: Text(
                        stateWord,
                        style: MivaltaType.titleM.copyWith(
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
