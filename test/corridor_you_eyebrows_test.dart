// BS-017 stage 2 — golden corridor invariant #2: YOU EYEBROWS, EXACT.
//
// The REAL YouScreen, pumped headless with the stage-1 seam, renders exactly
// the eyebrow set the code carries (verified against lib/screens/
// you_screen.dart this session: 'WHO YOU ARE' L455, 'LEARNING YOU' L486,
// 'YOUR SOURCES' L531, 'YOUR DATA, YOUR DEVICE' L614, 'HOW MIVALTA SPEAKS'
// L694, 'DISPLAY' L756 — the BS-017 spec list matches source 1:1, no delta).
// This is the exact contract the F3 'YOUR BODY' bug violated.
//
// Also pinned: the sovereignty promise banner is present (verbatim), and the
// erase row is red-styled (the stateOverreached token — pinning the LOCKED
// token is the point here).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/screens/you_screen.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

import 'support/fake_engine_binding.dart';
import 'support/headless_env.dart';

/// The exact eyebrow set the You screen renders, in source order.
const List<String> kYouEyebrows = [
  'WHO YOU ARE',
  'LEARNING YOU',
  'YOUR SOURCES',
  'YOUR DATA, YOUR DEVICE',
  'HOW MIVALTA SPEAKS',
  'DISPLAY',
];

/// The sovereignty promise banner, verbatim from you_screen.dart.
const String kSovereigntyPromise =
    'Computed on your phone. Your health data never leaves this '
    'device, and it is never in your phone backups. To move it '
    'to a new phone, use the encrypted export.';

void main() {
  Future<void> pumpYou(WidgetTester tester) async {
    await installHeadlessEnv(tester, profileJson: kTestProfileJson);
    useTallTestViewport(tester);
    final binding = FakeEngineBinding(canned: cannedCorridorDefaults());
    await tester.pumpWidget(MaterialApp(
      home: YouScreen(binding: binding, handle: binding.handle),
    ));
    await pumpUntilLoaded(tester);
  }

  testWidgets('You renders the exact eyebrow set — each exactly once',
      (tester) async {
    await pumpYou(tester);

    for (final eyebrow in kYouEyebrows) {
      expect(find.text(eyebrow), findsOneWidget,
          reason: 'eyebrow "$eyebrow" must render exactly once, verbatim');
    }

    // The F3 regression tripwire: the bug wording must never come back.
    expect(find.text('YOUR BODY'), findsNothing,
        reason: 'F3 bug wording — the eyebrow is WHO YOU ARE, '
            'never YOUR BODY');
  });

  testWidgets('sovereignty banner present with the verbatim promise',
      (tester) async {
    await pumpYou(tester);

    expect(find.text(kSovereigntyPromise), findsOneWidget,
        reason: 'the sovereignty promise renders verbatim — '
            'no paraphrase, no softening');
  });

  testWidgets('erase row is red-styled (stateOverreached token)',
      (tester) async {
    await pumpYou(tester);

    final eraseFinder = find.text('Erase everything');
    expect(eraseFinder, findsOneWidget);

    final eraseText = tester.widget<Text>(eraseFinder);
    expect(eraseText.style?.color, MivaltaColors.stateOverreached,
        reason: 'the erase row is the red moment — '
            'MivaltaColors.stateOverreached, by token');
  });
}
