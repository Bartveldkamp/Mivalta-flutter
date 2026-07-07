// Benchmark-change notify loader — Phase 3.
//
// Reads the athlete's latest `benchmark_change` ledger row (the coach's
// biggest decision — recorded when the closed loop promotes/demotes a
// benchmark), asks the engine to compose the presentable card, and reports
// whether it has already been dismissed. Display-only courier: the card's
// every word is engine-composed (`realize_benchmark_change`); this service
// only fetches, checks a local "seen" marker, and hands the card up.
//
// The dismissal marker is a pure UI preference (which notification the user
// has acknowledged) — NOT coaching data — so it lives in a tiny plaintext
// file beside the other prefs, never in the encrypted vault. Honest-failure:
// any load failure → no card (the home never breaks on a missing notify).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;

import 'package:path_provider/path_provider.dart';

import '../models/benchmark_change_card.dart';
import '../rust_engine.dart';

/// A loaded, not-yet-dismissed benchmark-change notification.
class BenchmarkNotify {
  const BenchmarkNotify({required this.auditId, required this.card});

  /// The ledger row's audit id — the dismissal key.
  final String auditId;
  final BenchmarkChangeCard card;
}

class BenchmarkNotifyService {
  BenchmarkNotifyService({
    required this.binding,
    required this.handle,
    Directory? dir,
  }) : _dir = dir; // ignore: prefer_initializing_formals

  final RustEngineBinding binding;
  final EnginesHandle handle;
  final Directory? _dir;

  static const _fileName = 'benchmark_notify_seen.json';

  Future<File> _file() async {
    final dir = _dir ?? await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// The latest benchmark-change card the athlete hasn't dismissed, or null:
  /// no benchmark change yet, already dismissed, or any failure (honest
  /// absence — the home simply shows no notify).
  Future<BenchmarkNotify?> loadPending() async {
    try {
      final raw = await binding.readAuditTrail(
        handle,
        eventType: 'benchmark_change',
        limit: 1,
      );
      final rows = jsonDecode(raw);
      if (rows is! List || rows.isEmpty) return null;
      final row = rows.first;
      if (row is! Map) return null;

      final auditId = row['audit_id']?.toString();
      final eventJson = row['assessment_json'];
      if (auditId == null || eventJson is! String) return null;

      if (await _isDismissed(auditId)) return null;

      // The engine composes every word of the card from the event.
      final cardJson = await binding.realizeBenchmarkChange(
        handle,
        eventJson: eventJson,
      );
      final card = BenchmarkChangeCard.parse(cardJson);
      if (card == null) return null;

      return BenchmarkNotify(auditId: auditId, card: card);
    } catch (e) {
      // Honest absence — but name the cause in debug so a corrupt ledger row
      // (bad assessment_json) is distinguishable from "no event" on-device
      // (PR #170 review). A blanket-silent swallow hid real errors elsewhere.
      if (kDebugMode) {
        // ignore: avoid_print
        print('BenchmarkNotifyService.loadPending: ${e.runtimeType}: $e');
      }
      return null;
    }
  }

  /// Record that the athlete acknowledged this notification, so it doesn't
  /// re-appear. Best-effort; a failed write just means it shows once more.
  Future<void> dismiss(String auditId) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode({'seen': auditId}));
    } catch (_) {
      // Silent — a failed dismissal never breaks the home.
    }
  }

  Future<bool> _isDismissed(String auditId) async {
    try {
      final file = await _file();
      if (!await file.exists()) return false;
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map && decoded['seen'] == auditId;
    } catch (_) {
      return false;
    }
  }
}
