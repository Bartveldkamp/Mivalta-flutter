// GlowHero — the centered radial glow with readiness score + state word.
// Per Today-Modular.html: breathing StateField glow with two concentric layers,
// score number, and state word below. The glow color maps to the fatigue state.
//
// Engine DECIDES the score and state; this only renders (no thresholds in Dart).

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The hero glow element for the Today screen.
///
/// Shows the readiness score as a large number inside a radial glow, with the
/// state word (Productive, Recovered, etc.) below. The glow color is derived
/// from the fatigue state. When [noData] is true, shows "—" instead of a score.
class GlowHero extends StatelessWidget {
  const GlowHero({
    super.key,
    required this.score,
    required this.stateWord,
    this.fatigueState,
    this.noData = false,
    this.onTap,
  });

  /// The readiness score (0-100). Engine-computed.
  final int? score;

  /// The state word to display ("Productive", "Recovered", etc.).
  /// Engine-computed; Dart only renders.
  final String? stateWord;

  /// The fatigue state for glow color mapping.
  final String? fatigueState;

  /// When true, shows honest absence ("—") instead of score.
  final bool noData;

  /// Callback when the glow is tapped (opens detail).
  final VoidCallback? onTap;

  /// Get the glow color based on fatigue state.
  /// Falls back to stateProductive (#00C6A7) if unknown.
  Color get _glowColor {
    if (noData) return MivaltaColors.textMuted;
    return fatigueStateColor(fatigueState);
  }

  @override
  Widget build(BuildContext context) {
    // Glow sizing from Today-Modular.html
    const size = 140.0;
    const h2Size = size * 0.61; // ~86px inner glow

    return GestureDetector(
      onTap: noData ? null : onTap,
      child: SizedBox(
        width: size,
        height: size + 24, // Extra space for state word
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The glow container
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow (h1): large blurred gradient
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _glowColor.withValues(alpha: 0.26),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.62],
                      ),
                    ),
                  ),
                  // Apply blur to outer glow
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _glowColor.withValues(alpha: 0.26),
                            blurRadius: 11,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Inner glow (h2): smaller, more intense
                  Container(
                    width: h2Size,
                    height: h2Size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _glowColor.withValues(alpha: 0.6),
                          _glowColor.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.56, 0.72],
                      ),
                    ),
                  ),
                  // Center content: score number
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        noData ? '—' : (score?.toString() ?? '—'),
                        style: MivaltaTextStyles.heroNumber(
                          color: noData
                              ? MivaltaColors.textMuted
                              : MivaltaColors.textPrimary,
                        ).copyWith(fontSize: 38), // Balanced density default
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // State word below the glow
            const SizedBox(height: MivaltaSpace.x1),
            if (stateWord != null && !noData)
              Text(
                stateWord!,
                style: MivaltaTextStyles.stateWord(color: _glowColor),
              ),
          ],
        ),
      ),
    );
  }
}
