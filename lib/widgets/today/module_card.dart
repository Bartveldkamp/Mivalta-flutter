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

  /// Title Case eyebrow title (e.g. "Load today").
  final String title;

  /// Leading icon.
  final IconData icon;

  /// Card content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // BS-001 Step 9: card container styling
    // bg rgba(255,255,255,.03), border 1px rgba(255,255,255,.08), radius 14px, padding 13px 14px
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF), // rgba(255,255,255,.03) ≈ 0x08
        border: Border.all(
          color: const Color(0x14FFFFFF), // rgba(255,255,255,.08) ≈ 0x14
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // BS-001 Step 2: icon tile 30×30, radius 9px, mint @12% bg
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0x1F00C6A7), // rgba(0,198,167,.12)
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: MivaltaColors.stateProductive, // #00C6A7
                ),
              ),
              const SizedBox(width: 10),
              // BS-001 Step 1: Title Case, cardTitle token (BS-004: 18px)
              Text(
                title,
                style: MivaltaType.cardTitle.copyWith(
                  color: MivaltaColors.textPrimary,
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
              label,
              style: MivaltaType.small.copyWith(
                color: MivaltaColors.textSecondary,
              ),
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: MivaltaType.metric.copyWith(
                    color: MivaltaColors.textPrimary,
                  ),
                ),
                if (unit != null)
                  TextSpan(
                    text: unit,
                    style: MivaltaType.small.copyWith(
                      color: MivaltaColors.textPrimary.withValues(alpha: 0.5),
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
