// Today-facts copy layer (HOME_REDESIGN_BRIEF §5) — the fixed dictionaries
// that turn engine context values into plain human words for the Today tiles.
//
// LABEL layer only (same pattern as axis_labels.dart / readinessLevelColor):
// engine value in → fixed copy out. The engine owns the zones and statuses;
// nothing here computes or thresholds. Unknown engine values fall back to
// silence (null → the tile shows its learning/empty copy), NEVER the raw
// string — raw enums are FORBIDDEN user-visible on Today (brief §5).
//
// Copy lives here, next to f1.dart and axis_labels.dart, so reviews can diff
// wording without touching widgets.

/// Tile heading labels.
const kSleepTileLabel = 'Last night';
const kTrainingLoadTileLabel = 'Training load';
const kTodayLoadTileLabel = 'Today';
const kWeatherTileLabel = 'Weather';

/// Round 3 item 12: stable tile ids for the user-configurable grid. Order
/// here = display order on the home and in the picker sheet.
const kTodayTileIds = ['sleep', 'load', 'today', 'weather'];

/// All tiles on — the default before the user customizes anything.
const Set<String> kDefaultTodayTiles = {'sleep', 'load', 'today', 'weather'};

/// Tile id → the human name shown in the picker sheet (same words as the
/// tile headings, so the mapping is obvious).
String todayTileName(String id) => switch (id) {
      'sleep' => kSleepTileLabel,
      'load' => kTrainingLoadTileLabel,
      'today' => kTodayLoadTileLabel,
      'weather' => kWeatherTileLabel,
      _ => id,
    };

/// Picker sheet heading + edit-affordance tooltip (item 12).
const kTilePickerTitle = 'Choose your tiles';
const kTilePickerTooltip = 'Choose tiles';

/// Sleep tile — no sleep row for last night.
const kSleepEmptyCopy = 'No sleep data yet';

/// Training-load tile — engine still calibrating (`data_status` ≠ ok, or a
/// zone string we have no label for).
const kTrainingLoadLearningCopy = 'Still learning your load';

/// Today's-load tile.
const kTodayLoadTrainedCopy = 'Trained today';
const kTodayLoadEmptyCopy = 'Nothing logged yet';

/// Weather tile — wired to OS weather (items 11+18); when the OS returned
/// nothing the tile says so honestly instead of fabricating conditions.
const kWeatherEmptyCopy = 'No weather right now';

/// Engine `acwr_zone` → human training-load label. Fixed dictionary keyed on
/// the engine's zone strings ('optimal'/'caution' observed in engine tests;
/// 'green'/'yellow'/'danger'/'red' accepted as the level-string family).
/// Unknown zones (including the insufficient-data marker) → null, and the
/// tile renders [kTrainingLoadLearningCopy] instead — never the raw string.
String? trainingLoadLabel(String? acwrZone) =>
    switch ((acwrZone ?? '').toLowerCase()) {
      'low' => 'Easy week',
      'optimal' || 'green' => 'Steady',
      'caution' || 'yellow' => 'High',
      'danger' || 'red' => 'Very high',
      _ => null,
    };

/// Engine `data_status` → is the load context trustworthy enough to label?
/// Dictionary membership check on the engine's own status string ('ok' /
/// 'state_unavailable' observed) — the engine decides; we only key copy off
/// its verdict.
bool loadContextAvailable(String? dataStatus) =>
    (dataStatus ?? '').toLowerCase() == 'ok';
