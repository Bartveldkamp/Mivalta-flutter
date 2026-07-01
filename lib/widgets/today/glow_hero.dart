// Glow Hero — the readiness state centrepiece.
//
// Per Today-Modular.html: radial gradient glow, state number in Inter
// (NOT Zen Dots — that's brand/wordmark only), state word below.
// The engine DECIDES the state; this only renders it.
//
// DR-008: Responsive sizing — scales down for smaller screens (SE).
// Beta is portrait-only; landscape deferred post-beta. Base fieldSize is 340.
//
// DR-009 fixes:
// - D1: Glow core centered on the number, not the number+state column
// - D2: Raised inner/mid halo scale/alpha (see tokens.dart)
// - D3: Honest "Learning" label when absent-hero has no content

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
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;

    // DR-005: Responsive glow sizing
    // - Base fieldSize is 280 (DR-005 bump from 240)
    // - Scale down for smaller screens (SE ~375px) to avoid overflow
    // - Landscape: use smaller field to fit in available height
    final baseFieldSize = MivaltaGlow.fieldSize; // 280
    final fieldSize = isLandscape
        ? baseFieldSize * 0.7 // Landscape: 70% of base
        : screenWidth < 390
            ? baseFieldSize * 0.85 // Small screens (SE): 85% = ~238
            : baseFieldSize; // Pro/Pro Max: full 280

    final outerSize = fieldSize * MivaltaGlow.outerScale;
    final midSize = fieldSize * MivaltaGlow.midScale;
    final innerSize = fieldSize * MivaltaGlow.innerScale;

    // Display: score number when data, state word only when insufficient.
    final showScore = !insufficientData && score != null;
    final stateWord = _formatState(fatigueState);

    // D3: Honest label for absent-hero when no score AND no state word.
    final absentLabel = (insufficientData || score == null) && stateWord.isEmpty
        ? 'Learning'
        : null;

    // D1: When showing number + state word, offset glow upward so it centers
    // on the number, not the combined column. The state word is ~20px * 1.2
    // line height + 8px gap ≈ 32px; shift glow up by half = 16px.
    final glowOffset = showScore && stateWord.isNotEmpty ? -16.0 : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x4),
      child: Center(
        child: SizedBox(
          width: fieldSize,
          height: fieldSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow layer (scale 1.30, blur 14)
              // D1: offset to center on number
              Transform.translate(
                offset: Offset(0, glowOffset),
                child: ImageFiltered(
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
              ),
              // Mid glow layer (scale 1.0, blur 8)
              // D1: offset to center on number
              Transform.translate(
                offset: Offset(0, glowOffset),
                child: ImageFiltered(
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
              ),
              // Inner glow layer (scale 0.60, blur 3)
              // D1: offset to center on number
              Transform.translate(
                offset: Offset(0, glowOffset),
                child: ImageFiltered(
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
                  else if (absentLabel != null)
                    // D3: honest label when no score and no state word
                    Text(
                      absentLabel,
                      style: MivaltaType.titleM.copyWith(
                        color: color,
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
