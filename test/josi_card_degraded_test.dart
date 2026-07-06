// BS-016 B0: Widget test — degraded==true renders identically to degraded==false.
//
// The presenter lock rule: `line.degraded == true` renders IDENTICALLY.
// No branch on `degraded` may reach styling code. This test asserts that
// a degraded line produces the same widget tree structure as a non-degraded one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/models/realized_line.dart';
import 'package:mivalta_flutter/widgets/today/josi_card.dart';

void main() {
  group('BS-016 B0: JosiCard degraded styling', () {
    testWidgets('degraded==true renders identically to degraded==false', (tester) async {
      const testText = 'Your body is ready for a productive session.';
      const testSafety = ['Listen to your body during intense efforts.'];

      // Build with degraded=false
      final normalLine = RealizedLine(
        text: testText,
        safety: testSafety,
        degraded: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JosiCard(realizedLine: normalLine),
          ),
        ),
      );

      // Capture the normal widget tree
      final normalFinder = find.text(testText);
      expect(normalFinder, findsOneWidget, reason: 'Normal line text should render');

      // Get the Text widget's style
      final normalTextWidget = tester.widget<Text>(normalFinder);
      final normalStyle = normalTextWidget.style;

      // Verify safety line renders
      expect(find.text(testSafety.first), findsOneWidget);

      // Now build with degraded=true
      final degradedLine = RealizedLine(
        text: testText,
        safety: testSafety,
        degraded: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JosiCard(realizedLine: degradedLine),
          ),
        ),
      );

      // Capture the degraded widget tree
      final degradedFinder = find.text(testText);
      expect(degradedFinder, findsOneWidget, reason: 'Degraded line text should render');

      // Get the Text widget's style
      final degradedTextWidget = tester.widget<Text>(degradedFinder);
      final degradedStyle = degradedTextWidget.style;

      // ASSERT: Styles must be identical
      expect(
        degradedStyle?.color,
        equals(normalStyle?.color),
        reason: 'Degraded text color must match normal',
      );
      expect(
        degradedStyle?.fontSize,
        equals(normalStyle?.fontSize),
        reason: 'Degraded font size must match normal',
      );
      expect(
        degradedStyle?.fontWeight,
        equals(normalStyle?.fontWeight),
        reason: 'Degraded font weight must match normal',
      );
      expect(
        degradedStyle?.height,
        equals(normalStyle?.height),
        reason: 'Degraded line height must match normal',
      );

      // Verify NO degraded suffix or badge
      expect(
        find.textContaining('limited'),
        findsNothing,
        reason: 'No "limited read" suffix should appear',
      );
      expect(
        find.textContaining('degraded'),
        findsNothing,
        reason: 'No degraded label should appear',
      );

      // Safety line should still render
      expect(find.text(testSafety.first), findsOneWidget);
    });

    testWidgets('empty text returns SizedBox.shrink', (tester) async {
      final emptyLine = RealizedLine(
        text: '',
        safety: const [],
        degraded: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JosiCard(realizedLine: emptyLine),
          ),
        ),
      );

      // Should render as SizedBox.shrink (no container, no text)
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('null realizedLine with fallback renders fallback', (tester) async {
      const fallback = 'Fallback state recommendation.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JosiCard(
              realizedLine: null,
              fallbackLine: fallback,
            ),
          ),
        ),
      );

      expect(find.text(fallback), findsOneWidget);
    });
  });
}
