// Day-3 BLOCKER 5: cover the new RustEngineBinding facade without
// loading the native shim. Asserts:
//   (1) bootstrap() refuses to run on non-Android hosts (Day-2
//       WARNING 3 fix — Platform.isAndroid gate).
//   (2) The BridgeError sealed class has the exact six variant
//       subclasses the brief specified, all constructible from
//       Dart, all instances of FrbException.
//   (3) Variant payloads round-trip through pattern matching, so
//       Dart callers can switch on variant safely.
//
// Forwarding semantics of the five FFI methods are not exercised:
// each facade method is one line of `return rust_api.foo(handle:
// handle);`. A full forwarding test would require a hand-rolled
// fake of `RustLibApi` (an FRB-generated abstract class with the
// full FFI surface). The behaviour is covered end-to-end by the
// device smoketest screen instead — that's the productive
// boundary, and the host-side fake would only re-test FRB's own
// dispatch.

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show FrbException;
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/rust_engine.dart';
// Variant subclasses live in the FRB-generated source; the public
// facade only re-exports the sealed base class. Importing the
// generated module here is test-only — production code catches
// `BridgeError` and pattern-matches without naming subclasses.
import 'package:mivalta_flutter/src/rust/api.dart'
    show
        BridgeError_LibraryNotLoaded,
        BridgeError_EngineConstructionFailed,
        BridgeError_VaultError,
        BridgeError_InputError,
        BridgeError_StateError,
        BridgeError_RoundTripFailed,
        BridgeError_InvalidDate;

void main() {
  group('RustEngineBinding.bootstrap()', () {
    test('throws UnsupportedError on non-Android host', () async {
      // The test runner is Linux/macOS — Platform.isAndroid is false,
      // so the bootstrap gate fires before any FFI call.
      await expectLater(
        RustEngineBinding.bootstrap(),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('BridgeError variants', () {
    test('LibraryNotLoaded is a parameter-less FrbException', () {
      const e = BridgeError.libraryNotLoaded();
      expect(e, isA<FrbException>());
    });

    test('EngineConstructionFailed carries a String payload', () {
      const e = BridgeError.engineConstructionFailed('viterbi: nope');
      expect(e, isA<FrbException>());
      switch (e) {
        case BridgeError_EngineConstructionFailed(:final field0):
          expect(field0, 'viterbi: nope');
        default:
          fail('expected EngineConstructionFailed pattern to match');
      }
    });

    test('VaultError carries a String payload', () {
      const e = BridgeError.vaultError('db locked');
      expect(e, isA<BridgeError_VaultError>());
      expect((e as BridgeError_VaultError).field0, 'db locked');
    });

    test('InputError carries a String payload', () {
      const e = BridgeError.inputError('bad json');
      expect(e, isA<BridgeError_InputError>());
      expect((e as BridgeError_InputError).field0, 'bad json');
    });

    test('StateError carries a String payload (also folds Policy/Consistency)', () {
      // Shim's From<gatc_ffi::BridgeError> folds upstream Policy and
      // Consistency variants into StateError with a prefix; this
      // checks the payload survives intact.
      const e = BridgeError.stateError('policy: gating denied');
      expect(e, isA<BridgeError_StateError>());
      expect((e as BridgeError_StateError).field0, 'policy: gating denied');
    });

    test('RoundTripFailed carries a String payload', () {
      const e = BridgeError.roundTripFailed('serde drift');
      expect(e, isA<BridgeError_RoundTripFailed>());
      expect((e as BridgeError_RoundTripFailed).field0, 'serde drift');
    });

    test('InvalidDate (Day-7) carries a String payload', () {
      const e = BridgeError.invalidDate('2026-13-99: bad month');
      expect(e, isA<BridgeError_InvalidDate>());
      expect((e as BridgeError_InvalidDate).field0, '2026-13-99: bad month');
    });

    test('switch on BridgeError is exhaustive', () {
      // The compiler enforces exhaustiveness for sealed classes;
      // exercising every branch here is the regression check.
      String tag(BridgeError e) {
        switch (e) {
          case BridgeError_LibraryNotLoaded():
            return 'lib';
          case BridgeError_EngineConstructionFailed():
            return 'ctor';
          case BridgeError_VaultError():
            return 'vault';
          case BridgeError_InputError():
            return 'input';
          case BridgeError_StateError():
            return 'state';
          case BridgeError_RoundTripFailed():
            return 'roundtrip';
          case BridgeError_InvalidDate():
            return 'invaliddate';
        }
      }

      expect(tag(const BridgeError.libraryNotLoaded()), 'lib');
      expect(tag(const BridgeError.engineConstructionFailed('x')), 'ctor');
      expect(tag(const BridgeError.vaultError('x')), 'vault');
      expect(tag(const BridgeError.inputError('x')), 'input');
      expect(tag(const BridgeError.stateError('x')), 'state');
      expect(tag(const BridgeError.roundTripFailed('x')), 'roundtrip');
      expect(tag(const BridgeError.invalidDate('x')), 'invaliddate');
    });
  });
}
