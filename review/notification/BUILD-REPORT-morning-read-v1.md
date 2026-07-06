# BUILD REPORT — BS-012 Morning Read Notification

**Spec:** BS-012-morning-read.md (MCP Design)
**Branch:** feature/bs012-morning-read
**Build SHA:** 30b62d4 (DR-021 fixes)

## Summary

The morning read salience gate — pure Dart service, fully unit-tested. Decides
whether to fire the morning notification based on Coach presence setting and
three reasons to speak. Zero new FFI.

## DR-021 Fixes Applied

| Fix | Issue | Resolution |
|-----|-------|------------|
| **N1** | Fabricated word "Fatigued" not in engine vocabulary | Use only locked states: Recovered/Productive/Accumulated/Overreached/IllnessRisk |
| **N2** | level→word mapping in Dart violated "engine words verbatim" | Use `fatigueState` from `viterbiFatigueState()` directly; no translation |
| **N3** | Wrong color hex values (e.g. #2BD974 instead of #00C6A7) | Use state palette from tokens.dart, not level palette |

## Files Created

| File | Purpose |
|------|---------|
| `lib/services/morning_read_gate.dart` | Salience gate service (274 lines) |
| `test/morning_read_gate_test.dart` | 15 decision-table unit tests |

## Decision Table (15 cases)

| # | Presence | State Δ | Advisory | Calibration Δ | Result | Reason |
|---|----------|---------|----------|---------------|--------|--------|
| 1 | Off | yes | yes | yes | **silent** | presence=off |
| 2 | Off | no | no | no | **silent** | presence=off |
| 3 | Off | no | yes | no | **silent** | presence=off |
| 4 | Quiet | yes | no | no | **silent** | quiet,no_advisory |
| 5 | Quiet | no | yes | no | **FIRE** | quiet+advisory |
| 6 | Quiet | no | no | yes | **silent** | quiet,no_advisory |
| 7 | Moderate | yes | no | no | **FIRE** | moderate+state_changed |
| 8 | Moderate | no | yes | no | **FIRE** | moderate+advisory |
| 9 | Moderate | no | no | yes | **FIRE** | moderate+calibration |
| 10 | Moderate | no | no | no | **silent** | moderate,no_change |
| 11 | Moderate | yes* | no | no | **silent** | *already notified today |
| 12 | — | — | — | — | **silent** | no_state_word (missing fatigue state) |
| 13 | (unset) | yes | no | no | **FIRE** | default=moderate |
| 14 | — | — | — | — | — | 5 locked states → colors verified (N1) |
| 15 | — | — | — | — | — | markDelivered persistence verified |

## Engine Integration

The gate reads engine outputs via JSON (no new FFI):
- `viterbiFatigueState` → state word verbatim (Recovered/Productive/Accumulated/Overreached/IllnessRisk)
- `pending_advisories` → non-empty list triggers (b)
- `state_advisory` → advisory text for line 2
- `validation_report` → sufficiency_bucket for calibration milestone

**Signature change (DR-021 N3):**
- `evaluate(fatigueStateJson: ...)` replaces `evaluate(readinessIndicatorJson: ...)`
- `markDelivered(state: ...)` replaces `markDelivered(level: ...)`
- Pref key `morning_read_last_state` replaces `morning_read_last_level`

## State Color Mapping (locked, from tokens.dart)

| State | Hex |
|-------|-----|
| Recovered | #7FE3B0 |
| Productive | #00C6A7 |
| Accumulated | #E8C547 |
| Overreached | #CE7B5A |
| IllnessRisk | #B85C63 |

## Scheduling Seam (Honest Naming)

**Status: NOT WIRED THIS PASS.**

The spec calls for `flutter_local_notifications` + `zonedSchedule`. This requires:
1. Adding the dependency to pubspec.yaml
2. iOS permission request flow (in-context, not at launch)
3. iOS Background Modes entitlement for scheduled wake

**Known iOS constraint:** iOS heavily restricts background execution. The gate
evaluation may need to happen at schedule time (not fire time) if the app isn't
running. This is acceptable for v1 — the gate can be evaluated when scheduling
the next morning's notification (app resume + post-ingest).

## Blocked Items

| Item | Reason |
|------|--------|
| Debug preview row in You | You screen not on main (feature/bs013-you unmerged) |
| Witness shots (notif-normal, notif-advisory, lockscreen-hidden) | Mac-only; sim required |
| Delivery window picker | Spec says "constant default is fine, note it" |
| flutter_local_notifications wiring | Dependency not added; gate logic is ready |

## Presence Mapping

The gate reads `coach_presence` from SharedPreferences (key: `coach_presence`).
This pref is set by the You screen (feature/bs013-you). Until merged, the gate
defaults to `moderate` (the spec default).

## Verification

```
flutter analyze  → No issues found!
flutter test     → 15 tests passed
```

## DoD Checklist

- [x] Gate service with three reasons to speak
- [x] Presence mapping (Off/Quiet/Moderate)
- [x] Engine words verbatim (DR-021 N1/N2) — fatigueState pass-through
- [x] Locked state palette colors (DR-021 N3) — from tokens.dart
- [x] Calibration milestone detection
- [x] Same-day deduplication (lastDeliveredDate)
- [x] Unit tests (15 cases, ≥9 required)
- [x] analyze green
- [x] test green (15 tests passed)
- [ ] flutter_local_notifications wiring (blocked: dep not added)
- [ ] Debug preview row (blocked: You screen not on main)
- [ ] Witness shots (blocked: Mac-only)

---

*Updated: 2026-07-06 (DR-021 fixes)*
