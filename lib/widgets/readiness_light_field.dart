// Readiness-as-light hero (UI_UX_DIRECTION §17.2, promoted to MVP by founder
// decision 2026-06-15; see the v1.7 scope banner). The Viterbi STATE is read
// pre-cognitively from how this surface LOOKS — calm/cool and open when
// recovered, warm/thick when accumulating, dim/settled when overreached,
// receding/still for illness risk — then CONFIRMED by the named state word +
// number beneath (§5.2 / 14.13: never light/colour alone). Display-only:
// every input is a verbatim engine read (state, score, the confidence-derived
// learning/no-data gates). This widget renders, it never computes.
//
// Material discipline: a tasteful luminance/gradient field (RadialGradient) —
// "90% of the intent at 0% of the GPU risk" (§17.2 Flutter subset). No
// per-pixel Liquid Glass, no shaders.
//
// SCOPE NOTE: the §17.5 slow "breathing" re-settle motion is a deliberate
// FOLLOW-UP increment — this first cut paints a STATIC state-driven field so
// the look can be verified on-device before motion is added (and so the home's
// widget tests, which lean on pumpAndSettle, are not blocked by a perpetual
// animation). State already reads from colour + glow extent + intensity here;
// motion is polish layered on next.
//
// Accessibility (§7 / 14.13): the state word + number are real text (read by
// screen readers); a Semantics summary carries state + score. Muted-alarm
// (§17.3): entering a safety state (IllnessRisk) fires one slow haptic on
// first appearance and the field recedes/stills — impossible to miss because
// the whole surface changes behaviour, not because it shouts.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../theme/tokens.dart';

/// How the light looks for one engine Viterbi state. A pure presentation
/// mapping of an engine enum (like [fatigueStateColor]) — no thresholds, no
/// physiology. Values are relative (0..1).
@immutable
class ReadinessLightProfile {
  const ReadinessLightProfile({
    required this.color,
    required this.glowExtent,
    required this.intensity,
    required this.safety,
  });

  /// Glow colour, sourced through the locked state palette tokens.
  final Color color;

  /// Relative radius of the luminance pool (0..1): larger = more "air".
  final double glowExtent;

  /// Peak alpha of the pool centre (0..1): brighter when fresh, dimmer as
  /// fatigue accumulates and the light recedes.
  final double intensity;

  /// Safety state (IllnessRisk): the field recedes/stills and a one-shot
  /// haptic fires on first appearance (§17.3 muted alarm).
  final bool safety;
}

/// Map an engine Viterbi state → its light look (§17.2 table). Direct
/// presentation mapping of the engine enum; colours come from the locked
/// [MivaltaColors] state palette via [fatigueStateColor].
ReadinessLightProfile lightProfileForState(String? state) {
  final color = fatigueStateColor(state);
  switch ((state ?? '').toLowerCase()) {
    case 'recovered':
      // Calm, cool, gently luminous — light pooling, air in it.
      return ReadinessLightProfile(
          color: color, glowExtent: 1.0, intensity: 0.85, safety: false);
    case 'productive':
      // Confident, steady glow.
      return ReadinessLightProfile(
          color: color, glowExtent: 0.94, intensity: 0.80, safety: false);
    case 'accumulated':
      // Light warms and thickens; the surface feels heavier.
      return ReadinessLightProfile(
          color: color, glowExtent: 0.80, intensity: 0.74, safety: false);
    case 'overreached':
      // Light dims and settles.
      return ReadinessLightProfile(
          color: color, glowExtent: 0.64, intensity: 0.62, safety: false);
    case 'illnessrisk':
      // Light RECEDES and STILLS — desaturated, quieted.
      return ReadinessLightProfile(
          color: color, glowExtent: 0.50, intensity: 0.52, safety: true);
    default:
      // Unknown / no claimed state: muted, small — honest absence of a state
      // colour rather than a fabricated healthy glow.
      return const ReadinessLightProfile(
          color: MivaltaColors.textMuted,
          glowExtent: 0.45,
          intensity: 0.40,
          safety: false);
  }
}

/// The readiness-as-light hero. All inputs are verbatim engine reads.
class ReadinessLightField extends StatefulWidget {
  const ReadinessLightField({
    super.key,
    required this.fatigueState, // engine Viterbi state → light look
    required this.stateWord,    // humanized state word (confirmation)
    required this.score,        // indicator['score'], rounded (confirmation)
    required this.noData,
    required this.learning,
  });

  /// Raw engine Viterbi state (e.g. "Recovered", "IllnessRisk"); drives the
  /// light look + palette colour. Null when no state is claimed.
  final String? fatigueState;

  /// Display state word beneath the light (already humanized by the caller).
  final String? stateWord;

  /// Readiness number beneath the light — smaller than the old hero number,
  /// it is now CONFIRMATION, not the headline (§17.2).
  final int? score;

  /// Honest absence: the engine has nothing to stand on yet. No coloured
  /// light, a quiet em-dash; the locked F1 copy lives in Josi's card.
  final bool noData;

  /// Engine still calibrating: the field is faint and muted and claims no
  /// state colour (unresolved light for unresolved knowledge, §1.4).
  final bool learning;

  @override
  State<ReadinessLightField> createState() => _ReadinessLightFieldState();
}

class _ReadinessLightFieldState extends State<ReadinessLightField> {
  bool _wasSafety = false;

  ReadinessLightProfile get _profile => widget.noData
      ? lightProfileForState(null)
      : widget.learning
          // Calibrating: muted, faint — no state colour claimed.
          ? const ReadinessLightProfile(
              color: MivaltaColors.textMuted,
              glowExtent: 0.6,
              intensity: 0.42,
              safety: false)
          : lightProfileForState(widget.fatigueState);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _profile;
    final double dimension = widget.learning || widget.noData ? 180 : 280;

    // Muted-alarm: fire one slow haptic the first time we enter a safety state.
    if (profile.safety && !_wasSafety) {
      HapticFeedback.heavyImpact();
    }
    _wasSafety = profile.safety;

    // Confirmation stack (never light alone): state word + number, smaller.
    final Widget confirmation = widget.noData
        ? Text(
            '—',
            style: theme.textTheme.displaySmall
                ?.copyWith(color: MivaltaColors.textMuted),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.stateWord != null && !widget.learning)
                Text(
                  widget.stateWord!,
                  style:
                      theme.textTheme.titleLarge?.copyWith(color: profile.color),
                ),
              Text(
                '${widget.score ?? '—'}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: widget.learning
                      ? MivaltaColors.textMuted
                      : MivaltaColors.textPrimary,
                ),
              ),
            ],
          );

    final field = SizedBox(
      width: dimension,
      height: dimension,
      child: CustomPaint(
        painter: _LightFieldPainter(profile: profile),
        child: Center(child: confirmation),
      ),
    );

    // Screen-reader summary: provenance is the state, confirmation is the
    // number. Light is decoration on top of these.
    final label = widget.noData
        ? 'Readiness: not enough data yet'
        : widget.learning
            ? 'Readiness ${widget.score ?? ''}, still calibrating'
            : 'Readiness ${widget.score ?? ''}, ${widget.stateWord ?? ''}';
    return Semantics(
      container: true,
      label: label.trim(),
      child: ExcludeSemantics(child: field),
    );
  }
}

class _LightFieldPainter extends CustomPainter {
  _LightFieldPainter({required this.profile});

  final ReadinessLightProfile profile;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final extent = profile.glowExtent.clamp(0.05, 1.0).toDouble();
    final radius = (size.shortestSide / 2) * extent;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          profile.color.withValues(alpha: profile.intensity),
          profile.color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_LightFieldPainter old) =>
      old.profile.color != profile.color ||
      old.profile.glowExtent != profile.glowExtent ||
      old.profile.intensity != profile.intensity;
}
