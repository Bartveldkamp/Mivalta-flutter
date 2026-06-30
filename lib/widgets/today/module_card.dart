// ModuleCard — collapsible metric card for the Today screen.
// Per Today-Modular.html: icon + title header, expandable content with metrics.
// Read-only for now; edit mode (drag-reorder, hide/show) is a follow-up PR.
//
// Engine provides the data; this is pure presentation.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// A collapsible module card for the Today screen.
///
/// Shows an icon + title header with optional expand/collapse. Content is
/// provided as a child widget (typically MetricRows or other content).
class ModuleCard extends StatefulWidget {
  const ModuleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
    this.collapsible = true,
  });

  /// The icon to show in the header.
  final IconData icon;

  /// The card title (shown in ALL-CAPS).
  final String title;

  /// The card content (metrics, text, etc.).
  final Widget child;

  /// Whether the card starts expanded.
  final bool initiallyExpanded;

  /// Whether the card can be collapsed.
  final bool collapsible;

  @override
  State<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: MivaltaMotion.fast,
      vsync: this,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOut));
    if (_expanded) _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.collapsible) return;
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MivaltaColors.cardBackground,
        border: Border.all(color: MivaltaColors.cardBorder),
        borderRadius: BorderRadius.circular(MivaltaRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          GestureDetector(
            onTap: widget.collapsible ? _toggle : null,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(MivaltaSpace.x4),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 18,
                    color: MivaltaColors.stateProductive,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      widget.title.toUpperCase(),
                      style: MivaltaTextStyles.cardHeader(),
                    ),
                  ),
                  if (widget.collapsible)
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: MivaltaMotion.fast,
                      child: Icon(
                        Icons.expand_more,
                        size: 20,
                        color: MivaltaColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Content (animated)
          ClipRect(
            child: AnimatedBuilder(
              animation: _heightFactor,
              builder: (context, child) {
                return Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _heightFactor.value,
                  child: child,
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(
                  left: MivaltaSpace.x4,
                  right: MivaltaSpace.x4,
                  bottom: MivaltaSpace.x4,
                ),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single metric row for use inside ModuleCard.
///
/// Shows a label on the left and a value on the right, optionally with a unit.
class MetricRow extends StatelessWidget {
  const MetricRow({
    super.key,
    required this.label,
    required this.value,
    this.unit,
  });

  /// The metric label (e.g., "Training load").
  final String label;

  /// The metric value (e.g., "412").
  final String value;

  /// Optional unit suffix (e.g., "/600", "W", "min").
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: MivaltaTextStyles.cardHeader(),
            ),
          ),
          Text(
            value,
            style: MivaltaTextStyles.metricValue(),
          ),
          if (unit != null) ...[
            Text(
              unit!,
              style: MivaltaTextStyles.metricUnit(),
            ),
          ],
        ],
      ),
    );
  }
}

/// A progress bar for metrics (e.g., load progress).
class MetricProgressBar extends StatelessWidget {
  const MetricProgressBar({
    super.key,
    required this.progress,
    this.color,
  });

  /// Progress value (0.0 to 1.0).
  final double progress;

  /// Bar color (defaults to stateProductive).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? MivaltaColors.stateProductive;
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: MivaltaColors.cardBorder,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
