// Benchmark-change notify card — Phase 3 display model.
//
// Display-only. The engine (`VaultEngine::realize_benchmark_change`) composes
// EVERY string from a real `benchmark_change` ledger event — the headline, the
// before→after line, and the why-disclosure lines. Flutter renders them
// verbatim; no math, no re-phrasing, no invented congratulation. The engine
// returns the JSON string `"null"` when there is no presentable event (honest
// absence), which parses here to `null`.

import 'dart:convert';

class BenchmarkChangeCard {
  /// `promote` | `demote` — lets the UI pick tone/icon without parsing prose.
  final String kind;

  /// e.g. "Your cycling threshold improved".
  final String headline;

  /// Before→after in the athlete's unit, e.g. "FTP 240 → 259 W" or
  /// "Threshold pace 4:10 → 4:03 /km".
  final String benchmarkLine;

  /// Why-disclosure — one engine-composed line per real evidence field
  /// (pattern size, measured gain, rate-cap). Shown behind a "why?" tap.
  final List<String> disclosure;

  const BenchmarkChangeCard({
    required this.kind,
    required this.headline,
    required this.benchmarkLine,
    required this.disclosure,
  });

  /// Parse `realize_benchmark_change` output. Returns null for the engine's
  /// `"null"` (honest absence) or any non-object / malformed payload — the
  /// caller renders nothing, never a fabricated card.
  static BenchmarkChangeCard? parse(String json) {
    dynamic decoded;
    try {
      decoded = jsonDecode(json);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final headline = decoded['headline'];
    final benchmarkLine = decoded['benchmark_line'];
    if (headline is! String || benchmarkLine is! String) return null;
    final rawDisclosure = decoded['disclosure'];
    return BenchmarkChangeCard(
      kind: decoded['kind']?.toString() ?? '',
      headline: headline,
      benchmarkLine: benchmarkLine,
      disclosure: rawDisclosure is List
          ? rawDisclosure.map((e) => e.toString()).toList(growable: false)
          : const [],
    );
  }
}
