// SessionRecorder — power-sample capture path (Phase 4 cyclist CP stream).
//
// Proves the recorder captures injected power samples at 1 Hz and emits them
// on the CompletedSession, the mirror of the speed path. Uses fakeAsync so the
// 1 Hz sensor timer advances deterministically without real waiting.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/services/session_recorder.dart';

void main() {
  group('SessionRecorder — power capture', () {
    test('captures injected watts at 1 Hz and emits them on stop', () {
      fakeAsync((async) {
        final r = SessionRecorder(sport: 'cycling');
        r.start();

        r.injectPower(250);
        async.elapse(const Duration(seconds: 1));
        r.injectPower(300);
        async.elapse(const Duration(seconds: 1));
        r.injectPower(0); // coasting — kept, not fabricated away.
        async.elapse(const Duration(seconds: 1));

        final done = r.stop();
        expect(done.powerSamples, [250, 300, 0]);
        expect(done.sport, 'cycling');
        r.dispose();
      });
    });

    test('no power injected → honest absence (null powerSamples)', () {
      fakeAsync((async) {
        final r = SessionRecorder(sport: 'cycling');
        r.start();
        async.elapse(const Duration(seconds: 2));
        final done = r.stop();
        expect(done.powerSamples, isNull);
        r.dispose();
      });
    });

    test('speed and power are captured independently', () {
      fakeAsync((async) {
        final r = SessionRecorder(sport: 'running');
        r.start();
        r.injectSpeed(12.0);
        async.elapse(const Duration(seconds: 1));
        final done = r.stop();
        expect(done.speedSamples, [12.0]);
        expect(done.powerSamples, isNull); // never fabricated for a runner.
        r.dispose();
      });
    });
  });
}
