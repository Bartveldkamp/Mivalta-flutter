// Why? unfold — the evidence layer under Josi.
//
// BS-007 Step 2: A "Why?" affordance that reveals readiness_indicator.contributions[].
// Each row: label (left) · value (right, tabular) · direction glyph ('—'
// until the engine emits a direction field — cross-repo, Law 8).
// Labels go through a fixed dictionary (axis_labels.dart).
// Absent/zero-weight signal → "—  · pulls nothing".
// Empty contributions → Why? affordance does not render at all.
//
// Motion (M3): rows animate FROM hidden (opacity 0, y −6) to visible,
// 150ms each, 90ms stagger. Respect disableAnimations → instant appearance.

import 'package:flutter/material.dart';

import '../../copy/axis_labels.dart';
import '../../copy/today_facts_labels.dart';
import '../../theme/tokens.dart';

/// The Why? unfold widget — expandable evidence layer.
class WhyUnfold extends StatefulWidget {
  const WhyUnfold({
    super.key,
    required this.contributions,
    this.confidenceText,
  });

  /// Readiness contributions from the engine — list of
  /// {name, raw_score, weight, weighted}: serde-serialized `AxisContribution`
  /// (gatc-viterbi/src/readiness_blend.rs), couriered verbatim.
  final List<Map<String, dynamic>> contributions;

  /// Optional confidence sentence to show below the rows.
  final String? confidenceText;

  @override
  State<WhyUnfold> createState() => _WhyUnfoldState();
}

class _WhyUnfoldState extends State<WhyUnfold> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: MivaltaMotion.fast,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Empty contributions → don't render the affordance at all
    if (widget.contributions.isEmpty) {
      return const SizedBox.shrink();
    }

    final reducedMotion = MediaQuery.of(context).disableAnimations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Why? affordance — tap to toggle
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44), // min hit target
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Why?',
                  style: MivaltaType.small.copyWith(
                    color: MivaltaColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: MivaltaMotion.fast,
                  child: Icon(
                    Icons.expand_more,
                    size: 18,
                    color: MivaltaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded content
        SizeTransition(
          sizeFactor: _expandAnimation,
          // ignore: deprecated_member_use
          axisAlignment: -1.0, // align to top (deprecated but alignment replacement not available)
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contribution rows
              ...widget.contributions.asMap().entries.map((entry) {
                final index = entry.key;
                final contrib = entry.value;
                return _ContributionRow(
                  contribution: contrib,
                  index: index,
                  reducedMotion: reducedMotion,
                  isExpanded: _expanded,
                );
              }),

              // Confidence sentence (if present)
              if (widget.confidenceText != null && widget.confidenceText!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.confidenceText!,
                  style: MivaltaType.small.copyWith(
                    color: MivaltaColors.textMuted,
                  ),
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single contribution row with staggered entrance animation.
class _ContributionRow extends StatefulWidget {
  const _ContributionRow({
    required this.contribution,
    required this.index,
    required this.reducedMotion,
    required this.isExpanded,
  });

  final Map<String, dynamic> contribution;
  final int index;
  final bool reducedMotion;
  final bool isExpanded;

  @override
  State<_ContributionRow> createState() => _ContributionRowState();
}

class _ContributionRowState extends State<_ContributionRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();

    // Stagger delay: 90ms per row (beatStagger ÷ 3)
    final staggerDelay = Duration(
      milliseconds: widget.index * (MivaltaMotion.beatStagger.inMilliseconds ~/ 3),
    );

    _controller = AnimationController(
      vsync: this,
      duration: MivaltaMotion.fast,
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _offset = Tween<Offset>(
      begin: const Offset(0, -6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.isExpanded) {
      if (widget.reducedMotion) {
        _controller.value = 1.0;
      } else {
        Future.delayed(staggerDelay, () {
          if (mounted) _controller.forward();
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant _ContributionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        if (widget.reducedMotion) {
          _controller.value = 1.0;
        } else {
          final staggerDelay = Duration(
            milliseconds: widget.index * (MivaltaMotion.beatStagger.inMilliseconds ~/ 3),
          );
          Future.delayed(staggerDelay, () {
            if (mounted) _controller.forward();
          });
        }
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.contribution['name'] as String?;
    final rawScore = widget.contribution['raw_score'];
    final weight = widget.contribution['weight'];

    // Label from dictionary — unknown → null
    final label = humanizeAxisName(name);

    // Determine if this is an absent/zero-weight signal
    final isAbsent = label == null || weight == 0 || weight == null;

    // Format the value
    final valueStr = _formatValue(rawScore, isAbsent);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _offset.value,
          child: Opacity(
            opacity: _opacity.value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // Label (left)
            // B2: Unknown key → '—', never the raw engine key
            Expanded(
              child: Text(
                label ?? '—',
                style: MivaltaType.small.copyWith(
                  color: isAbsent ? MivaltaColors.textMuted : MivaltaColors.textSecondary,
                ),
              ),
            ),

            // Value (right, tabular)
            if (isAbsent)
              Text(
                '—  · $kContributionAbsentCopy',
                style: MivaltaType.small.copyWith(
                  color: MivaltaColors.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )
            else ...[
              Text(
                valueStr,
                style: MivaltaType.small.copyWith(
                  color: MivaltaColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              // Direction glyph: the engine's AxisContribution carries no
              // direction field — honest '—' until an engine-emitted
              // direction exists (cross-repo, Law 8); Dart derives nothing
              // (Law 2).
              Text(
                '—',
                style: MivaltaType.small.copyWith(
                  color: MivaltaColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatValue(dynamic value, bool isAbsent) {
    if (isAbsent || value == null) return '—';
    if (value is num) {
      // Format as integer or 1 decimal
      if (value == value.toInt()) {
        return value.toInt().toString();
      }
      return value.toStringAsFixed(1);
    }
    return value.toString();
  }
}
