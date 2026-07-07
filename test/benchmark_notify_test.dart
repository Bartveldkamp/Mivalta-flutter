// Phase 3 — benchmark-change notify: model parse + service + widget.
//
// Pins: the card is the engine's composed output rendered verbatim (headline,
// before→after line, why-disclosure); the service reads the latest ledger row
// and honours dismissal; and honest absence (no event / dismissed / malformed)
// renders no card.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/benchmark_change_card.dart';
import 'package:mivalta_flutter/rust_engine.dart';
import 'package:mivalta_flutter/services/benchmark_notify.dart';
import 'package:mivalta_flutter/widgets/today/benchmark_notify_card.dart';

class _FakeHandle implements EnginesHandle {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

class _NotifyBinding implements RustEngineBinding {
  _NotifyBinding({required this.auditJson, required this.cardJson});
  final String auditJson; // read_audit_trail result
  final String cardJson; // realize_benchmark_change result
  String? realizedFrom;

  @override
  Future<String> readAuditTrail(EnginesHandle handle,
          {required String eventType, required int limit}) async =>
      auditJson;

  @override
  Future<String> realizeBenchmarkChange(EnginesHandle handle,
      {required String eventJson}) async {
    realizedFrom = eventJson;
    return cardJson;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

const _cardJson = '''
{"kind":"promote","headline":"Your cycling threshold improved",
 "benchmark_line":"FTP 240 → 259 W",
 "disclosure":["Confirmed over 2 days","Measured +12.5%","Held to a safe progression rate"]}''';

String _auditRow(String auditId, String eventJson) => jsonEncode([
      {
        'audit_id': auditId,
        'event_type': 'benchmark_change',
        'assessment_json': eventJson,
        'message': 'cycling cp_watts promote: 240 → 259 watts',
      }
    ]);

void main() {
  final handle = _FakeHandle();

  group('BenchmarkChangeCard.parse', () {
    test('parses the engine card verbatim', () {
      final c = BenchmarkChangeCard.parse(_cardJson)!;
      expect(c.kind, 'promote');
      expect(c.headline, 'Your cycling threshold improved');
      expect(c.benchmarkLine, 'FTP 240 → 259 W');
      expect(c.disclosure.length, 3);
      expect(c.disclosure[1], 'Measured +12.5%');
    });

    test('the engine "null" and malformed payloads are honest absence', () {
      expect(BenchmarkChangeCard.parse('null'), isNull);
      expect(BenchmarkChangeCard.parse('not json'), isNull);
      expect(BenchmarkChangeCard.parse('{"headline":"x"}'), isNull); // no line
    });
  });

  group('BenchmarkNotifyService', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('bn_test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('loads the latest event, realizes it, then honours dismissal',
        () async {
      final binding = _NotifyBinding(
        auditJson: _auditRow('a1', '{"the":"event"}'),
        cardJson: _cardJson,
      );
      final svc =
          BenchmarkNotifyService(binding: binding, handle: handle, dir: tmp);

      final pending = await svc.loadPending();
      expect(pending, isNotNull);
      expect(pending!.auditId, 'a1');
      expect(pending.card.headline, 'Your cycling threshold improved');
      // The engine realized from the ledger row's assessment_json verbatim.
      expect(binding.realizedFrom, '{"the":"event"}');

      // After dismissal the same event no longer surfaces.
      await svc.dismiss('a1');
      expect(await svc.loadPending(), isNull);
    });

    test('no benchmark_change rows → honest absence', () async {
      final binding = _NotifyBinding(auditJson: '[]', cardJson: _cardJson);
      final svc =
          BenchmarkNotifyService(binding: binding, handle: handle, dir: tmp);
      expect(await svc.loadPending(), isNull);
    });
  });

  testWidgets('the card renders headline, line, and tappable why-disclosure',
      (tester) async {
    final c = BenchmarkChangeCard.parse(_cardJson)!;
    var dismissed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BenchmarkNotifyCard(card: c, onDismiss: () => dismissed = true),
      ),
    ));

    expect(find.text('Your cycling threshold improved'), findsOneWidget);
    expect(find.text('FTP 240 → 259 W'), findsOneWidget);
    // Disclosure hidden until "Why?" tapped.
    expect(find.text('Confirmed over 2 days'), findsNothing);
    await tester.tap(find.text('Why?'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed over 2 days'), findsOneWidget);
    expect(find.text('Held to a safe progression rate'), findsOneWidget);

    // Dismiss fires the callback.
    await tester.tap(find.byIcon(Icons.close));
    expect(dismissed, isTrue);
  });
}
