// NEXT_BUILD_BRIEF §C: Journey screen copy. The 2nd anchor is the athlete's
// JOURNEY — past + becoming, not future planning. Copy FLAGGED FOR FOUNDER
// REVIEW before lock.

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

// — Load vs Recovery (the spine) —
const kJourneyLoadRecoveryHeading = 'LOAD VS RECOVERY';
const kJourneyLoadRecoveryEmptyCopy =
    'Your load and recovery trends will appear after training starts.';

// — Fitness / Form / Freshness —
const kJourneyFitnessHeading = 'FITNESS & FORM';
const kJourneyFitnessEmptyCopy =
    'Your fitness baseline will appear after your first workouts.';

// — Biometric overviews —
const kJourneyHrvHeading = 'HRV TREND';
const kJourneyHrvEmptyCopy = 'HRV data will appear after morning check-ins.';
const kJourneyRhrHeading = 'RESTING HR';
const kJourneyRhrEmptyCopy = 'Resting HR will appear after morning check-ins.';
const kJourneySleepHeading = 'SLEEP';
const kJourneySleepEmptyCopy = 'Sleep data will appear after syncing.';

// — Workouts list —
const kJourneyWorkoutsHeading = 'RECENT WORKOUTS';
const kJourneyWorkoutsEmptyCopy = 'No workouts logged yet.';

// — Adaptation trends —
const kJourneyAdaptationHeading = 'ADAPTATION';
const kJourneyEfTrendLabel = 'Efficiency factor';
const kJourneyHrRecoveryLabel = 'HR recovery';
const kJourneyAdaptationEmptyCopy =
    'Adaptation trends will appear after several workouts.';

// — Week in review (legacy, now part of load) —
const kJourneyWeekHeading = 'THIS WEEK';
const kJourneyWeekEmptyCopy = 'No training logged this week yet.';

// — Baseline evolution (legacy, now part of fitness) —
const kJourneyBaselineHeading = 'BASELINE';
const kJourneyBaselineEmptyCopy =
    'Your fitness baseline will appear after your first workouts.';
