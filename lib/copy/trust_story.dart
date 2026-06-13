// Round 3 item 13 + round 3-final item 22
// (docs/FOUNDER_FEEDBACK_2026-06-12.md): the "why" under the locked F1 line
// tells the trust story PLAINLY — the model needs ~28 days of your data to
// build a real personalized profile of your level and status before its
// reads are trustworthy. What it's collecting, why it takes time, how trust
// grows. Simple human words, no jargon.
//
// FIXED COPY, label layer only (same contract as lib/copy/f1.dart): these
// strings are locked explanations of how the product behaves — grounded in
// the engine's card-backed design (on-device inference, honest-confidence
// ~28-day calibration window) — NOT engine output and NOT science claims
// invented in Dart.

/// Part 1 — what it's collecting.
const String kTrustStoryWhatData =
    'MiValta is collecting your days: how you slept, how you feel each '
    'morning, and the training you do.';

/// Part 2 — what it builds from that, in plain words.
const String kTrustStoryHowItWorks =
    'From those days it builds a personal profile of your level and your '
    'day-to-day status \u2014 all on your phone, never on a server.';

/// Part 3 — why it takes time, and how trust grows.
const String kTrustStoryCalibration =
    'A profile you can trust takes about 28 days of your own data. Until '
    'then it holds back instead of guessing \u2014 every day you log makes '
    'its reads more yours.';
