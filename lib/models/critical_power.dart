// Critical Power (CP + W′) model — Monitor analytics.
//
// Display-only. Maps the engine's `gatc-cp` fit
// (mivalta-rust-engine `CpFit{cp_watts, w_prime_joules, r_squared, n_points}`,
// from `CpEngine::fit_cp_default`). CP is the asymptote of the power–duration
// curve (the highest sustainable power); W′ is the finite work available above
// it (Monod & Scherrer 1965, Hill 1993). Flutter only renders.
//
// FFI bridge needed (Mac step): facade `fitCp(mmpCurveJson)` → `fit_cp_default`,
// fed the same MMP curve the power-profile surface already reads
// (`read_mmp_history`). `fit_cp_default` is FFI-exposed in gatc-ffi.

class CriticalPower {
  /// Critical Power — highest sustainable power, watts.
  final double cpWatts;

  /// W′ — finite anaerobic work capacity above CP, joules.
  final double wPrimeJoules;

  /// Coefficient of determination of the fit (0..=1); fit quality.
  final double rSquared;

  /// Number of MMP points the fit used.
  final int nPoints;

  const CriticalPower({
    required this.cpWatts,
    required this.wPrimeJoules,
    required this.rSquared,
    required this.nPoints,
  });

  /// W′ in kilojoules (the human-readable unit for the card).
  double get wPrimeKj => wPrimeJoules / 1000.0;

  /// No usable fit — too few points or a non-physical CP. The card shows the
  /// honest empty state rather than a fabricated number.
  bool get isEmpty => nPoints <= 0 || cpWatts <= 0;

  factory CriticalPower.fromJson(dynamic json) {
    if (json is! Map) {
      return const CriticalPower(
        cpWatts: 0,
        wPrimeJoules: 0,
        rSquared: 0,
        nPoints: 0,
      );
    }
    return CriticalPower(
      cpWatts: (json['cp_watts'] as num?)?.toDouble() ?? 0,
      wPrimeJoules: (json['w_prime_joules'] as num?)?.toDouble() ?? 0,
      rSquared: (json['r_squared'] as num?)?.toDouble() ?? 0,
      nPoints: (json['n_points'] as num?)?.toInt() ?? 0,
    );
  }
}
