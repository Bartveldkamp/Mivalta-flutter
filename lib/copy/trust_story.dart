// Round 3 item 13 (docs/FOUNDER_FEEDBACK_2026-06-12.md): the "why" under the
// locked F1 line tells the TRUST STORY — what data is needed, how the model
// works, and how it earns confidence over the first ~28 days.
//
// FIXED COPY, label layer only (same contract as lib/copy/f1.dart): these
// strings are locked explanations of how the product behaves — grounded in
// the engine's card-backed design (four-axis readiness fusion, on-device
// inference, honest-confidence calibration window) — NOT engine output and
// NOT science claims invented in Dart. The axis names quoted in
// [kTrustStoryHowItWorks] are the humanized labels from
// lib/copy/axis_labels.dart, pinned by test so they cannot drift apart.

/// Part 1 — what data the model needs from the athlete.
const String kTrustStoryWhatData =
    'To predict your recovery, MiValta needs to see your days: '
    'morning check-ins, last night\u2019s sleep, and the workouts you log.';

/// Part 2 — how the model works, in plain words. The four axis names match
/// lib/copy/axis_labels.dart verbatim (test-pinned).
const String kTrustStoryHowItWorks =
    'On your phone, a model combines four views of you \u2014 '
    'Fatigue model, Fitness & freshness, Body signals, and How you feel '
    '\u2014 into one recovery picture. Nothing is sent to a server.';

/// Part 3 — the calibration story: how confidence is earned.
const String kTrustStoryCalibration =
    'It starts cautious on purpose. Over roughly the first 28 days it '
    'calibrates to your normal, and its confidence grows with every day of '
    'data. Until then, it says so honestly instead of guessing.';
