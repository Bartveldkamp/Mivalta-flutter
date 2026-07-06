// NotificationService unit tests — BS-012 delivery layer.
//
// Covers the pure content/scheduling logic via the kDebugMode preview seam
// (previewMorningRead), which exercises the same title/body/next-delivery
// code paths as scheduleMorningRead WITHOUT touching platform channels.
// Contract pins (adversarial review 2026-07-06):
// - title is the ENGINE state word verbatim — never a fabricated word;
// - body is the engine advisory verbatim, or EMPTY (Dart invents no copy);
// - a silent gate result previews as silent with its reason;
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
    test('title is the engine state word verbatim; body the advisory', () {
      const result = MorningReadResult(
        shouldFire: true,
        stateWord: 'Productive',
        stateColor: '#00C6A7',
        advisoryText: 'Fatigue is trending down.',
        reason: 'moderate+state_changed',
      );

      final preview =
          NotificationService.instance.previewMorningRead(result: result);

      expect(preview, isNotNull);
      expect(preview!['status'], 'scheduled');
      expect(preview['title'], 'Productive'); // engine word, no mapping
      expect(preview['body'], 'Fatigue is trending down.'); // verbatim
      expect(preview['stateColor'], '#00C6A7');
    });

    test('no advisory → EMPTY body, never fabricated copy', () {
      const result = MorningReadResult(
        shouldFire: true,
        stateWord: 'Accumulated',
        stateColor: '#E8C547',
        advisoryText: null,
        reason: 'moderate+calibration',
      );

      final preview =
          NotificationService.instance.previewMorningRead(result: result);

      expect(preview!['status'], 'scheduled');
      expect(preview['title'], 'Accumulated');
      expect(preview['body'], '',
          reason: 'Dart must not invent coach copy when the engine is silent');
    });

    test('silent gate result previews as silent with its reason', () {
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
        stateWord: 'Recovered',
        advisoryText: 'Test',
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
