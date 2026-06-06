// Power Curve chart — Monitor analytics, next-gen UI.
//
// Display-only (UI_UX §2.5 opaque data surface, §8.6 engine-drawn). Plots the
// mean-maximal power curve (log time axis) and labels the standard peak-power
// durations. The engine computes every watt; this widget renders + labels.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/power_curve.dart';
import '../../theme/tokens.dart';

class PowerCurveChart extends StatelessWidget {
  const PowerCurveChart({super.key, required this.curve});

  final PowerCurve curve;

  // Standard peak-power durations: 5 s, 1 min, 5 min, 20 min, 60 min.
  static const _keyDurations = [5, 60, 300, 1200, 3600];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Power profile',
            style: textTheme.titleMedium?.copyWith(
              color: MivaltaColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          if (curve.isEmpty)
            SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  'No power data yet.',
                  style: textTheme.bodyMedium?.copyWith(color: MivaltaColors.textMuted),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(painter: _PowerCurvePainter(curve: curve)),
            ),
            const SizedBox(height: MivaltaSpace.x3),
            // Key peak-power readouts (engine values, selected by duration).
            Wrap(
              spacing: MivaltaSpace.x5,
              runSpacing: MivaltaSpace.x2,
              children: _keyDurations.map((d) {
                final p = curve.nearest(d);
                return _PeakReadout(label: _durationLabel(d), watts: p?.maxPowerWatts);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  static String _durationLabel(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    return '${m}min';
  }
}

class _PeakReadout extends StatelessWidget {
  const _PeakReadout({required this.label, required this.watts});
  final String label;
  final double? watts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelSmall?.copyWith(color: MivaltaColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          watts == null ? '—' : '${watts!.round()}W',
          style: textTheme.titleMedium?.copyWith(
            color: MivaltaColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Plots watts vs log10(duration). Pure rendering.
class _PowerCurvePainter extends CustomPainter {
  _PowerCurvePainter({required this.curve});
  final PowerCurve curve;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = curve.points.where((p) => p.durationSeconds > 0).toList()
      ..sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));
    if (pts.length < 2) return;

    final minX = math.log(pts.first.durationSeconds.toDouble());
    final maxX = math.log(pts.last.durationSeconds.toDouble());
    var maxW = -double.infinity;
    for (final p in pts) {
      if (p.maxPowerWatts > maxW) maxW = p.maxPowerWatts;
    }
    if (maxW <= 0) return;
    final spanX = (maxX - minX) == 0 ? 1 : (maxX - minX);

    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = (math.log(pts[i].durationSeconds.toDouble()) - minX) / spanX * size.width;
      final y = size.height - (pts[i].maxPowerWatts / maxW) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = MivaltaColors.primaryGreen
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PowerCurvePainter old) => old.curve != curve;
}
