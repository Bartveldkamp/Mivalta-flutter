// Tests for the A1 airplane-mode privacy moment (NEXT_UPDATE_V2_ADOPTIONS).
//
// Onboarding's final step: the on-device privacy proof. Pins the founder's
// copy (draft — flagged for founder review before lock) and that the page is
// informational only (no inputs).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/screens/onboarding_screen.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

void main() {
  group('PrivacyMomentPage (A1)', () {
    testWidgets('presents the airplane-mode privacy proof copy', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: const Scaffold(body: PrivacyMomentPage()),
      ));

      expect(find.byIcon(Icons.airplanemode_active), findsOneWidget);
      expect(find.text('Turn on airplane mode.'), findsOneWidget);
      expect(
        find.text(
          'Watch: the engine still works. Your data never leaves this phone.',
        ),
        findsOneWidget,
      );
      // The on-device proof framing: engine boot happens right after this page.
      expect(find.textContaining('No cloud. No account.'), findsOneWidget);
    });

    testWidgets('informational only — no inputs on the privacy moment', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: const Scaffold(body: PrivacyMomentPage()),
      ));

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
    });
  });
}
