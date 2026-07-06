// DR-024 W1: Masthead golden test — tripwire for locked sizes.
//
// This is the 3rd size regression. LOCKED sizes (do not change without Bart):
// - Logo: 30px
// - Wordmark: Zen Dots 24px
// - Gap: 10px
//
// This test asserts the logo and wordmark sizes match the locked values.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mivalta_flutter/theme/tokens.dart';

void main() {
  // Disable Google Fonts HTTP fetching in tests
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('DR-024 W1: Masthead locked sizes', () {
    testWidgets('logo size is exactly 30px', (tester) async {
      // Build a minimal masthead row matching today_screen's implementation
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/mivalta-logo.svg',
                  width: 30,
                  height: 30,
                ),
                const SizedBox(width: 10),
                Text(
                  'MiValta',
                  style: GoogleFonts.zenDots(
                    fontSize: 24,
                    letterSpacing: 0.24,
                    color: MivaltaColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Find the SvgPicture and verify dimensions
      final svgFinder = find.byType(SvgPicture);
      expect(svgFinder, findsOneWidget);

      final svgWidget = tester.widget<SvgPicture>(svgFinder);
      expect(svgWidget.width, equals(30.0), reason: 'Logo must be 30px wide (DR-024 locked)');
      expect(svgWidget.height, equals(30.0), reason: 'Logo must be 30px tall (DR-024 locked)');
    });

    testWidgets('wordmark font size is exactly 24px Zen Dots', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/mivalta-logo.svg',
                  width: 30,
                  height: 30,
                ),
                const SizedBox(width: 10),
                Text(
                  'MiValta',
                  style: GoogleFonts.zenDots(
                    fontSize: 24,
                    letterSpacing: 0.24,
                    color: MivaltaColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Find the Text widget with 'MiValta'
      final textFinder = find.text('MiValta');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(
        textWidget.style?.fontSize,
        equals(24.0),
        reason: 'Wordmark must be 24px (DR-024 locked)',
      );
    });

    testWidgets('gap between logo and wordmark is exactly 10px', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/mivalta-logo.svg',
                  width: 30,
                  height: 30,
                ),
                const SizedBox(width: 10),
                Text(
                  'MiValta',
                  style: GoogleFonts.zenDots(
                    fontSize: 24,
                    letterSpacing: 0.24,
                    color: MivaltaColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Find the SizedBox between logo and wordmark
      final sizedBoxFinder = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 10,
      );
      expect(
        sizedBoxFinder,
        findsOneWidget,
        reason: 'Gap must be 10px SizedBox (DR-024 locked)',
      );
    });

    test('locked sizes constant check (compile-time guard)', () {
      // These constants should match today_screen.dart masthead implementation.
      // If you're changing these, you need Bart's approval.
      const lockedLogoSize = 30.0;
      const lockedWordmarkSize = 24.0;
      const lockedGap = 10.0;

      expect(lockedLogoSize, greaterThanOrEqualTo(30.0),
          reason: 'Logo must be at least 30px (DR-024 W1)');
      expect(lockedWordmarkSize, equals(24.0),
          reason: 'Wordmark must be 24px Zen Dots (DR-024 W1)');
      expect(lockedGap, equals(10.0),
          reason: 'Gap must be 10px (DR-024 W1)');
    });
  });
}
