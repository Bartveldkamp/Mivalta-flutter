// DR-024 W1: Masthead golden tests.
//
// Locks the visual appearance of the masthead widget against golden files.
// Three variants:
//   1. No weather (honest absence)
//   2. Sunny weather with temperature
//   3. Rain weather with temperature
//
// Run `flutter test --update-goldens` to regenerate golden files.
//
// Note: Golden tests require local fonts and are skipped in CI unless
// fonts are bundled. Widget behavior tests always run.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mivalta_flutter/services/weather_service.dart';
import 'package:mivalta_flutter/theme/tokens.dart';
import 'package:mivalta_flutter/widgets/today/masthead.dart';

void main() {
  // Disable HTTP font fetching in tests — use bundled/default fonts only.
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  // Golden tests are skipped in CI/headless — they require bundled Google Fonts
  // assets which aren't available in unit tests. Run these manually with
  // `flutter test --update-goldens` on a machine with network access to create
  // the baseline images, then commit the goldens/ directory.
  //
  // The widget behavior is fully tested below in the "TodayMasthead widget tests"
  // group, which does not depend on font rendering.
  group('TodayMasthead golden tests', skip: 'Requires bundled fonts; run manually with --update-goldens', () {
    // Wrap widget in a constrained container with dark background for golden
    Widget buildTestWidget({WeatherReport? weather}) {
      return MaterialApp(
        theme: mivaltaDarkTheme(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: MivaltaColors.surfaceBackground,
          body: SafeArea(
            child: SizedBox(
              width: 390, // iPhone 14 width
              child: TodayMasthead(
                onStartWorkout: () {},
                weather: weather,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('masthead without weather matches golden', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(TodayMasthead),
        matchesGoldenFile('goldens/masthead_no_weather.png'),
      );
    });

    testWidgets('masthead with sunny weather matches golden', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        weather: const WeatherReport(
          symbol: 'sun.max',
          condition: 'Sunny',
          temperatureC: 22,
          daily: [],
        ),
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(TodayMasthead),
        matchesGoldenFile('goldens/masthead_sunny.png'),
      );
    });

    testWidgets('masthead with rain weather matches golden', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        weather: const WeatherReport(
          symbol: 'cloud.rain',
          condition: 'Rain',
          temperatureC: 14,
          daily: [],
        ),
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(TodayMasthead),
        matchesGoldenFile('goldens/masthead_rain.png'),
      );
    });
  });

  group('TodayMasthead widget tests', () {
    testWidgets('renders MiValta wordmark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mivaltaDarkTheme(),
          home: Scaffold(
            body: TodayMasthead(
              onStartWorkout: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MiValta'), findsOneWidget);
    });

    testWidgets('renders Start workout button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mivaltaDarkTheme(),
          home: Scaffold(
            body: TodayMasthead(
              onStartWorkout: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start workout'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('Start workout button triggers callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: mivaltaDarkTheme(),
          home: Scaffold(
            body: TodayMasthead(
              onStartWorkout: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start workout'));
      expect(tapped, isTrue);
    });

    testWidgets('weather slot shows nothing when weather is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mivaltaDarkTheme(),
          home: Scaffold(
            body: TodayMasthead(
              onStartWorkout: () {},
              weather: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No weather text should appear
      expect(find.textContaining('°'), findsNothing);
    });

    testWidgets('weather slot shows condition and temperature', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mivaltaDarkTheme(),
          home: Scaffold(
            body: TodayMasthead(
              onStartWorkout: () {},
              weather: const WeatherReport(
                symbol: 'sun.max',
                condition: 'Sunny',
                temperatureC: 22.7,
                daily: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show "Sunny 23°" (rounded)
      expect(find.text('Sunny 23°'), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    });

    testWidgets('weather symbol mapping: cloud.rain shows grain icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mivaltaDarkTheme(),
          home: Scaffold(
            body: TodayMasthead(
              onStartWorkout: () {},
              weather: const WeatherReport(
                symbol: 'cloud.rain',
                condition: 'Rain',
                temperatureC: 12,
                daily: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rain 12°'), findsOneWidget);
      expect(find.byIcon(Icons.grain), findsOneWidget);
    });
  });
}
