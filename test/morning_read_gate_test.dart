// Morning-read courier tests — BS-012 (engine-side verdict since #388).
//
// The salience DECISION table lives in the engine now
// (gatc_viterbi::morning_read_verdict — 8 unit tests + 5 FFI seam tests in
// rust-engine pin these). What Dart owns, and what these tests pin, is the
// COURIER half only:
// - the delivery context read from SharedPreferences (presence token,
//   last-delivered markers, the same-day flag);
// - the mechanical parse of the engine's verdict JSON (verbatim fields,
//   fail-loud on malformed payloads — a broken payload is never coerced
//   into a fire or a silent);
// - the markDelivered round-trip that feeds the next verdict call.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mivalta_flutter/services/morning_read_gate.dart';

Future<MorningReadGate> gateWith(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  return MorningReadGate(prefs: await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('delivery context couriered from prefs', () {
    test('presence defaults to moderate; reads the You-screen pref verbatim',
        () async {
      final fresh = await gateWith({});
      expect(fresh.presenceToken, 'moderate');

      final quiet = await gateWith({'coach_presence': 'quiet'});
      expect(quiet.presenceToken, 'quiet');
    });

    test('last-delivered markers are null before the first delivered read',
        () async {
      final gate = await gateWith({});
      expect(gate.lastDeliveredState, isNull);
      expect(gate.lastDeliveredBucket, isNull);
      expect(gate.alreadyNotifiedToday, isFalse);
    });

    test('markDelivered round-trips state + bucket and arms the same-day flag',
        () async {
      final gate = await gateWith({});
      gate.markDelivered(state: 'Accumulated', calibrationBucket: 'low');

      expect(gate.lastDeliveredState, 'Accumulated');
      expect(gate.lastDeliveredBucket, 'low');
      expect(gate.alreadyNotifiedToday, isTrue,
          reason: 'delivered today → same-day flag couriers true');
    });

    test('a delivery on an earlier date does not arm the same-day flag',
        () async {
      final gate = await gateWith({
        'morning_read_last_state': 'Productive',
        'morning_read_last_date': '2001-01-01',
      });
      expect(gate.alreadyNotifiedToday, isFalse);
    });
  });

  group('verdict JSON parse (mechanical courier, verbatim fields)', () {
    test('fire verdict carries title/body/state/bucket verbatim', () async {
      final gate = await gateWith({});
      final result = gate.parseVerdict(
        '{"fire":true,"reason":"moderate+state_changed",'
        '"state":"Accumulated","sufficiency_bucket":"insufficient",'
        '"title":"Carrying some fatigue","body":"Keep today controlled."}',
      );

      expect(result.shouldFire, isTrue);
      expect(result.title, 'Carrying some fatigue',
          reason: 'card wording verbatim — never the raw token as title');
      expect(result.body, 'Keep today controlled.');
      expect(result.state, 'Accumulated',
          reason: 'raw token kept ONLY as the next last-delivered marker');
      expect(result.sufficiencyBucket, 'insufficient');
      expect(result.reason, 'moderate+state_changed');
      expect(result.stateColor, '#E8C547',
          reason: 'the LOCKED state-palette hex for Accumulated, via tokens');
    });

    test('stateColor pins the LOCKED palette for all five engine states',
        () async {
      // The palette lock (tokens.dart) was previously pinned by the deleted
      // decision-table tests; re-pinned here so a token drift stays loud.
      final gate = await gateWith({});
      const expected = {
        'Recovered': '#7FE3B0',
        'Productive': '#00C6A7',
        'Accumulated': '#E8C547',
        'Overreached': '#CE7B5A',
        'IllnessRisk': '#B85C63',
      };
      for (final entry in expected.entries) {
        final result = gate.parseVerdict(
          '{"fire":true,"reason":"moderate+state_changed",'
          '"state":"${entry.key}","sufficiency_bucket":"low",'
          '"title":"t","body":""}',
        );
        expect(result.stateColor, entry.value,
            reason: '${entry.key} must map to its locked token hex');
      }
    });

    test('silent verdict parses silent with the engine reason', () async {
      final gate = await gateWith({});
      final result = gate.parseVerdict(
        '{"fire":false,"reason":"presence=off","state":null,'
        '"sufficiency_bucket":null,"title":"","body":""}',
      );

      expect(result.shouldFire, isFalse);
      expect(result.reason, 'presence=off');
      expect(result.state, isNull);
      expect(result.stateColor, isNull,
          reason: 'no state → no color, honest absence');
    });

    test('empty body stays empty — no copy invented in the parse', () async {
      final gate = await gateWith({});
      final result = gate.parseVerdict(
        '{"fire":true,"reason":"moderate+calibration","state":"Productive",'
        '"sufficiency_bucket":"low","title":"Making gains","body":""}',
      );
      expect(result.body, '');
    });

    test('malformed payload fails loud — never coerced to a verdict',
        () async {
      final gate = await gateWith({});
      expect(() => gate.parseVerdict('not json'), throwsA(anything));
      expect(() => gate.parseVerdict('{"reason":"x"}'), throwsA(anything),
          reason: 'a payload without "fire" must throw, not default silent');
    });
  });
}
