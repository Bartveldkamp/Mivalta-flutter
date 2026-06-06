// PR-C: ReadinessDetailScreen — deep-dive into the readiness indicator.
//
// Four sections per BETA_BUILD_PACK.md §4:
//   1. AXIS BREAKDOWN — contributions[] bars showing each axis's contribution
//   2. TREND — 30-day readReadinessHistory sparkline
//   3. COACH NOTE — advisories.recommendations[] verbatim
//   4. SOURCE + CONFIDENCE — tier swatch + confidence band + calibration banner
//
// Display-only: every value verbatim from engine. Tokens-only: no inline Colors/hex.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/decoupling_trend.dart';
import '../models/power_curve.dart';
import '../models/training_load.dart';
import '../rust_engine.dart';
import '../theme/source_tier.dart';
import '../theme/tokens.dart';
import '../widgets/analytics/decoupling_card.dart';
import '../widgets/analytics/power_curve_chart.dart';
import '../widgets/analytics/training_load_chart.dart';

/// Humanize axis names for display. Engine field → user-friendly label.
String _humanizeAxisName(String? name) {
  return switch ((name ?? '').toLowerCase()) {
    'hmm_posteriors' => 'Fatigue model',
    'banister' => 'Fitness & freshness',
    'physio_zscore' => 'Body signals',
    'psychological' => 'How you feel',
    _ => name ?? '—',
  };
}

/// Detail screen data from engine
class _DetailData {
  // From readinessIndicator()
  int? score;
  String? level;
  double? confidence;
  List<Map<String, dynamic>> contributions = [];

  // From readinessScore() advisories
  List<String> recommendations = [];

  // From readReadinessHistory(days: 30)
  List<double> historyScores = [];
  List<String> historyDates = [];

  // From readDailyLoads(days: 30) — training-load surface
  TrainingLoad? trainingLoad;

  // From readMmpHistory() — power-profile surface (cycling)
  PowerCurve? powerCurve;

  // From recentDecouplingPct() at 7/14/28-day windows — aerobic-decoupling surface
  DecouplingTrend? decoupling;

  // From lastObservationSourceTier()
  SourceTier? sourceTier;

  // From getStateWidget() — non-null when still calibrating
  String? confidenceAdvisory;

  String? error;
}

class ReadinessDetailScreen extends StatefulWidget {
  const ReadinessDetailScreen({
    super.key,
    required this.handle,
    required this.binding,
  });

  final EnginesHandle handle;
  final RustEngineBinding binding;

  @override
  State<ReadinessDetailScreen> createState() => _ReadinessDetailScreenState();
}

class _ReadinessDetailScreenState extends State<ReadinessDetailScreen> {
  _DetailData _data = _DetailData();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final d = _DetailData();
    try {
      // readinessIndicator() — score, level, confidence, contributions
      final indicatorJson =
          await widget.binding.readinessIndicator(widget.handle);
      final indicator = jsonDecode(indicatorJson) as Map<String, dynamic>;
      final num? score = indicator['score'] as num?;
      d.score = score?.round();
      d.level = indicator['level']?.toString();
      d.confidence = (indicator['confidence'] as num?)?.toDouble();

      final contributions = indicator['contributions'];
      if (contributions is List) {
        d.contributions = contributions
            .whereType<Map<String, dynamic>>()
            .toList();
      }

      // readinessScore() → advisories.recommendations
      final readinessJson = await widget.binding.readinessScore(widget.handle);
      final readiness = jsonDecode(readinessJson) as Map<String, dynamic>;
      final advisories = readiness['advisories'];
      if (advisories is Map) {
        final recs = advisories['recommendations'];
        if (recs is List) {
          d.recommendations = recs.map((e) => e.toString()).toList();
        }
      }

      // readReadinessHistory(days: 30) — for trend sparkline
      final historyJson =
          await widget.binding.readReadinessHistory(widget.handle, days: 30);
      final history = jsonDecode(historyJson);
      if (history is List) {
        for (final e in history) {
          if (e is Map) {
            final s = e['readiness_score'];
            if (s is num) {
              d.historyScores.add(s.toDouble());
              d.historyDates.add(e['date']?.toString() ?? '');
            }
          }
        }
      }

      // readDailyLoads(days: 30) — training-load surface
      final loadsJson =
          await widget.binding.readDailyLoads(widget.handle, days: 30);
      d.trainingLoad = TrainingLoad.fromJson(jsonDecode(loadsJson));

      // readMmpHistory() — power profile (JSON null when no curve yet)
      final mmpJson = await widget.binding.readMmpHistory(widget.handle);
      d.powerCurve = PowerCurve.fromJson(jsonDecode(mmpJson));

      // recentDecouplingPct() at 7/14/28-day windows — aerobic-decoupling trend
      final dc7 = await widget.binding.recentDecouplingPct(widget.handle, windowDays: 7);
      final dc14 = await widget.binding.recentDecouplingPct(widget.handle, windowDays: 14);
      final dc28 = await widget.binding.recentDecouplingPct(widget.handle, windowDays: 28);
      d.decoupling = DecouplingTrend(
        short: DecouplingTrend.parseMean(jsonDecode(dc7)),
        mid: DecouplingTrend.parseMean(jsonDecode(dc14)),
        long: DecouplingTrend.parseMean(jsonDecode(dc28)),
      );

      // lastObservationSourceTier()
      final tierJson =
          await widget.binding.lastObservationSourceTier(widget.handle);
      d.sourceTier = sourceTierFromEngine(jsonDecode(tierJson));

      // getStateWidget() — confidence_advisory for calibration banner
      final stateWidgetJson =
          await widget.binding.getStateWidget(widget.handle);
      final stateWidget = jsonDecode(stateWidgetJson) as Map<String, dynamic>;
      d.confidenceAdvisory = stateWidget['confidence_advisory']?.toString();
    } catch (e) {
      d.error = '${e.runtimeType}: $e';
    }

    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: const Text('Readiness Details'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data.error != null
              ? _ErrorView(error: _data.error!, textTheme: textTheme)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(MivaltaSpace.x4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero score + level
                      _HeroSection(data: _data, textTheme: textTheme),
                      const SizedBox(height: MivaltaSpace.x6),

                      // Section 1: Axis Breakdown
                      _AxisBreakdownSection(
                        contributions: _data.contributions,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: MivaltaSpace.x5),

                      // Section 2: Trend
                      _TrendSection(
                        scores: _data.historyScores,
                        dates: _data.historyDates,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: MivaltaSpace.x5),

                      // Section: Training load (all sports)
                      if (_data.trainingLoad != null) ...[
                        TrainingLoadChart(load: _data.trainingLoad!),
                        const SizedBox(height: MivaltaSpace.x5),
                      ],

                      // Section: Power profile (shown when a power curve exists)
                      if (_data.powerCurve != null &&
                          !_data.powerCurve!.isEmpty) ...[
                        PowerCurveChart(curve: _data.powerCurve!),
                        const SizedBox(height: MivaltaSpace.x5),
                      ],

                      // Section: Aerobic decoupling (shown once a reading exists)
                      if (_data.decoupling != null &&
                          _data.decoupling!.hasData) ...[
                        DecouplingCard(trend: _data.decoupling!),
                        const SizedBox(height: MivaltaSpace.x5),
                      ],

                      // Section 3: Coach Note
                      _CoachNoteSection(
                        recommendations: _data.recommendations,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: MivaltaSpace.x5),

                      // Section 4: Source + Confidence
                      _SourceConfidenceSection(
                        sourceTier: _data.sourceTier,
                        confidence: _data.confidence,
                        confidenceAdvisory: _data.confidenceAdvisory,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: MivaltaSpace.x4),
                    ],
                  ),
                ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.textTheme});
  final String error;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MivaltaSpace.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, color: MivaltaColors.levelRed, size: 48),
            const SizedBox(height: MivaltaSpace.x4),
            SelectableText(error, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Hero section: score + level at top
class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.data, required this.textTheme});
  final _DetailData data;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final color = readinessLevelColor(data.level);
    return Column(
      children: [
        Text(
          '${data.score ?? '—'}',
          style: textTheme.displayLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: MivaltaSpace.x1),
        Text(
          data.level ?? '—',
          style: textTheme.titleMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Section 1: Axis Breakdown — contributions[] as horizontal bars
class _AxisBreakdownSection extends StatelessWidget {
  const _AxisBreakdownSection({
    required this.contributions,
    required this.textTheme,
  });
  final List<Map<String, dynamic>> contributions;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (contributions.isEmpty) {
      return _SectionCard(
        title: 'AXIS BREAKDOWN',
        textTheme: textTheme,
        child: Text(
          'No contribution data available.',
          style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
        ),
      );
    }

    // Find max weighted for scaling
    double maxWeighted = 0;
    for (final c in contributions) {
      final w = (c['weighted'] as num?)?.toDouble() ?? 0;
      if (w > maxWeighted) maxWeighted = w;
    }
    if (maxWeighted <= 0) maxWeighted = 1;

    return _SectionCard(
      title: 'AXIS BREAKDOWN',
      textTheme: textTheme,
      child: Column(
        children: [
          for (final c in contributions) ...[
            _AxisBar(
              name: _humanizeAxisName(c['name']?.toString()),
              rawScore: (c['raw_score'] as num?)?.toDouble(),
              weight: (c['weight'] as num?)?.toDouble(),
              weighted: (c['weighted'] as num?)?.toDouble(),
              maxWeighted: maxWeighted,
              textTheme: textTheme,
            ),
            if (c != contributions.last)
              const SizedBox(height: MivaltaSpace.x3),
          ],
        ],
      ),
    );
  }
}

/// A single axis contribution bar
class _AxisBar extends StatelessWidget {
  const _AxisBar({
    required this.name,
    required this.rawScore,
    required this.weight,
    required this.weighted,
    required this.maxWeighted,
    required this.textTheme,
  });
  final String name;
  final double? rawScore;
  final double? weight;
  final double? weighted;
  final double maxWeighted;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final progress = (weighted ?? 0) / maxWeighted;
    final weightPct = weight != null ? '${(weight! * 100).round()}%' : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                name,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'weight $weightPct',
              style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: MivaltaSpace.x1),
        ClipRRect(
          borderRadius: BorderRadius.circular(MivaltaRadii.sm),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: MivaltaColors.surface2,
            valueColor: AlwaysStoppedAnimation<Color>(MivaltaColors.primaryGreen),
          ),
        ),
        const SizedBox(height: MivaltaSpace.x1),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'raw: ${rawScore?.toStringAsFixed(1) ?? '—'}',
              style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
            ),
            Text(
              'contribution: ${weighted?.toStringAsFixed(1) ?? '—'}',
              style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

/// Section 2: Trend — 30-day history sparkline
class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.scores,
    required this.dates,
    required this.textTheme,
  });
  final List<double> scores;
  final List<String> dates;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'TREND (30 DAYS)',
      textTheme: textTheme,
      child: scores.isEmpty
          ? Text(
              'No history data available.',
              style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 60,
                  child: CustomPaint(
                    painter: _TrendSparklinePainter(scores: scores),
                    size: const Size(double.infinity, 60),
                  ),
                ),
                const SizedBox(height: MivaltaSpace.x2),
                Text(
                  '${scores.length} data points',
                  style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
                ),
              ],
            ),
    );
  }
}

class _TrendSparklinePainter extends CustomPainter {
  _TrendSparklinePainter({required this.scores});
  final List<double> scores;

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final paint = Paint()
      ..color = MivaltaColors.primaryGreen
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = MivaltaColors.primaryGreen.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final range = maxScore - minScore;

    final linePath = Path();
    final fillPath = Path();

    for (var i = 0; i < scores.length; i++) {
      final x = scores.length > 1
          ? (i / (scores.length - 1)) * size.width
          : size.width / 2;
      final normalized = range > 0 ? (scores[i] - minScore) / range : 0.5;
      final y = size.height - (normalized * size.height * 0.8) - size.height * 0.1;

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Close fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Section 3: Coach Note — advisories.recommendations[]
class _CoachNoteSection extends StatelessWidget {
  const _CoachNoteSection({
    required this.recommendations,
    required this.textTheme,
  });
  final List<String> recommendations;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'COACH NOTE',
      textTheme: textTheme,
      child: recommendations.isEmpty
          ? Text(
              'No recommendations at this time.',
              style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final rec in recommendations) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '•',
                        style: textTheme.bodyMedium?.copyWith(
                          color: MivaltaColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: MivaltaSpace.x2),
                      Expanded(
                        child: Text(rec, style: textTheme.bodyMedium),
                      ),
                    ],
                  ),
                  if (rec != recommendations.last)
                    const SizedBox(height: MivaltaSpace.x2),
                ],
              ],
            ),
    );
  }
}

/// Section 4: Source + Confidence — tier swatch + confidence band + calibration banner
class _SourceConfidenceSection extends StatelessWidget {
  const _SourceConfidenceSection({
    required this.sourceTier,
    required this.confidence,
    required this.confidenceAdvisory,
    required this.textTheme,
  });
  final SourceTier? sourceTier;
  final double? confidence;
  final String? confidenceAdvisory;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final confPct = confidence != null ? (confidence! * 100).round() : null;
    // Show banner when engine signals calibration via confidence_advisory (honest-confidence)
    final isLearning = confidenceAdvisory != null;

    return _SectionCard(
      title: 'SOURCE & CONFIDENCE',
      textTheme: textTheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source tier
          Row(
            children: [
              Text(
                'Data source: ',
                style: textTheme.bodyMedium,
              ),
              if (sourceTier != null)
                _SourceTierBadge(tier: sourceTier!)
              else
                Text(
                  'No data yet',
                  style: textTheme.bodyMedium?.copyWith(
                    color: MivaltaColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: MivaltaSpace.x3),

          // Confidence band
          Row(
            children: [
              Text(
                'Confidence: ',
                style: textTheme.bodyMedium,
              ),
              Text(
                confPct != null ? '$confPct%' : '—',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _confidenceColor(confidence),
                ),
              ),
            ],
          ),
          if (confidence != null) ...[
            const SizedBox(height: MivaltaSpace.x2),
            ClipRRect(
              borderRadius: BorderRadius.circular(MivaltaRadii.sm),
              child: LinearProgressIndicator(
                value: confidence!.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: MivaltaColors.surface2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _confidenceColor(confidence),
                ),
              ),
            ),
          ],

          // "Still learning you" calibration banner (honest-confidence)
          if (isLearning) ...[
            const SizedBox(height: MivaltaSpace.x4),
            Container(
              padding: const EdgeInsets.all(MivaltaSpace.x3),
              decoration: BoxDecoration(
                color: MivaltaColors.cautionYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(MivaltaRadii.sm),
                border: Border.all(
                  color: MivaltaColors.cautionYellow.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: MivaltaColors.cautionYellow,
                  ),
                  const SizedBox(width: MivaltaSpace.x2),
                  Expanded(
                    child: Text(
                      'Still learning you — predictions will improve with more data.',
                      style: textTheme.bodySmall?.copyWith(
                        color: MivaltaColors.cautionYellow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _confidenceColor(double? conf) {
    if (conf == null) return MivaltaColors.textMuted;
    if (conf >= 0.8) return MivaltaColors.levelGreen;
    if (conf >= 0.6) return MivaltaColors.levelYellow;
    return MivaltaColors.levelOrange;
  }
}

/// Source tier badge using LOCKED tokens
class _SourceTierBadge extends StatelessWidget {
  const _SourceTierBadge({required this.tier});
  final SourceTier tier;

  @override
  Widget build(BuildContext context) {
    final color = kSourceTierColor[tier]!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MivaltaSpace.x2,
        vertical: MivaltaSpace.x1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(MivaltaRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: MivaltaSpace.x2,
            height: MivaltaSpace.x2,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: MivaltaSpace.x1 + 2),
          Text(
            kSourceTierLabel[tier]!,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Reusable section card with title
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.textTheme,
    required this.child,
  });
  final String title;
  final TextTheme textTheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
            title,
            style: textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: MivaltaColors.textMuted,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          child,
        ],
      ),
    );
  }
}
