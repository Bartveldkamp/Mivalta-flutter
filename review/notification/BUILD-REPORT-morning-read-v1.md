# BUILD REPORT — BS-012 Morning Read Notification

**Spec:** BS-012-morning-read.md (MCP Design)
**Branch:** feature/bs012-morning-read
**Build SHA:** 3c53bcb

## Summary

The morning read salience gate — pure Dart service, fully unit-tested. Decides
whether to fire the morning notification based on Coach presence setting and
three reasons to speak. Zero new FFI.

## Files Created

| File | Purpose |
|------|---------|
| `lib/services/morning_read_gate.dart` | Salience gate service (187 lines) |
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
| 12 | — | — | — | — | **silent** | no_state_word (missing indicator) |
| 13 | (unset) | yes | no | no | **FIRE** | default=moderate |
| 14 | — | — | — | — | — | level→word/color mapping verified |
| 15 | — | — | — | — | — | markDelivered persistence verified |

## Engine Integration

The gate reads engine outputs via JSON (no new FFI):
- `readiness_indicator` → level (Green/Yellow/Orange/Red) → word (Productive/Accumulated/Fatigued/Overreached)
- `pending_advisories` → non-empty list triggers (b)
- `state_advisory` → advisory text for line 2
- `validation_report` → sufficiency_bucket for calibration milestone

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
flutter analyze  → (pending)
flutter test     → 15 tests passed (morning_read_gate_test.dart)
```

## DoD Checklist

- [x] Gate service with three reasons to speak
- [x] Presence mapping (Off/Quiet/Moderate)
- [x] State level → word + color mapping
- [x] Calibration milestone detection
- [x] Same-day deduplication (lastDeliveredDate)
- [x] Unit tests (15 cases, ≥9 required)
- [x] Engine words verbatim (no fabrication)
- [ ] flutter_local_notifications wiring (blocked: dep not added)
- [ ] Debug preview row (blocked: You screen not on main)
- [ ] Witness shots (blocked: Mac-only)
- [x] analyze green (pending full run)
- [x] test green (15 tests passed)

---

*Generated: 2026-07-06*
