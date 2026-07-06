// NotificationService unit tests — BS-012 delivery layer.
//
// Covers the pure content/scheduling logic via the kDebugMode preview seam
// (previewMorningRead), which exercises the same title/body/next-delivery
// code paths as scheduleMorningRead WITHOUT touching platform channels.
// Contract pins (engine-side verdict since rust-engine #388):
// - title is the ENGINE's card-worded title verbatim — never a fabricated
//   word, never the raw state token assembled in Dart;
// - body is the engine's body verbatim, or EMPTY (Dart invents no copy);
// - a silent verdict previews as silent with its engine reason;
// - next delivery time rolls to tomorrow when today's slot has passed.

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:mivalta_flutter/services/morning_read_gate.dart';
import 'package:mivalta_flutter/services/notification_service.dart';

void main() {
  setUpAll(() {
    // previewMorningRead computes the delivery time via the timezone db;
    // initialize it directly (initialize() would touch platform channels).
    tz.initializeTimeZones();
  });

  group('NotificationService preview (content contract)', () {
    test('title is the engine card-worded title verbatim; body the advisory',
        () {
      const result = MorningReadResult(
        shouldFire: true,
        title: 'Making gains',
        body: 'Fatigue is trending down.',
        state: 'Productive',
        stateColor: '#00C6A7',
        reason: 'moderate+state_changed',
      );

      final preview =
          NotificationService.instance.previewMorningRead(result: result);

      expect(preview, isNotNull);
      expect(preview!['status'], 'scheduled');
      expect(preview['title'], 'Making gains',
          reason: 'the engine card wording verbatim — never the raw token');
      expect(preview['body'], 'Fatigue is trending down.'); // verbatim
      expect(preview['stateColor'], '#00C6A7');
    });

    test('no engine body → EMPTY body, never fabricated copy', () {
      const result = MorningReadResult(
        shouldFire: true,
        title: 'Carrying some fatigue',
        state: 'Accumulated',
        stateColor: '#E8C547',
        body: null,
        reason: 'moderate+calibration',
      );

      final preview =
          NotificationService.instance.previewMorningRead(result: result);

      expect(preview!['status'], 'scheduled');
      expect(preview['title'], 'Carrying some fatigue');
      expect(preview['body'], '',
          reason: 'Dart must not invent coach copy when the engine is silent');
    });

    test('silent verdict previews as silent with its engine reason', () {
      const result = MorningReadResult(
        shouldFire: false,
        reason: 'presence=off',
      );

      final preview =
          NotificationService.instance.previewMorningRead(result: result);

      expect(preview!['status'], 'silent');
      expect(preview['reason'], 'presence=off');
      expect(preview.containsKey('title'), isFalse);
    });

    test('next delivery time is the next 07:00 local, today or tomorrow', () {
      const result = MorningReadResult(
        shouldFire: true,
        title: 'Fully recovered',
        state: 'Recovered',
        body: 'Test',
      );

      final preview =
          NotificationService.instance.previewMorningRead(result: result);
      final scheduled = DateTime.parse(preview!['scheduledTime']!);
      final now = tz.TZDateTime.now(tz.local);

      expect(scheduled.hour, NotificationService.defaultDeliveryHour);
      expect(scheduled.minute, NotificationService.defaultDeliveryMinute);
      expect(scheduled.isAfter(now.subtract(const Duration(minutes: 1))), isTrue,
          reason: 'never schedules into the past');
      expect(
        scheduled.difference(now).inHours <= 24,
        isTrue,
        reason: 'always within the next day',
      );
    });
  });
}
