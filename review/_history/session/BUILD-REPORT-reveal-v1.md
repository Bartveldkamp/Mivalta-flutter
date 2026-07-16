# BUILD REPORT — BS-011 Session Reveal (Evening Reveal)

**Spec:** BS-011-reveal.md (MCP Design)
**Branch:** feature/bs011-reveal
**Build SHA:** 5014776

## Summary

Post-workout reveal screen: "one scroll, calm, verdict first." Shows what the
session did, time-in-zone breakdown, and tomorrow implication. Engine enters
at session end; Dart displays only.

## Files Created

| File | Purpose |
|------|---------|
| `lib/screens/session_reveal_screen.dart` | Post-workout reveal (864 lines) |

## Files Modified

| File | Change |
|------|--------|
| `lib/screens/session_live_screen.dart` | Navigate to `SessionRevealScreen` on session end |

## Screen Structure

```
SessionRevealScreen
├── _buildHeader()       # Gradient header, sport complete badge, duration/distance chips
├── _buildAverages()     # Avg HR, Max HR, Avg Speed strip
├── _buildVerdict()      # Josi verdict: "what it built" + quality summary
├── _buildTimeInZone()   # Zone bar chart with engine-system-true labels
├── _buildTomorrow()     # ACWR band implication (overreached/productive/accumulation)
└── _buildActions()      # Done button → TodayScreen
```

## Engine Integration

The reveal screen bootstraps its own engine connection (profile → tables → vault →
construct handle) and attempts to fetch:

1. `completedWorkoutFacts(date)` — session facts from vault
2. `buildPostWorkoutReport(factsJson)` — engine report (energySystem, whatItBuilds, qualitySummary)
3. `computeTimeInZone(activityJson)` — zone breakdown from HR samples

**Honest absence:** If facts/report unavailable (session not yet in vault or no
HR data), the screen shows the raw session metrics from `CompletedSession` struct
with fallback labels.

## Design Decisions

1. **Verdict first**: Josi's "what it built" line is the first message, not buried.
2. **One scroll**: All sections in a single scroll, calm reveal — no tabs.
3. **No share button**: The reveal is for the athlete, not social.
4. **Engine-system-true zone labels**: Uses `zoneDisplayNameAndColor()` for accurate
   energy-system naming (Z1-5 → Aerobic foundation / Aerobic endurance / etc.).
5. **Tomorrow implication**: ACWR band drives the "what to expect" message.

## Verification

```
flutter analyze  → No issues found!
flutter test     → 254 tests passed
```

## DoD Checklist

- [x] Receive `CompletedSession` from live screen
- [x] Bootstrap engine connection
- [x] Fetch workout report from engine (with honest-absence fallback)
- [x] Display session header with sport + duration + distance
- [x] Display averages strip (HR, speed)
- [x] Display Josi verdict (energySystem, whatItBuilds, qualitySummary)
- [x] Display time-in-zone bar chart
- [x] Display tomorrow implication (ACWR band)
- [x] Done button navigates to TodayScreen
- [x] analyze green
- [x] test green (254 tests)

---

*Generated: 2026-07-05*
