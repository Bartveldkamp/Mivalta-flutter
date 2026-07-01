// SleepStageRing — full 360° sleep stage donut.
//
// Per BS-006 / Metric-Treatments.html: Sleep is ALWAYS a full ring sliced into
// stages (Deep/REM/Light/Awake). The ring is 100% filled — there is no "remaining"
// arc. Total sleep time appears in the center; legend shows per-stage breakdown.
//
// If no stage data is available, render the honest-absent variant: a full outline
// ring with "No sleep data" text and "Connect a sleep tracker" caption.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Sleep stage data for the ring.
class SleepStages {
  const SleepStages({
    required this.deepMinutes,
    required this.remMinutes,
    required this.lightMinutes,
    required this.awakeMinutes,
  });

  final int deepMinutes;
  final int remMinutes;
  final int lightMinutes;
  final int awakeMinutes;

  int get totalMinutes => deepMinutes + remMinutes + lightMinutes + awakeMinutes;

  bool get hasData => totalMinutes > 0;
}

/// A full 360° sleep stage ring with center total and legend.
///
/// Per BS-006: Sleep is always a full ring sliced into stages. The ring never
/// shows a partial arc or "remaining to target" fill — it's 100% the measured
/// night, divided by stage.
class SleepStageRing extends StatelessWidget {
  const SleepStageRing({
    super.key,
    this.stages,
    this.needMinutes,
    this.sourceTier,
  });

  /// Per-stage minutes. If null or empty, shows honest-absent variant.
  final SleepStages? stages;

  /// Target sleep need in minutes (for caption).
  final int? needMinutes;

  /// Source tier for caption (e.g., "device-sourced").
  final String? sourceTier;

  @override
  Widget build(BuildContext context) {
    final hasStages = stages != null && stages!.hasData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ring + legend row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // The ring
            SizedBox(
              width: 100,
              height: 100,
              child: hasStages
                  ? CustomPaint(
                      painter: _SleepRingPainter(stages: stages!),
                      child: Center(child: _buildCenterText()),
                    )
                  : CustomPaint(
                      painter: _EmptyRingPainter(),
                      child: Center(child: _buildAbsentCenterText()),
                    ),
            ),

            const SizedBox(width: 16),

            // Legend (only when we have stages)
            if (hasStages) Expanded(child: _buildLegend()),
          ],
        ),

        const SizedBox(height: 10),

        // Caption
        Text(
          hasStages ? _buildCaption() : 'Connect a sleep tracker',
          style: MivaltaType.small.copyWith(
            color: MivaltaColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCenterText() {
    final total = stages!.totalMinutes;
    final hours = total ~/ 60;
    final mins = total % 60;
    final timeStr = mins > 0 ? '${hours}h${mins}m' : '${hours}h';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeStr,
          style: MivaltaType.metric.copyWith(
            color: MivaltaColors.textPrimary,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'ASLEEP',
          style: MivaltaType.label.copyWith(
            color: MivaltaColors.textMuted,
            fontSize: 8,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildAbsentCenterText() {
    return Text(
      'No sleep\ndata',
      textAlign: TextAlign.center,
      style: MivaltaType.small.copyWith(
        color: MivaltaColors.textMuted,
        fontSize: 11,
        height: 1.3,
      ),
    );
  }

  // Legend order per DR-014: Light / REM / Deep / Awake (draw order unchanged).
  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendRow(
          color: MivaltaColors.sleepLight,
          label: 'Light',
          minutes: stages!.lightMinutes,
        ),
        const SizedBox(height: 6),
        _LegendRow(
          color: MivaltaColors.sleepRem,
          label: 'REM',
          minutes: stages!.remMinutes,
        ),
        const SizedBox(height: 6),
        _LegendRow(
          color: MivaltaColors.sleepDeep,
          label: 'Deep',
          minutes: stages!.deepMinutes,
        ),
        const SizedBox(height: 6),
        _LegendRow(
          color: MivaltaColors.sleepAwake,
          label: 'Awake',
          minutes: stages!.awakeMinutes,
        ),
      ],
    );
  }

  String _buildCaption() {
    final total = stages!.totalMinutes;
    final hours = total ~/ 60;
    final mins = total % 60;
    final totalStr = mins > 0 ? '${hours}h${mins}m' : '${hours}h';

    final parts = <String>[];

    if (needMinutes != null && needMinutes! > 0) {
      final needH = needMinutes! ~/ 60;
      final needM = needMinutes! % 60;
      final needStr = needM > 0 ? '${needH}h${needM}m' : '${needH}h';
      parts.add('$totalStr of $needStr need');
    } else {
      parts.add(totalStr);
    }

    if (sourceTier != null) {
      parts.add(sourceTier!);
    }

    return parts.join(' · ');
  }
}

/// Legend row: colored dot + label + duration.
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.minutes,
  });

  final Color color;
  final String label;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final timeStr = hours > 0
        ? (mins > 0 ? '${hours}h${mins}m' : '${hours}h')
        : '${mins}m';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: MivaltaType.small.copyWith(
            color: MivaltaColors.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          timeStr,
          style: MivaltaType.small.copyWith(
            color: MivaltaColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter for the filled stage ring.
class _SleepRingPainter extends CustomPainter {
  _SleepRingPainter({required this.stages});

  final SleepStages stages;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 7; // strokeWidth/2 padding
    const strokeWidth = 10.0;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = stages.totalMinutes.toDouble();
    if (total <= 0) return;

    // Start at top (-90°), sweep clockwise
    // Draw order: Deep → REM → Light → Awake
    double startAngle = -math.pi / 2;

    void drawArc(int minutes, Color color) {
      if (minutes <= 0) return;
      final sweep = (minutes / total) * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }

    drawArc(stages.deepMinutes, MivaltaColors.sleepDeep);
    drawArc(stages.remMinutes, MivaltaColors.sleepRem);
    drawArc(stages.lightMinutes, MivaltaColors.sleepLight);
    drawArc(stages.awakeMinutes, MivaltaColors.sleepAwake);
  }

  @override
  bool shouldRepaint(covariant _SleepRingPainter oldDelegate) {
    return oldDelegate.stages != stages;
  }
}

/// CustomPainter for the empty/absent ring (full outline, no fill).
class _EmptyRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 7;
    const strokeWidth = 10.0;

    final paint = Paint()
      ..color = MivaltaColors.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
