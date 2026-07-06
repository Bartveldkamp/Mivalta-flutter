// DR-024 W6: Load vessel — replaces the flat MetricBar for load display.
//
// A rounded capsule that FILLS with the day's load; the brim = ACWR ceiling.
// Fill is a vertical gradient of state teal; subtle liquid meniscus curve at
// the top edge (CustomPainter).
//
// States (per W7 — vessel state MUST follow ACWR zone):
//   - Within band: calm teal fill, level well below brim
//   - Near brim (zone "high"): fill turns amber at the meniscus
//   - Over (zone "overreaching"/"very_high"): vessel shows quiet overspill —
//     fill reaches brim, amber, small spill bead outside rim
//
// Reduced-motion: static levels, no animation. Animate fill on load-in only
// (600ms, decelerate).
//
// TODO(engine): W7 ask — the raw `acwr_recommendation` string from the engine
// wants a card-voice pass (match MiValta text guidance). That's a Rust-side
// copy edit, not this Dart layer.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Load vessel — the "bucket that can spill" visualization for training load.
///
/// DR-024 W6: replaces the flat MetricBar. The capsule fills with load; the
/// brim represents the ACWR ceiling (chronic load baseline).
class LoadVessel extends StatefulWidget {
  const LoadVessel({
    super.key,
    required this.value,
    required this.ceiling,
    required this.acwrZone,
    this.caption,
  });

  /// Today's cumulative load.
  final double value;

  /// The ACWR ceiling (chronic load baseline = brim of the vessel).
  final double ceiling;

  /// Engine-assigned ACWR zone. Determines vessel color:
  /// - "optimal", "low", "within_band" → teal (calm)
  /// - "high" → amber meniscus (near brim warning)
  /// - "very_high", "overreaching" → amber + overspill (over)
  final String acwrZone;

  /// Caption below the vessel (engine recommendation, rendered verbatim).
  final String? caption;

  @override
  State<LoadVessel> createState() => _LoadVesselState();
}

class _LoadVesselState extends State<LoadVessel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fillAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.decelerate,
    );
    // Check for reduced motion preference
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reduceMotion =
          MediaQuery.of(context).disableAnimations;
      if (reduceMotion) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(LoadVessel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Don't re-animate on widget updates — only on initial load
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Determine vessel state from ACWR zone.
  _VesselState _stateFromZone(String zone) {
    final z = zone.toLowerCase();
    if (z.contains('very_high') ||
        z.contains('overreaching') ||
        z.contains('over')) {
      return _VesselState.over;
    }
    if (z.contains('high')) {
      return _VesselState.nearBrim;
    }
    // optimal, low, within_band, moderate, etc.
    return _VesselState.withinBand;
  }

  @override
  Widget build(BuildContext context) {
    final fillFraction = widget.ceiling > 0
        ? (widget.value / widget.ceiling).clamp(0.0, 1.2) // allow 20% overspill
        : 0.0;
    final vesselState = _stateFromZone(widget.acwrZone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Bold number + ceiling
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              widget.value.round().toString(),
              style: MivaltaType.metric.copyWith(
                color: MivaltaColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '/ ${widget.ceiling.round()}',
              style: MivaltaType.small.copyWith(
                color: MivaltaColors.textMuted,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Row 2: The vessel
        AnimatedBuilder(
          animation: _fillAnimation,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(double.infinity, 56),
              painter: _VesselPainter(
                fillFraction: fillFraction * _fillAnimation.value,
                state: vesselState,
              ),
            );
          },
        ),

        // Row 3: Caption (engine recommendation, verbatim)
        if (widget.caption != null && widget.caption!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            widget.caption!,
            style: MivaltaType.small.copyWith(
              color: MivaltaColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

enum _VesselState { withinBand, nearBrim, over }

/// CustomPainter for the load vessel — a capsule with liquid fill.
class _VesselPainter extends CustomPainter {
  _VesselPainter({
    required this.fillFraction,
    required this.state,
  });

  /// Fill level as fraction of the vessel height (0.0 to 1.2 for overspill).
  final double fillFraction;

  /// Vessel state determines fill color.
  final _VesselState state;

  @override
  void paint(Canvas canvas, Size size) {
    final vesselHeight = size.height;
    final vesselWidth = size.width;
    final radius = vesselHeight / 2;

    // Vessel outline (capsule shape)
    final vesselRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, vesselWidth, vesselHeight),
      Radius.circular(radius),
    );

    // Background (empty vessel)
    final bgPaint = Paint()
      ..color = MivaltaColors.textPrimary.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(vesselRect, bgPaint);

    // Determine fill color based on state
    final Color fillColor;
    final Color meniscusColor;
    switch (state) {
      case _VesselState.withinBand:
        fillColor = MivaltaColors.stateProductive;
        meniscusColor = MivaltaColors.stateProductive;
      case _VesselState.nearBrim:
        fillColor = MivaltaColors.stateProductive;
        meniscusColor = MivaltaColors.levelOrange; // amber at meniscus
      case _VesselState.over:
        fillColor = MivaltaColors.levelOrange;
        meniscusColor = MivaltaColors.levelOrange;
    }

    // Calculate fill level (clamped to vessel height for main fill)
    final clampedFill = fillFraction.clamp(0.0, 1.0);
    final fillHeight = vesselHeight * clampedFill;

    if (fillHeight > 0) {
      // Clip to vessel shape
      canvas.save();
      canvas.clipRRect(vesselRect);

      // Draw fill with vertical gradient
      final fillRect = Rect.fromLTWH(
        0,
        vesselHeight - fillHeight,
        vesselWidth,
        fillHeight,
      );

      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          fillColor,
          fillColor.withValues(alpha: 0.85),
          state == _VesselState.nearBrim ? meniscusColor : fillColor,
        ],
        stops: const [0.0, 0.7, 1.0],
      );

      final fillPaint = Paint()
        ..shader = gradient.createShader(fillRect)
        ..style = PaintingStyle.fill;

      canvas.drawRect(fillRect, fillPaint);

      // Draw subtle meniscus curve at the top of the liquid
      if (fillHeight > 4) {
        _drawMeniscus(
          canvas,
          vesselWidth,
          vesselHeight - fillHeight,
          meniscusColor,
        );
      }

      canvas.restore();
    }

    // Draw overspill bead if over
    if (state == _VesselState.over && fillFraction > 1.0) {
      _drawOverspill(canvas, size);
    }

    // Vessel stroke (subtle outline)
    final strokePaint = Paint()
      ..color = MivaltaColors.textPrimary.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(vesselRect, strokePaint);
  }

  /// Draw the subtle liquid meniscus curve at the surface.
  void _drawMeniscus(
      Canvas canvas, double width, double surfaceY, Color color) {
    final meniscusHeight = 3.0;
    final meniscusPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, surfaceY + meniscusHeight)
      ..quadraticBezierTo(
        width / 2,
        surfaceY - meniscusHeight, // slight upward curve
        width,
        surfaceY + meniscusHeight,
      )
      ..lineTo(width, surfaceY + meniscusHeight * 2)
      ..lineTo(0, surfaceY + meniscusHeight * 2)
      ..close();

    canvas.drawPath(path, meniscusPaint);
  }

  /// Draw the quiet overspill bead outside the rim.
  void _drawOverspill(Canvas canvas, Size size) {
    final spillAmount = (fillFraction - 1.0).clamp(0.0, 0.2);
    final beadRadius = 4.0 + spillAmount * 15; // 4-7px bead
    final beadCenter = Offset(
      size.width * 0.7, // offset right of center
      -beadRadius * 0.3, // just above the rim
    );

    final beadPaint = Paint()
      ..color = MivaltaColors.levelOrange.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    // Small droplet shape
    final dropPath = Path();
    dropPath.addOval(Rect.fromCircle(center: beadCenter, radius: beadRadius));
    canvas.drawPath(dropPath, beadPaint);

    // Tiny highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      beadCenter + Offset(-beadRadius * 0.3, -beadRadius * 0.3),
      beadRadius * 0.25,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(_VesselPainter oldDelegate) {
    return oldDelegate.fillFraction != fillFraction ||
        oldDelegate.state != state;
  }
}
