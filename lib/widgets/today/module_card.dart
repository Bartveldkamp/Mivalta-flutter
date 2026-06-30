// Module Card — base card shell for Today modules.
//
// Per Today-Modular.html: cards have consistent radius 15, hairline border,
// subtle background. Content is passed as child.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// A module card with eyebrow title and icon.
class ModuleCard extends StatelessWidget {
  const ModuleCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  /// ALL-CAPS eyebrow title (e.g. "LOAD TODAY").
  final String title;

  /// Leading icon.
  final IconData icon;

  /// Card content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1.withValues(alpha:0.03),
        border: Border.all(
          color: MivaltaColors.textPrimary.withValues(alpha:0.08),
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Eyebrow
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: MivaltaColors.stateProductive,
              ),
              const SizedBox(width: 9),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: MivaltaColors.textPrimary.withValues(alpha:0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

/// A metric row inside a module card: label left, value right.
class MetricRow extends StatelessWidget {
  const MetricRow({
    super.key,
    required this.label,
    required this.value,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: MivaltaColors.textPrimary.withValues(alpha:0.5),
              ),
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 19,
                    color: MivaltaColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (unit != null)
                  TextSpan(
                    text: unit,
                    style: TextStyle(
                      fontSize: 11,
                      color: MivaltaColors.textPrimary.withValues(alpha:0.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A progress bar for module cards (e.g. load progress).
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.fraction,
    this.color,
  });

  /// Progress fraction 0.0 to 1.0.
  final double fraction;

  /// Bar color (defaults to stateProductive).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      margin: const EdgeInsets.only(top: 9),
      decoration: BoxDecoration(
        color: MivaltaColors.textPrimary.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? MivaltaColors.stateProductive,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
