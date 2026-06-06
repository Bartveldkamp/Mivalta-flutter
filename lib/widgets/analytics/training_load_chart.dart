// Training Load chart — Monitor analytics, next-gen UI.
//
// Display-only (UI_UX §2.5 opaque data surface). Daily training-load bars over
// the window. The engine computes each day's load; this widget renders bars +
// the peak readout. No thresholds or math in Dart (scaling is layout only).

import 'package:flutter/material.dart';

import '../../models/training_load.dart';
import '../../theme/tokens.dart';

class TrainingLoadChart extends StatelessWidget {
  const TrainingLoadChart({super.key, required this.load});

  final TrainingLoad load;

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
            'Training load',
            style: textTheme.titleMedium?.copyWith(
              color: MivaltaColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          if (load.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'No training load recorded yet.',
                  style: textTheme.bodyMedium?.copyWith(color: MivaltaColors.textMuted),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(painter: _LoadBarsPainter(load: load)),
            ),
            const SizedBox(height: MivaltaSpace.x3),
            Row(
              children: [
                Text('Peak day',
                    style: textTheme.labelSmall?.copyWith(color: MivaltaColors.textMuted)),
                const SizedBox(width: MivaltaSpace.x2),
                Text(
                  load.peak.round().toString(),
                  style: textTheme.titleMedium?.copyWith(
                    color: MivaltaColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: MivaltaSpace.x5),
                Text('Days',
                    style: textTheme.labelSmall?.copyWith(color: MivaltaColors.textMuted)),
                const SizedBox(width: MivaltaSpace.x2),
                Text(
                  load.days.length.toString(),
                  style: textTheme.titleMedium?.copyWith(
                    color: MivaltaColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadBarsPainter extends CustomPainter {
  _LoadBarsPainter({required this.load});
  final TrainingLoad load;

  @override
  void paint(Canvas canvas, Size size) {
    final days = load.days;
    if (days.isEmpty) return;
    final maxV = load.peak;
    if (maxV <= 0) return;

    final n = days.length;
    final slot = size.width / n;
    final barW = slot * 0.7;
    final paint = Paint()..color = MivaltaColors.stateProductive;

    for (var i = 0; i < n; i++) {
      final h = (days[i].load / maxV) * size.height;
      final x = i * slot + (slot - barW) / 2;
      final y = size.height - h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barW, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoadBarsPainter old) => old.load != load;
}
