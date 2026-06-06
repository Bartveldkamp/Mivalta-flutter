// Fitness Development (PMC) chart — Monitor analytics, next-gen UI.
//
// Display-only (UI_UX_DIRECTION §2.1 insight-first, §2.5 opaque data surface,
// §8.6 engine-drawn chart). Renders the engine's Banister CTL/ATL/TSB series:
//   - CTL (fitness)  — slow line, the "are you getting fitter" signal
//   - ATL (fatigue)  — fast line
//   - TSB (form)     — CTL-ATL, the freshness band
// The engine computes the series + the form classification; this widget only
// plots and labels. No thresholds or math in Dart.

import 'package:flutter/material.dart';

import '../../models/fitness_trend.dart';
import '../../theme/tokens.dart';

class FitnessTrendChart extends StatelessWidget {
  const FitnessTrendChart({super.key, required this.trend});

  final FitnessTrend trend;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final latest = trend.latest;

    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Insight-first header: title + engine's form classification.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fitness development',
                style: textTheme.titleMedium?.copyWith(
                  color: MivaltaColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (trend.formZone != null && trend.formZone!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MivaltaSpace.x2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: MivaltaColors.surface2,
                    borderRadius: BorderRadius.circular(MivaltaRadii.sm),
                  ),
                  child: Text(
                    trend.formZone!,
                    style: textTheme.labelSmall?.copyWith(
                      color: MivaltaColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: MivaltaSpace.x3),

          if (trend.isEmpty)
            _EmptyChart(textTheme: textTheme)
          else ...[
            // The curve (opaque, engine-drawn).
            SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(
                painter: _PmcPainter(samples: trend.samples),
              ),
            ),
            const SizedBox(height: MivaltaSpace.x3),
            // Latest values + legend.
            Row(
              children: [
                _Metric(
                  label: 'Fitness (CTL)',
                  value: latest == null ? '—' : latest.ctl.round().toString(),
                  color: MivaltaColors.levelGreen,
                ),
                const SizedBox(width: MivaltaSpace.x5),
                _Metric(
                  label: 'Fatigue (ATL)',
                  value: latest == null ? '—' : latest.atl.round().toString(),
                  color: MivaltaColors.levelOrange,
                ),
                const SizedBox(width: MivaltaSpace.x5),
                _Metric(
                  label: 'Form (TSB)',
                  value: latest == null ? '—' : latest.tsb.round().toString(),
                  color: MivaltaColors.tertiaryTeal,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: MivaltaSpace.x1),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(color: MivaltaColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            color: MivaltaColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.textTheme});
  final TextTheme textTheme;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'Not enough training history yet.',
            style: textTheme.bodyMedium?.copyWith(color: MivaltaColors.textMuted),
          ),
        ),
      );
}

/// Plots CTL and ATL as lines over a shared min/max range. Pure rendering.
class _PmcPainter extends CustomPainter {
  _PmcPainter({required this.samples});
  final List<FitnessSample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    double minV = double.infinity, maxV = -double.infinity;
    for (final s in samples) {
      minV = [minV, s.ctl, s.atl].reduce((a, b) => a < b ? a : b);
      maxV = [maxV, s.ctl, s.atl].reduce((a, b) => a > b ? a : b);
    }
    if (minV == maxV) maxV = minV + 1;

    Offset pt(int i, double v) {
      final x = samples.length == 1 ? 0.0 : i / (samples.length - 1) * size.width;
      final y = size.height - (v - minV) / (maxV - minV) * size.height;
      return Offset(x, y);
    }

    void line(double Function(FitnessSample) sel, Color color) {
      final path = Path();
      for (var i = 0; i < samples.length; i++) {
        final p = pt(i, sel(samples[i]));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      );
    }

    line((s) => s.ctl, MivaltaColors.levelGreen);
    line((s) => s.atl, MivaltaColors.levelOrange);
  }

  @override
  bool shouldRepaint(covariant _PmcPainter old) => old.samples != samples;
}
