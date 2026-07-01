// MetricBar — DS-compliant counted-value widget.
//
// Per Metric-Treatments.html: counted metrics (load, sleep, watts) get a
// SHARP bar + bold number, not a glow. The bar shows where-in-range; the
// number is the hero. Scale markers anchor the ends; caption provides context.
//
// BS-005: replaces the flat MetricRow for Load/Sleep on Today.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// A counted metric with bold number, sharp bar, scale, and caption.
///
/// Per DS: use for load, sleep, watts — anything with a measurable value
/// against a range. Contrast with StateField (glow) for felt states.
class MetricBar extends StatelessWidget {
  const MetricBar({
    super.key,
    this.value,
    this.max = 100,
    this.valueWidget,
    this.ceiling,
    this.color,
    this.scaleStart,
    this.scaleEnd,
    this.caption,
  });

  /// The counted value (ignored if [valueWidget] is provided).
  final double? value;

  /// The denominator for the bar fill (defaults to 100).
  final double max;

  /// Rich value widget (e.g., "7h 42m" with styled units). Overrides [value].
  final Widget? valueWidget;

  /// Ceiling shown as "/ ceiling" beside the value.
  final double? ceiling;

  /// Bar fill color (defaults to stateProductive).
  final Color? color;

  /// Scale label at start (left), e.g., "0".
  final String? scaleStart;

  /// Scale label at end (right), e.g., "600" or "need · 8h 30m".
  final String? scaleEnd;

  /// Caption below the bar (e.g., "Within today's target band").
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final fillColor = color ?? MivaltaColors.stateProductive;
    final fillFraction = (value != null && max > 0)
        ? (value! / max).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Bold number + optional ceiling
        _buildValueRow(fillColor),

        const SizedBox(height: 9),

        // Row 2: Sharp hairline bar
        _buildBar(fillFraction, fillColor),

        // Row 3: Scale markers (if provided)
        if (scaleStart != null || scaleEnd != null) ...[
          const SizedBox(height: 6),
          _buildScale(),
        ],

        // Row 4: Caption (if provided)
        if (caption != null) ...[
          const SizedBox(height: 8),
          Text(
            caption!,
            style: MivaltaType.small.copyWith(
              color: MivaltaColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildValueRow(Color fillColor) {
    if (valueWidget != null) {
      // Rich value widget provided (e.g., sleep with h/m units)
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          valueWidget!,
          if (ceiling != null) ...[
            const SizedBox(width: 4),
            Text(
              '/ ${ceiling!.round()}',
              style: MivaltaType.small.copyWith(
                color: MivaltaColors.textMuted,
              ),
            ),
          ],
        ],
      );
    }

    // Simple numeric value
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value?.round().toString() ?? '--',
          style: MivaltaType.metric.copyWith(
            color: MivaltaColors.textPrimary,
          ),
        ),
        if (ceiling != null) ...[
          const SizedBox(width: 4),
          Text(
            '/ ${ceiling!.round()}',
            style: MivaltaType.small.copyWith(
              color: MivaltaColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBar(double fraction, Color fillColor) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: MivaltaColors.textPrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction,
        child: Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildScale() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          scaleStart ?? '',
          style: MivaltaType.label.copyWith(
            color: MivaltaColors.textMuted,
            fontSize: 10,
            letterSpacing: 0.3,
          ),
        ),
        Text(
          scaleEnd ?? '',
          style: MivaltaType.label.copyWith(
            color: MivaltaColors.textMuted,
            fontSize: 10,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// Rich sleep duration widget: "7h 42m" with muted unit styling.
///
/// Per BS-005: Sleep displays with unit spans muted at ~15px.
class SleepDuration extends StatelessWidget {
  const SleepDuration({
    super.key,
    required this.hours,
    required this.minutes,
  });

  final int hours;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$hours',
            style: MivaltaType.metric.copyWith(
              color: MivaltaColors.textPrimary,
            ),
          ),
          TextSpan(
            text: 'h',
            style: MivaltaType.small.copyWith(
              color: MivaltaColors.textMuted,
              fontSize: 15,
            ),
          ),
          if (minutes > 0) ...[
            const TextSpan(text: ' '),
            TextSpan(
              text: '$minutes',
              style: MivaltaType.metric.copyWith(
                color: MivaltaColors.textPrimary,
              ),
            ),
            TextSpan(
              text: 'm',
              style: MivaltaType.small.copyWith(
                color: MivaltaColors.textMuted,
                fontSize: 15,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
