# BS-003-advisor Build Report

**Branch:** `feature/bs003-advisor`
**Last commit:** `3cb85d1` (safety advisories support)
**Date:** 2026-07-03

## Completed (coding session)

### 1. Spec mirrored to repo
- `review/advisor/BS-003-advisor.md` — full spec from design project

### 2. Today card updated (`lib/screens/today_screen.dart`)
- Zone chip: energy name first (e.g. "Tempo · Z3")
- FocusCue preview from `structure.main_set.cue_start`
- Chevron affordance + tap → AdvisorScreen navigation
- Honest-absence copy (no gamification): "No suggestion yet"
- Stored `_binding` and `_handle` for Advisor re-resolve

### 3. AdvisorScreen created (`lib/screens/advisor_screen.dart`)
- Quick-adjust chip row: Feeling (mood) / Equipment / Terrain
- Chip selection triggers `_reResolve()` via passed binding/handle
- Option cards: zone chip, title, duration, why prose
- "Recommended for you" pill on first option
- "Chosen today" checkmark on persisted selection
- Detail view with full option info
- "This one today" button → persists to SharedPreferences, pops to Today
- Back arrow returns to list view
- Honest-absent state: "No options right now"
- Loading overlay + error card for re-resolve failures

### 4. Model extended (`lib/models/home_data.dart`)
- Added `workoutOptions` list for Advisor navigation

### 5. Dependency added (`pubspec.yaml`)
- `shared_preferences: ^2.2.0` for choice persistence

### 6. Tests added (`test/advisor_chip_mapping_test.dart`)
- Chip values match engine contract (10 tests, all pass)
- Documents Feeling→mood, Equipment→equipment, Terrain→terrain mapping
- Null-selection semantics documented

### 7. Safety advisories support
- Optional `safetyAdvisories` parameter on AdvisorScreen
- Renders above options in `stateAccumulated` color (steady, not alarm)
- Forward-compatible: ready for when TodayScreen wires `realize_advisor_line`

## Blocked on Mac session

### 1. Structure renderer (detail view)
The detail view currently shows placeholder text. Needs real JSON echo from
Mac-side `recommend_workout` call to see actual shape of:
- `structure.warmup` (type, duration, segments?)
- `structure.main_set` (intervals, cue_start already parsed, but rest?)
- `structure.cooldown` (type, duration?)

**Instruction for Mac:** Run app with DemoSeeder, navigate to Advisor detail
view, capture console JSON or add temporary logging to echo the full
`structure` object.

### 2. Screenshot captures
Per spec: capture screenshots of Today card with zone chip, Advisor list view,
and Advisor detail view.

### 3. Full build verification
Run `flutter build apk --debug` and `flutter run` to verify no runtime errors
with real engine binding.

## Files modified

| File | Change |
|------|--------|
| `lib/screens/today_screen.dart` | Zone chip, tap navigation, binding storage |
| `lib/screens/advisor_screen.dart` | NEW — full Advisor screen |
| `lib/models/home_data.dart` | Added `workoutOptions` |
| `lib/widgets/today/module_card.dart` | Added `onTap`, `trailing` params |
| `pubspec.yaml` | Added shared_preferences |
| `review/advisor/BS-003-advisor.md` | Spec mirror |
| `test/advisor_chip_mapping_test.dart` | NEW — chip contract tests |

## Next steps (Mac session)

1. `git pull` on `feature/bs003-advisor`
2. Run with DemoSeeder enabled
3. Navigate Today → Advisor → tap option to detail
4. Capture `structure` JSON shape from console/logs
5. Report back structure fields for renderer implementation
6. Take screenshots for spec review
