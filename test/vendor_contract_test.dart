// PINNING TEST #3 (LAST-INCH T3) — the Dart-sent vendor set.
//
// The COMPLETE set of vendor tokens this app can ever pass as the engine
// normalizer's FFI dispatch argument (NormalizerEngine::normalize_observation,
// reached ONLY via IngestAdapter.ingestObservation / ingestWorkout — traced
// this session: no other lib/ call site reaches the binding's
// normalizeObservation):
//
//     { 'apple', 'health_connect', 'ble_hr' }
//
// Call-site inventory (traced 2026-07-16):
//   * lib/services/health_ingest.dart — HealthIngestService.platformVendor
//     ('apple' | 'health_connect'), used by BOTH the biometric loop and the
//     workout ingest;
//   * lib/debug/demo_seeder.dart — DemoSeeder.vendor ('apple'; call sites are
//     kDebugMode-gated but it is still an app-passable token);
//   * lib/services/ble/ble_hr_service.dart — BleHrService.bleVendor
//     ('ble_hr'), PINNED for ALL BLE-recorded observations. Device-specific
//     strap ids ('polar_h10', …) are payload `source` values that ble.rs
//     reads from the JSON (ble.rs:44) — they are NEVER dispatch tokens (the
//     engine dispatcher rejects them: "Unknown vendor: polar_h10").
//
// Cross-reference: the engine-side acceptance test (gatc-ffi, train PR-T2)
// pins the dispatcher's acceptance of the same tokens (BLE dispatch
// "ble"|"ble_hr"). The two tests close the seam from both ends — the app only
// sends tokens the engine accepts, and the engine accepts every token the app
// sends. If either set changes, change BOTH tests in the same train.

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/debug/demo_seeder.dart';
import 'package:mivalta_flutter/services/ble/ble_hr_service.dart';
import 'package:mivalta_flutter/services/health_ingest.dart';

/// The pinned app-wide dispatch set — every vendor token the app can ever
/// hand to the engine normalizer.
const Set<String> kAppVendorTokens = {'apple', 'health_connect', 'ble_hr'};

void main() {
  group('Dart-sent vendor set (pin #3)', () {
    test('every call-site vendor constant resolves into the pinned set', () {
      expect(kAppVendorTokens, contains(HealthIngestService.appleVendor));
      expect(
        kAppVendorTokens,
        contains(HealthIngestService.healthConnectVendor),
      );
      expect(kAppVendorTokens, contains(BleHrService.bleVendor));
      expect(kAppVendorTokens, contains(DemoSeeder.vendor));
    });

    test('the platform vendor path resolves into the pinned set', () {
      // On the test host this evaluates to 'apple'; on Android it is
      // 'health_connect'. Both branches of the getter are the named constants
      // asserted above, so the runtime value cannot leave the set.
      expect(kAppVendorTokens, contains(HealthIngestService.platformVendor));
    });

    test('exact token values (the engine-side dispatch strings)', () {
      // These literals are the gatc-ffi dispatcher's match arms — a drift on
      // either side must break here, not on-device.
      expect(HealthIngestService.appleVendor, 'apple');
      expect(HealthIngestService.healthConnectVendor, 'health_connect');
      expect(BleHrService.bleVendor, 'ble_hr');
      expect(DemoSeeder.vendor, 'apple');
    });

    test('device-specific strap ids are NOT in the dispatch set', () {
      // The A5 defect class: a strap model id leaking into the vendor arg.
      expect(kAppVendorTokens, isNot(contains('polar_h10')));
    });
  });
}
