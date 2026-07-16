// PR-T1 A1 — the readiness_indicator → why-unfold contribution contract, pinned.
//
// The engine emits readiness_indicator.contributions[] as serde-serialized
// `AxisContribution { name, raw_score, weight, weighted }`
// (gatc-viterbi/src/readiness_blend.rs:196-205; axis name literals at
// :498-503 — 'hmm_posteriors', 'banister', 'physio_zscore', 'psychological').
// The widget previously parsed {key, value, weight, direction} — fields the
// engine never emits — so `key` was always null and EVERY row rendered
// "— · pulls nothing" (the A1 finding). These tests pin the real shape on the
// widget side so a field/axis rename on either side fails HERE, not silently
// on an athlete's phone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/copy/today_facts_labels.dart';
import 'package:mivalta_flutter/widgets/today/why_unfold.dart';

Future<void> _pumpUnfold(
  WidgetTester tester,
  List<Map<String, dynamic>> contributions,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WhyUnfold(contributions: contributions),
      ),
    ),
  );
  // Expand the unfold the way the athlete does — tap "Why?".
  await tester.tap(find.text('Why?'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('real engine contribution shape renders its axis label',
      (tester) async {
    await _pumpUnfold(tester, [
      // Verbatim engine shape (AxisContribution, readiness_blend.rs).
      {'name': 'banister', 'raw_score': 0.72, 'weight': 0.3, 'weighted': 0.216},
    ]);

    // The axis_labels.dart dictionary label — the row is a REAL signal row,
    // not the absent fallback.
    expect(find.text('Fitness & freshness'), findsOneWidget,
        reason: "the engine's 'banister' axis must render its human label");
    expect(find.textContaining(kContributionAbsentCopy), findsNothing,
        reason: 'a weighted, known axis must never render "pulls nothing"');
    // raw_score is the rendered row value (1-decimal number format).
    expect(find.text('0.7'), findsOneWidget,
        reason: 'the row value comes from raw_score, verbatim');
  });

  testWidgets('unknown axis name stays honest-absent — never the raw id',
      (tester) async {
    await _pumpUnfold(tester, [
      {
        'name': 'some_future_axis',
        'raw_score': 50.0,
        'weight': 0.25,
        'weighted': 12.5,
      },
    ]);

    // B2: unknown name → '—' label + absence copy, NEVER the engine id.
    expect(find.text('—'), findsOneWidget,
        reason: 'unknown axis label must be the honest em-dash');
    expect(find.textContaining(kContributionAbsentCopy), findsOneWidget,
        reason: 'unknown axis renders the honest-absence copy');
    expect(find.textContaining('some_future_axis'), findsNothing,
        reason: 'raw engine ids are FORBIDDEN user-visible (B2)');
  });
}
