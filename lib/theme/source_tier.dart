// Locked SourceTier color tokens. Single source of truth for the
// four data-source-quality tiers gatc-normalizer classifies
// observations into. Mirrors `DataSourceTier` in
// mivalta-rust-engine/crates/gatc-normalizer/src/data_quality.rs:37
// (Medical / Device / Partial / Manual). Hex values are LOCKED per
// CLAUDE.md — change a value here only if the founder authorises a
// design-token bump in the same PR.

import 'package:flutter/material.dart';

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
