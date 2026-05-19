// Locked SourceTier color tokens. Single source of truth for the
// four data-source-quality tiers gatc-normalizer classifies
// observations into. Mirrors `DataSourceTier` in
// mivalta-rust-engine/crates/gatc-normalizer/src/data_quality.rs:37
// (Medical / Device / Partial / Manual). Hex values are LOCKED per
// CLAUDE.md — change a value here only if the founder authorises a
// design-token bump in the same PR.

import 'package:flutter/material.dart';

import '../copy/f1.dart';

/// The four canonical data-source tiers. Strings match the JSON
/// serialisation `serde` produces for `DataSourceTier` on the
/// rust-engine side (PascalCase variant name).
enum SourceTier { medical, device, partial, manual }

/// Hex-encoded color tokens, raw integers so the const-map test can
/// assert exact byte equality with CLAUDE.md without depending on
/// Flutter's Color packing.
const Map<SourceTier, int> kSourceTierHex = <SourceTier, int>{
  SourceTier.medical: 0xFF2BD974,
  SourceTier.device: 0xFF00C6A7,
  SourceTier.partial: 0xFFE6872F,
  SourceTier.manual: 0xFF878C8C,
};

/// Flutter `Color` projection of the locked tokens. Widgets read from
/// here so the hex literals never appear at call sites.
final Map<SourceTier, Color> kSourceTierColor = <SourceTier, Color>{
  for (final entry in kSourceTierHex.entries) entry.key: Color(entry.value),
};

/// Engine-facing label matching the `DataSourceTier::Display` impl
/// in rust-engine (`Medical (A)`, etc.). Display-only — never parse
/// from this.
const Map<SourceTier, String> kSourceTierLabel = <SourceTier, String>{
  SourceTier.medical: 'Medical (A)',
  SourceTier.device: 'Device (B)',
  SourceTier.partial: 'Partial (C)',
  SourceTier.manual: 'Manual (D)',
};

/// Map an engine-emitted JSON variant string (`"Medical"`, `"Device"`,
/// `"Partial"`, `"Manual"`) onto the enum value, or `null` when the
/// string isn't a known variant. The shim emits exactly these four
/// PascalCase variants when a biometric exists; any other shape
/// (`null`, a number, a typo) returns `null` so the caller can
/// fall through to the F1 no-data path without trusting a stranger.
SourceTier? sourceTierFromEngine(Object? raw) {
  if (raw is! String) return null;
  switch (raw) {
    case 'Medical':
      return SourceTier.medical;
    case 'Device':
      return SourceTier.device;
    case 'Partial':
      return SourceTier.partial;
    case 'Manual':
      return SourceTier.manual;
  }
  return null;
}

/// Renders either a single LOCKED-token swatch + tier label (when
/// the engine returned a known variant) or the F1 no-data copy
/// (when the engine returned `null`). Public so tests can exercise
/// the two branches directly without driving the full readiness
/// screen.
class SourceTierIndicator extends StatelessWidget {
  const SourceTierIndicator({super.key, required this.tier});
  final SourceTier? tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = tier;
    if (t == null) {
      // Single source of truth: lib/copy/f1.dart. `source_tier_test.dart`
      // asserts both render paths reach kF1NoDataCopy.
      return Text(kF1NoDataCopy, style: theme.textTheme.bodyLarge);
    }
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: kSourceTierColor[t],
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Text(kSourceTierLabel[t] ?? t.name,
            style: theme.textTheme.titleMedium),
      ],
    );
  }
}
