// Time-in-Zone chart — Monitor analytics (display-only).
//
// Renders the engine's `TimeInZone` distribution (per-activity seconds in each
// canonical zone R, Z1..Z8) as horizontal bars. Bar lengths are pure ratios
// from the engine totals (`TimeInZone.fraction`); no thresholds, math, or
// binning in Dart — the engine classified every sample through MiValta's own
// `zone_anchors` scale. The widget only maps numbers to pixels.

import 'package:flutter/material.dart';

import '../../models/time_in_zone.dart';
import '../../theme/tokens.dart';

/// Zone → colour delegates to the single canonical map (`zoneColor` in
/// tokens.dart) — the Viterbi state-scale palette — so this chart and the
/// advisor screen can never diverge (audit #8). The engine owns the zone;
/// Dart only renders its colour.
Color _colorFor(String zone) => zoneColor(zone);

/// Human label for the anchor the engine classified through.
String _anchorLabel(String anchor) => switch (anchor) {
      'power' => 'Power',
      'pace' => 'Pace',
      'hr' => 'Heart rate',
      _ => '',
    };

class TimeInZoneChart extends StatelessWidget {
  final TimeInZone data;

  const TimeInZoneChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _NoData();
    }

    // Only render zones that hold time — keeps short sessions compact while the
    // engine still owns the full 9-bucket scale.
    final present = data.zones.where((z) => z.seconds > 0).toList(growable: false);
    final anchor = _anchorLabel(data.anchor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Time in zone',
              style: TextStyle(
                color: MivaltaColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (anchor.isNotEmpty)
              Text(
                anchor,
                style: const TextStyle(
                  color: MivaltaColors.textMuted,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: MivaltaSpace.x4),
        for (final z in present) ...[
          _ZoneBar(
            zone: z,
            fraction: data.fraction(z),
            color: _colorFor(z.zone),
          ),
          const SizedBox(height: MivaltaSpace.x3),
        ],
      ],
    );
  }
}

class _ZoneBar extends StatelessWidget {
  final ZoneSeconds zone;
  final double fraction;
  final Color color;

  const _ZoneBar({
    required this.zone,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            zone.zone,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: MivaltaSpace.x2),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MivaltaRadii.sm),
            child: Stack(
              children: [
                Container(height: 14, color: MivaltaColors.surface2),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(height: 14, color: color),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: MivaltaSpace.x3),
        SizedBox(
          width: 44,
          child: Text(
            '${zone.minutes}m',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: MivaltaColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
      ),
      child: const Text(
        'No zone data for this activity yet.',
        style: TextStyle(color: MivaltaColors.textMuted, fontSize: 14),
      ),
    );
  }
}
