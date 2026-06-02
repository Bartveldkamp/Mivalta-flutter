// MVP-1 smoke test for the ReadinessScreen — the default home.
//
// Engine bindings are Android-only (FRB + libmivalta_rust_bridge.so), so
// this test only verifies the widget tree structure on the host harness.
// The engine-connected behaviour is tested via integration tests on device.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/main.dart';

void main() {
  testWidgets(
    'MivaltaApp renders ReadinessScreen as default home',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MivaltaApp());
      // Render one frame only — engine bootstrap is in flight, do not
      // settle (native libraries are not loadable in the host harness).
      await tester.pump();

      // App bar shows 'MiValta' title (PR-B three-zone home)
      expect(find.text('MiValta'), findsOneWidget);

      // Either loading indicator OR error is shown (on host harness,
      // bootstrap fails synchronously so error surfaces immediately)
      final hasLoader = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      final hasError = find.textContaining('UnsupportedError').evaluate().isNotEmpty;
      expect(hasLoader || hasError, isTrue,
          reason: 'Should show either loading indicator or error');
    },
  );
}
