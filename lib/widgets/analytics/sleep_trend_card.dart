// Sleep Trend card — Monitor analytics, next-gen UI.
//
// Display-only (UI_UX_DIRECTION §2.1 insight-first). The most recent night's
// sleep (verbatim) on top, a sparkline of recent nights below. Engine-sourced;
// honest empty state. Tokens-only. No derived metric — just renders what's stored.

import 'package:flutter/material.dart';

import '../../models/sleep_trend.dart';
import '../../theme/tokens.dart';

class SleepTrendCard extends StatelessWidget {
  const SleepTrendCard({super.key, required this.trend});

  final SleepTrend trend;

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
            'SLEEP',
            style: textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: MivaltaColors.textMuted,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          if (trend.isEmpty)
            Text(
              'No sleep data yet.',
              style: textTheme.bodyMedium?.copyWith(color: MivaltaColors.textMuted),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trend.latestHours!.toStringAsFixed(1),
                  style: textTheme.displaySmall?.copyWith(
                    color: MivaltaColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: MivaltaSpace.x1),
                Padding(
                  padding: const EdgeInsets.only(bottom: MivaltaSpace.x1),
                  child: Text(
                    'h last night',
                    style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
                  ),
                ),
              ],
            ),
            if (trend.series.length > 1) ...[
              const SizedBox(height: MivaltaSpace.x3),
              SizedBox(
                height: 44,
                child: CustomPaint(
                  painter: _SleepSparkline(series: trend.series),
                  size: const Size(double.infinity, 44),
                ),
              ),
            ],
            const SizedBox(height: MivaltaSpace.x2),
            Text(
              '${trend.nights.length} nights',
              style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _SleepSparkline extends CustomPainter {
  _SleepSparkline({required this.series});
  final List<double> series;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;

    final line = Paint()
      ..color = MivaltaColors.primaryGreen
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final minV = series.reduce((a, b) => a < b ? a : b);
    final maxV = series.reduce((a, b) => a > b ? a : b);
    final range = maxV - minV;

    final path = Path();
    for (var i = 0; i < series.length; i++) {
      final x = (i / (series.length - 1)) * size.width;
      final norm = range > 0 ? (series[i] - minV) / range : 0.5;
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
  bool shouldRepaint(covariant _SleepSparkline oldDelegate) => true;
}
