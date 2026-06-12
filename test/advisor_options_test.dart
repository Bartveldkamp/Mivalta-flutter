// Tests for AdvisorOptionsList — lead-with-A / offer-C (founder decision,
// UI_UX_DIRECTION v1.6). Pins the ranked PRESENTATION so a future flatten
// back to an equal-weight menu is caught. Display-only: the engine ranks;
// the widget styles.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/workout_option.dart';
import 'package:mivalta_flutter/screens/advisor_screen.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

WorkoutOption _opt(String id, String title, String zone) =>
    WorkoutOption.fromJson({
      'option_id': id,
      'title': title,
      'zone': zone,
      'why': 'because $id',
      'tags': const <String>[],
    });

Future<void> _pump(WidgetTester tester, List<WorkoutOption> options) =>
    tester.pumpWidget(MaterialApp(
      theme: mivaltaDarkTheme(),
      home: Scaffold(body: AdvisorOptionsList(options: options)),
    ));

void main() {
  final abc = [
    _opt('A', 'Sweet-spot intervals', 'Z4'),
    _opt('B', 'Tempo alternative', 'Z3'),
    _opt('C', 'Easy aerobic spin', 'Z2'),
  ];

  testWidgets('A is led as the recommended session; C offered as easy',
      (tester) async {
    await _pump(tester, abc);

    expect(find.text('RECOMMENDED FOR TODAY'), findsOneWidget);
    expect(find.text('Sweet-spot intervals'), findsOneWidget);
    expect(find.text('or take it easy'), findsOneWidget);
    expect(find.text('Easy aerobic spin'), findsOneWidget);

    // A renders ABOVE C — the lead is not a flat menu.
    final aY = tester.getTopLeft(find.text('Sweet-spot intervals')).dy;
    final cY = tester.getTopLeft(find.text('Easy aerobic spin')).dy;
    expect(aY, lessThan(cY));
  });

  testWidgets('B is de-emphasized behind "More options"', (tester) async {
    await _pump(tester, abc);

    expect(find.text('Tempo alternative'), findsNothing);
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Tempo alternative'), findsOneWidget);
  });

  testWidgets('red-day single option renders led, honestly, no upsell',
      (tester) async {
    await _pump(tester, [_opt('A', 'Rest day', 'R')]);
    expect(find.text('RECOMMENDED FOR TODAY'), findsOneWidget);
    expect(find.text('Rest day'), findsOneWidget);
    expect(find.text('or take it easy'), findsNothing);
    expect(find.text('More options'), findsNothing);
  });

  testWidgets('lead is positional (options.first), even when first is C — '
      'no re-sort, no duplication', (tester) async {
    // Engine contract: options arrive RANKED; the widget must trust position
    // for the lead and never re-sort. On a capped day the engine's top pick
    // can itself be the easy option (id C) — it leads, and the easy section
    // must not duplicate it.
    await _pump(tester, [_opt('C', 'Recovery spin', 'R')]);
    expect(find.text('RECOMMENDED FOR TODAY'), findsOneWidget);
    expect(find.text('Recovery spin'), findsOneWidget); // exactly once
    expect(find.text('or take it easy'), findsNothing);
  });
}
