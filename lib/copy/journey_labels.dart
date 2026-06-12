// Round 3 item 19 (docs/FOUNDER_FEEDBACK_2026-06-12.md): the 2nd anchor is
// the athlete's JOURNEY — past + becoming, not future planning. Fixed copy
// for the Journey screen, label layer only. Copy FLAGGED FOR FOUNDER REVIEW
// before lock (same contract as the old Plan placeholder).

/// Tab + app-bar title.
const kJourneyTitle = 'Journey';

/// Engine not ready / first fetch not back yet — honest transient.
const kJourneyLoadingCopy = 'Getting your journey ready\u2026';

/// Fetch failed — honest failure, never a fabricated journey.
const kJourneyErrorCopy = 'Couldn\u2019t load your journey.';

// — Learning arc (calibration story) —
const kJourneyLearningHeading = 'LEARNING YOU';
const kJourneyCalibrationCopy =
    'The first ~28 days calibrate the model to your normal.';
const kJourneyLearningEmptyCopy =
    'Your journey starts with the first morning check-in.';

/// The learning-arc line — founder phrasing "day X of ~28" while inside the
/// calibration window; past it, the plain day count (no false ceiling).
String journeyLearningLine(int days) => days <= 28
    ? 'Learning you \u2014 day $days of ~28.'
    : 'Learning you \u2014 day $days.';

// — Week in review —
const kJourneyWeekHeading = 'THIS WEEK';
const kJourneyWeekEmptyCopy = 'No training logged this week yet.';

// — Baseline evolution —
const kJourneyBaselineHeading = 'BASELINE';
const kJourneyBaselineEmptyCopy =
    'Your fitness baseline will appear after your first workouts.';
