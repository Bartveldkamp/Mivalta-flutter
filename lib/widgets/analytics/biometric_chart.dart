// Biometric Chart — Explore view, next-gen UI.
//
// Display-only. Renders one biometric series (engine-sourced) as a line with the
// latest value on top and min/max context. Honest empty state for a range with
// no recorded data. Tokens-only. No derived metric — only rendering geometry.

import 'package:flutter/material.dart';

import '../../models/biometric_series.dart';
import '../../theme/tokens.dart';

class BiometricChart extends StatelessWidget {
  const BiometricChart({super.key, required this.series});

  final BiometricSeries series;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final unit = series.metric.unit;

    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                series.metric.label.toUpperCase(),
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: MivaltaColors.textMuted,
                ),
              ),
              if (series.latest != null)
                Text(
                  '${_fmt(series.latest!)}${unit.isEmpty ? '' : ' $unit'}',
                  style: textTheme.titleMedium?.copyWith(
                    color: MivaltaColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: MivaltaSpace.x3),
          if (series.isEmpty)
            Text(
              'No ${series.metric.label} data in this range.',
              style: textTheme.bodyMedium?.copyWith(color: MivaltaColors.textMuted),
            )
          else ...[
            SizedBox(
              height: 56,
              child: CustomPaint(
                painter: _LinePainter(values: series.values),
                size: const Size(double.infinity, 56),
              ),
            ),
            const SizedBox(height: MivaltaSpace.x2),
            Text(
              '${series.points.length} readings',
              style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// Whole numbers render without a decimal; otherwise one decimal place.
  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.values});
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final line = Paint()
      ..color = MivaltaColors.primaryGreen
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = maxV - minV;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length > 1
          ? (i / (values.length - 1)) * size.width
          : size.width / 2;
      final norm = range > 0 ? (values[i] - minV) / range : 0.5;
      final y = size.height - (norm * size.height * 0.8) - size.height * 0.1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => true;
}
