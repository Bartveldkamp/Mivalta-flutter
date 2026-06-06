// Fitness trend chart — Monitor analytics, next-gen UI.
//
// Display-only (UI_UX_DIRECTION §2.1 insight-first, §2.5 opaque data surface,
// §8.6 engine-drawn chart). Renders the engine's long-term Banister fitness
// trend (the slow shape):
//   - fitness — slow line, the "are you getting fitter" signal
//   - fatigue — fast line
//   - form    — fitness − fatigue (shown as a value)
// Optionally overlays the athlete's ACTUAL watts/pace over time on a secondary
// scale — the trend is the model, the overlay is measured (no new claim). The
// engine computes everything; this widget only plots and labels. No math in
// Dart beyond rendering geometry.

import 'package:flutter/material.dart';

import '../../models/fitness_trend.dart';
import '../../models/metric_series.dart';
import '../../theme/tokens.dart';

class FitnessTrendChart extends StatelessWidget {
  const FitnessTrendChart({
    super.key,
    required this.trend,
    this.overlay,
    this.overlayLabel,
  });

  final FitnessTrend trend;

  /// Actual watts/pace over time, plotted on a secondary scale. Null = no overlay.
  final MetricSeries? overlay;

  /// Legend label for the overlay (e.g. "Actual watts", "Actual pace").
  final String? overlayLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final latest = trend.latest;
    final hasOverlay = overlay != null && !overlay!.isEmpty && overlayLabel != null;

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
            'Fitness development',
            style: textTheme.titleMedium?.copyWith(
              color: MivaltaColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x1),
          Text(
            'Your long-term fitness shape — the slow Banister trend.',
            style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          if (trend.isEmpty)
            _EmptyChart(textTheme: textTheme)
          else ...[
            SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(
                painter: _TrendPainter(
                  samples: trend.samples,
                  overlay: hasOverlay ? overlay!.samples : const [],
                ),
              ),
            ),
            const SizedBox(height: MivaltaSpace.x3),
            Row(
              children: [
                _Metric(
                  label: 'Fitness',
                  value: latest == null ? '—' : latest.fitness.round().toString(),
                  color: MivaltaColors.levelGreen,
                ),
                const SizedBox(width: MivaltaSpace.x5),
                _Metric(
                  label: 'Fatigue',
                  value: latest == null ? '—' : latest.fatigue.round().toString(),
                  color: MivaltaColors.levelOrange,
                ),
                const SizedBox(width: MivaltaSpace.x5),
                _Metric(
                  label: 'Form',
                  value: latest == null ? '—' : latest.form.round().toString(),
                  color: MivaltaColors.tertiaryTeal,
                ),
              ],
            ),
            if (hasOverlay) ...[
              const SizedBox(height: MivaltaSpace.x2),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: MivaltaColors.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: MivaltaSpace.x1),
                  Text(
                    '${overlayLabel!} (measured, secondary scale)',
                    style: textTheme.labelSmall?.copyWith(color: MivaltaColors.textMuted),
                  ),
                ],
              ),
            ],
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
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: MivaltaSpace.x1),
            Text(label,
                style: textTheme.labelSmall?.copyWith(color: MivaltaColors.textMuted)),
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

/// Plots fitness + fatigue as lines (left scale) and the actuals overlay as dots
/// (right scale, its own range). Pure rendering geometry — no engine logic.
class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.samples, required this.overlay});
  final List<FitnessSample> samples;
  final List<MetricSample> overlay;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    double minV = double.infinity, maxV = -double.infinity;
    for (final s in samples) {
      for (final v in [s.fitness, s.fatigue]) {
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
    }
    if (minV == maxV) maxV = minV + 1;

    Offset pt(int i, double v) {
      final x = i / (samples.length - 1) * size.width;
      final y = size.height - (v - minV) / (maxV - minV) * size.height;
      return Offset(x, y);
    }

    void line(double Function(FitnessSample) sel, Color color) {
      final path = Path();
      for (var i = 0; i < samples.length; i++) {
        final p = pt(i, sel(samples[i]));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
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

    line((s) => s.fitness, MivaltaColors.levelGreen);
    line((s) => s.fatigue, MivaltaColors.levelOrange);

    // Actuals overlay: dots on the right scale, positioned by date within the
    // trend's date span. Rendering geometry only.
    if (overlay.isNotEmpty) {
      final first = DateTime.tryParse(samples.first.date);
      final last = DateTime.tryParse(samples.last.date);
      if (first == null || last == null) return;
      final spanDays = last.difference(first).inDays;
      if (spanDays <= 0) return;

      double oMin = double.infinity, oMax = -double.infinity;
      for (final s in overlay) {
        if (s.value < oMin) oMin = s.value;
        if (s.value > oMax) oMax = s.value;
      }
      if (oMin == oMax) oMax = oMin + 1;

      final dot = Paint()..color = MivaltaColors.textSecondary;
      for (final s in overlay) {
        final d = DateTime.tryParse(s.date);
        if (d == null) continue;
        final frac = (d.difference(first).inDays / spanDays).clamp(0.0, 1.0);
        final x = frac * size.width;
        final y = size.height - (s.value - oMin) / (oMax - oMin) * size.height;
        canvas.drawCircle(Offset(x, y), 2.5, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.samples != samples || old.overlay != overlay;
}
