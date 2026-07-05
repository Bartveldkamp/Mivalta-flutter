// Morning read gate unit tests — BS-012
//
// Tests the salience gate decision table.
// Contract: ≥9 presence × reason combinations.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mivalta_flutter/services/morning_read_gate.dart';

void main() {
  group('MorningReadGate decision table', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    // Helper to create gate with a specific presence.
    MorningReadGate gateWithPresence(String presence) {
      prefs.setString('coach_presence', presence);
      return MorningReadGate(prefs: prefs);
    }

    // Helper to create engine JSON outputs.
    String indicatorJson(String level) =>
        jsonEncode({'level': level, 'score': 75, 'confidence': 0.8});

    String advisoriesJson(List<String> advisories) => jsonEncode(advisories);

    String stateAdvisoryJson(String text) => jsonEncode({'advisory': text});

    String validationJson(String bucket) =>
        jsonEncode({'sufficiency_bucket': bucket});

    // ══════════════════════════════════════════════════════════════════════
    // PRESENCE = OFF (cases 1–3)
    // ══════════════════════════════════════════════════════════════════════

    test('1. Off + state change + advisory + calibration → silent', () {
      final gate = gateWithPresence('off');
      // Seed previous state.
      prefs.setString('morning_read_last_level', 'Yellow');
      prefs.setString('morning_read_last_date', '2024-01-01');
      prefs.setString('morning_read_last_calibration', 'low');

      final result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Green'),
        pendingAdvisoriesJson: advisoriesJson(['Take it easy']),
        stateAdvisoryJson: stateAdvisoryJson('You are recovered.'),
        validationReportJson: validationJson('medium'),
      );

      expect(result.shouldFire, false, reason: 'Off presence = always silent');
      expect(result.reason, contains('off'));
    });

    test('2. Off + no change + no advisory → silent', () {
      final gate = gateWithPresence('off');

      final result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Green'),
        pendingAdvisoriesJson: advisoriesJson([]),
        stateAdvisoryJson: stateAdvisoryJson(''),
        validationReportJson: validationJson('low'),
      );

      expect(result.shouldFire, false);
    });

    test('3. Off + advisory only → silent', () {
      final gate = gateWithPresence('off');

      final result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Green'),
        pendingAdvisoriesJson: advisoriesJson(['Rest today']),
        stateAdvisoryJson: stateAdvisoryJson('Rest advisory.'),
        validationReportJson: validationJson('low'),
      );

      expect(result.shouldFire, false);
    });

    // ══════════════════════════════════════════════════════════════════════
    // PRESENCE = QUIET (cases 4–6)
    // ══════════════════════════════════════════════════════════════════════

    test('4. Quiet + state change only → silent', () {
      final gate = gateWithPresence('quiet');
      prefs.setString('morning_read_last_level', 'Yellow');
      prefs.setString('morning_read_last_date', '2024-01-01');

      final result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Green'),
        pendingAdvisoriesJson: advisoriesJson([]),
        stateAdvisoryJson: stateAdvisoryJson(''),
        validationReportJson: validationJson('low'),
      );

      expect(result.shouldFire, false,
          reason: 'Quiet ignores state changes');
      expect(result.reason, contains('quiet'));
    });

    test('5. Quiet + advisory → FIRE', () {
      final gate = gateWithPresence('quiet');

      final result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Green'),
        pendingAdvisoriesJson: advisoriesJson(['Take it easy today']),
        stateAdvisoryJson: stateAdvisoryJson('High load this week.'),
        validationReportJson: validationJson('low'),
      );

      expect(result.shouldFire, true, reason: 'Quiet fires for advisories');
      expect(result.stateWord, 'Productive');
      expect(result.stateColor, '#2BD974');
      expect(result.advisoryText, 'High load this week.');
      expect(result.reason, contains('advisory'));
    });

    test('6. Quiet + calibration change only → silent', () {
      final gate = gateWithPresence('quiet');
      prefs.setString('morning_read_last_calibration', 'low');
      prefs.setString('morning_read_last_date', '2024-01-01');

      final result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Green'),
        pendingAdvisoriesJson: advisoriesJson([]),
        stateAdvisoryJson: stateAdvisoryJson(''),
        validationReportJson: validationJson('medium'),
      );

      expect(result.shouldFire, false,
          reason: 'Quiet ignores calibration changes');
    });

    // ══════════════════════════════════════════════════════════════════════
    // PRESENCE = MODERATE (cases 7–12)
    // ══════════════════════════════════════════════════════════════════════

    test('7. Moderate + state change → FIRE', () {
      final gate = gateWithPresence('moderate');
      prefs.setString('morning_read_last_level', 'Yellow');
      prefs.setString('morning_read_last_date', '2024-01-01');

      final result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Green'),
        pendingAdvisoriesJson: advisoriesJson([]),
        stateAdvisoryJson: stateAdvisoryJson('You recovered overnight.'),
        validationReportJson: validationJson('low'),
      );

      expect(result.shouldFire, true,
          reason: 'Moderate fires for state changes');
      expect(result.stateWord, 'Productive');
      expect(result.reason, contains('state_changed'));
    });

    test('8. Moderate + advisory → FIRE', () {
      final gate = gateWithPresence('moderate');

      final result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Yellow'),
        pendingAdvisoriesJson: advisoriesJson(['Consider rest']),
        stateAdvisoryJson: stateAdvisoryJson('Fatigue accumulating.'),
        validationReportJson: validationJson('low'),
      );

      expect(result.shouldFire, true,
          reason: 'Moderate fires for advisories');
      expect(result.stateWord, 'Accumulated');
      expect(result.stateColor, '#E6872F');
      expect(result.reason, contains('advisory'));
    });

    test('9. Moderate + calibration milestone → FIRE', () {
      final gate = gateWithPresence('moderate');
      prefs.setString('morning_read_last_calibration', 'low');
      prefs.setString('morning_read_last_date', '2024-01-01');

      final result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Green'),
        pendingAdvisoriesJson: advisoriesJson([]),
        stateAdvisoryJson: stateAdvisoryJson('Your readings are validated.'),
        validationReportJson: validationJson('medium'),
      );

      expect(result.shouldFire, true,
          reason: 'Moderate fires for calibration milestones');
      expect(result.reason, contains('calibration'));
    });

    test('10. Moderate + no change + no advisory + no calibration → silent', () {
      final gate = gateWithPresence('moderate');
      // Same level as last time.
      prefs.setString('morning_read_last_level', 'Green');
      prefs.setString('morning_read_last_calibration', 'low');

      final result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Green'),
        pendingAdvisoriesJson: advisoriesJson([]),
        stateAdvisoryJson: stateAdvisoryJson(''),
        validationReportJson: validationJson('low'),
      );

      expect(result.shouldFire, false,
          reason: 'Nothing to report = silence');
      expect(result.reason, contains('no_change'));
    });

    test('11. Moderate + state change same day → silent (already notified)', () {
      final gate = gateWithPresence('moderate');
      // Set last date to today.
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      prefs.setString('morning_read_last_level', 'Yellow');
      prefs.setString('morning_read_last_date', todayStr);

      final result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Green'),
        pendingAdvisoriesJson: advisoriesJson([]),
        stateAdvisoryJson: stateAdvisoryJson(''),
        validationReportJson: validationJson('low'),
      );

      expect(result.shouldFire, false,
          reason: 'Already notified today');
    });

    // ══════════════════════════════════════════════════════════════════════
    // EDGE CASES (cases 12–15)
    // ══════════════════════════════════════════════════════════════════════

    test('12. Missing state word → silent even with reasons', () {
      final gate = gateWithPresence('moderate');

      final result = gate.evaluate(
        readinessIndicatorJson: null, // No indicator data.
        pendingAdvisoriesJson: advisoriesJson(['Something']),
        stateAdvisoryJson: stateAdvisoryJson('Advisory'),
        validationReportJson: validationJson('low'),
      );

      expect(result.shouldFire, false,
          reason: 'No state word = cannot compose notification');
    });

    test('13. Default presence (not set) = moderate', () {
      // Don't set presence.
      final gate = MorningReadGate(prefs: prefs);
      prefs.setString('morning_read_last_level', 'Yellow');
      prefs.setString('morning_read_last_date', '2024-01-01');

      final result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Green'),
        pendingAdvisoriesJson: advisoriesJson([]),
        stateAdvisoryJson: stateAdvisoryJson('Good morning.'),
        validationReportJson: validationJson('low'),
      );

      expect(result.shouldFire, true,
          reason: 'Default presence is moderate');
    });

    test('14. All state levels map to correct words and colors', () {
      final gate = gateWithPresence('moderate');
      prefs.setString('morning_read_last_level', 'Red');
      prefs.setString('morning_read_last_date', '2024-01-01');

      // Green → Productive.
      var result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Green'),
        pendingAdvisoriesJson: advisoriesJson([]),
        stateAdvisoryJson: stateAdvisoryJson('Test'),
        validationReportJson: validationJson('low'),
      );
      expect(result.stateWord, 'Productive');
      expect(result.stateColor, '#2BD974');

      // Yellow → Accumulated.
      prefs.setString('morning_read_last_level', 'Green');
      result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Yellow'),
        pendingAdvisoriesJson: advisoriesJson([]),
        stateAdvisoryJson: stateAdvisoryJson('Test'),
        validationReportJson: validationJson('low'),
      );
      expect(result.stateWord, 'Accumulated');
      expect(result.stateColor, '#E6872F');

      // Orange → Fatigued.
      prefs.setString('morning_read_last_level', 'Yellow');
      result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Orange'),
        pendingAdvisoriesJson: advisoriesJson([]),
        stateAdvisoryJson: stateAdvisoryJson('Test'),
        validationReportJson: validationJson('low'),
      );
      expect(result.stateWord, 'Fatigued');
      expect(result.stateColor, '#E65C2F');

      // Red → Overreached.
      prefs.setString('morning_read_last_level', 'Orange');
      result = gate.evaluate(
        readinessIndicatorJson: indicatorJson('Red'),
        pendingAdvisoriesJson: advisoriesJson([]),
        stateAdvisoryJson: stateAdvisoryJson('Test'),
        validationReportJson: validationJson('low'),
      );
      expect(result.stateWord, 'Overreached');
      expect(result.stateColor, '#E63946');
    });

    test('15. markDelivered persists state for next evaluation', () {
      final gate = gateWithPresence('moderate');

      gate.markDelivered(level: 'Green', calibrationBucket: 'high');

      expect(prefs.getString('morning_read_last_level'), 'Green');
      expect(prefs.getString('morning_read_last_calibration'), 'high');
      expect(prefs.getString('morning_read_last_date'), isNotNull);
    });
  });
}
