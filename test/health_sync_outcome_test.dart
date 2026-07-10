// D1 — the health-store sync honest-absence rule.
//
// classifyHealthSync must NOT trust the (iOS-unreliable) permission query: it
// decides off "attempted + nothing landed", so a HealthKit READ denial — which
// iOS reports as an empty result, not a denial — still surfaces the connect
// affordance rather than a fabricated reading or an error state.

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/services/health_ingest.dart';

void main() {
  group('classifyHealthSync — honest-absence rule', () {
    test('fresh observations landed → refreshed', () {
      const r = HealthSyncResult(success: true, observationsProcessed: 3);
      expect(classifyHealthSync(r), HealthSyncOutcome.refreshed);
    });

    test('workout-only sync (0 obs, 1 workout) still landed → refreshed', () {
      const r = HealthSyncResult(
        success: true,
        observationsProcessed: 0,
        workoutsProcessed: 1,
      );
      expect(classifyHealthSync(r), HealthSyncOutcome.refreshed);
    });

    test('explicit denial → needsConnect', () {
      expect(
        classifyHealthSync(HealthSyncResult.denied),
        HealthSyncOutcome.needsConnect,
      );
    });

    test('granted-but-empty (iOS denial masquerades as no-data) → needsConnect',
        () {
      expect(
        classifyHealthSync(HealthSyncResult.noData),
        HealthSyncOutcome.needsConnect,
      );
    });

    test('success but nothing landed → needsConnect', () {
      const r = HealthSyncResult(success: true, observationsProcessed: 0);
      expect(classifyHealthSync(r), HealthSyncOutcome.needsConnect);
    });

    test('real failure (error, not a denial) → unchanged — keep prior data', () {
      const r = HealthSyncResult(
        success: false,
        observationsProcessed: 0,
        error: 'plugin timeout',
      );
      expect(classifyHealthSync(r), HealthSyncOutcome.unchanged);
    });
  });
}
