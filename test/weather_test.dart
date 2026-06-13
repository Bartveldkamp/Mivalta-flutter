// Round 3 items 11+18: weather display + transport tests.
//
// The display widgets take parsed data directly (no channel), so they pump
// without any platform mocking. The service is exercised through a mocked
// `mivalta/weather` MethodChannel — including the honest-absence contract:
// ANY failure returns null, never fabricated conditions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/services/weather_service.dart';
import 'package:mivalta_flutter/theme/tokens.dart';
import 'package:mivalta_flutter/widgets/weather.dart';

WeatherReport seededReport() => WeatherReport(
      symbol: 'cloud.rain',
      condition: 'Rain',
      temperatureC: 11.6,
      daily: [
        const WeatherDay(
          date: '2026-06-12',
          symbol: 'cloud.rain',
          condition: 'Rain',
          highC: 14.4,
          lowC: 8.6,
        ),
        const WeatherDay(
          date: '2026-06-13',
          symbol: 'sun.max',
          condition: 'Clear',
          highC: 18.2,
          lowC: 9.1,
        ),
      ],
    );

void main() {
  group('weatherGlyph (fixed dictionary)', () {
    test('maps Apple SF symbol families to Material glyphs', () {
      expect(weatherGlyph('sun.max'), Icons.wb_sunny_outlined);
      expect(weatherGlyph('cloud.rain'), Icons.water_drop_outlined);
      expect(weatherGlyph('cloud.snow'), Icons.ac_unit);
      expect(weatherGlyph('cloud.bolt.rain'), Icons.bolt);
      expect(weatherGlyph('cloud.fog'), Icons.blur_on);
      expect(weatherGlyph('wind'), Icons.air);
      expect(weatherGlyph('cloud.sun'), Icons.cloud_outlined);
      expect(weatherGlyph('moon.stars'), Icons.nightlight_outlined);
      // Unknown symbol → calm cloud, never a crash.
      expect(weatherGlyph('something.new'), Icons.cloud_outlined);
    });
  });

  // LAST-TWO item 24: the glassy week overlay, one swipeable day per page.
  group('WeatherWeekOverlay (glassy week, item 24)', () {
    Future<void> pumpOverlay(WidgetTester tester, WeatherReport report) =>
        tester.pumpWidget(
          MaterialApp(
            theme: mivaltaDarkTheme(),
            home: Scaffold(body: WeatherWeekOverlay(report: report)),
          ),
        );

    testWidgets('glass per UI_UX §15.5: ONE BackdropFilter, ClipRRect-bound, '
        'solid fallback ALWAYS painted', (tester) async {
      await pumpOverlay(tester, seededReport());

      // The ONE glass surface — a single, never-nested BackdropFilter.
      expect(find.byType(BackdropFilter), findsOneWidget);
      // Bound with ClipRRect (§15.5 mandate).
      expect(
        find.ancestor(
          of: find.byType(BackdropFilter),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
      );
      // Mandatory solid fallback: the semi-opaque fill is painted always,
      // not conditionally — where blur is unavailable the surface still
      // reads as an intentional solid.
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(BackdropFilter),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (container.decoration! as BoxDecoration).color,
        kWeatherGlassFill,
      );
    });

    testWidgets('header + ONE day per page; swiping reveals the next day',
        (tester) async {
      await pumpOverlay(tester, seededReport());

      // Header: current conditions with rounded temperature.
      expect(find.text('12°'), findsOneWidget); // 11.6 rounds to 12
      // Page 1 only — Friday's rain; Saturday stays off-page.
      expect(find.text('Friday'), findsOneWidget); // 2026-06-12
      expect(find.text('14° / 9°'), findsOneWidget); // 14.4 / 8.6
      expect(find.text('18° / 9°'), findsNothing);

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();

      expect(find.text('Saturday'), findsOneWidget); // 2026-06-13
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('18° / 9°'), findsOneWidget); // 18.2 / 9.1
    });

    testWidgets('no daily data → current conditions only, no fabricated '
        'pages', (tester) async {
      final report = WeatherReport(
        symbol: 'sun.max',
        condition: 'Clear',
        temperatureC: 21.0,
        daily: const [],
      );
      await pumpOverlay(tester, report);

      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('21°'), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
      expect(find.textContaining(' / '), findsNothing);
    });
  });

  group('WeatherService (mocked OS channel)', () {
    const channel = MethodChannel('mivalta/weather');
    TestWidgetsFlutterBinding.ensureInitialized();

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('parses a valid OS payload verbatim', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getWeather');
        return {
          'symbol': 'cloud.rain',
          'condition': 'Rain',
          'temperatureC': 11.6,
          'daily': [
            {
              'date': '2026-06-12',
              'symbol': 'cloud.rain',
              'condition': 'Rain',
              'highC': 14.4,
              'lowC': 8.6,
            },
          ],
        };
      });

      final report = await WeatherService.fetch();
      expect(report, isNotNull);
      expect(report!.symbol, 'cloud.rain');
      expect(report.condition, 'Rain');
      expect(report.temperatureC, 11.6);
      expect(report.daily, hasLength(1));
      expect(report.daily.single.date, '2026-06-12');
      expect(report.daily.single.highC, 14.4);
      expect(report.daily.single.lowC, 8.6);
    });

    test('PlatformException (denied/unsupported/WeatherKit error) → null — '
        'honest absence', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'denied');
      });

      expect(await WeatherService.fetch(), isNull);
    });

    test('no handler at all (Android today) → null — honest absence',
        () async {
      expect(await WeatherService.fetch(), isNull);
    });

    test('malformed payload → null, never a half-parsed report', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return {'symbol': 'sun.max'}; // missing condition/temperature
      });

      expect(await WeatherService.fetch(), isNull);
    });
  });
}
