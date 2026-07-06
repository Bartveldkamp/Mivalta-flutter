# BUILD REPORT — BS-012 Morning Read Notification

**Spec:** BS-012-morning-read.md (MCP Design)
**Branch:** feature/bs012-morning-read
**Build SHA:** (updated post-N3)

## Summary

The morning read notification feature — gate logic + delivery layer. Decides
whether to fire the morning notification based on Coach presence setting and
three reasons to speak, then schedules via flutter_local_notifications.

**N3 Delivery Layer (DR-021):** Added flutter_local_notifications with zonedSchedule,
app resume + post-ingest triggers, sensitive lock-screen handling (NotificationVisibility.secret),
badge:false on iOS, and tap→TodayScreen navigation.

## DR-021 Fixes Applied

| Fix | Issue | Resolution |
|-----|-------|------------|
| **N1** | Fabricated word "Fatigued" not in engine vocabulary | Use only locked states: Recovered/Productive/Accumulated/Overreached/IllnessRisk |
| **N2** | level→word mapping in Dart violated "engine words verbatim" | Use `fatigueState` from `viterbiFatigueState()` directly; no translation |
| **N3** | Wrong color hex values (e.g. #2BD974 instead of #00C6A7) | Use state palette from tokens.dart, not level palette |

## Files Created / Modified

| File | Purpose |
|------|---------|
| `lib/services/morning_read_gate.dart` | Salience gate service |
| `lib/services/notification_service.dart` | Delivery layer service (N3) |
| `lib/main.dart` | NotificationService init + global navigator key |
| `lib/screens/today_screen.dart` | Lifecycle observer + scheduling triggers |
| `pubspec.yaml` | flutter_local_notifications + timezone deps |
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

## Scheduling Seam

**Status: WIRED (N3 complete).**

The spec's `flutter_local_notifications` + `zonedSchedule` is now implemented:
1. Dependency added: `flutter_local_notifications: ^18.0.1` + `timezone: ^0.10.0`
2. iOS permissions: requested at init (sound + alert, no badge)
3. Scheduling triggers: app resume (WidgetsBindingObserver) + post-ingest

**iOS constraint:** iOS heavily restricts background execution. The gate is
evaluated at schedule time (app resume + post-ingest), not at fire time. This
means the notification content is determined when the app was last open, not
at 07:00 delivery time. Acceptable for v1.

## Blocked Items

| Item | Reason |
|------|--------|
| Debug preview row in You | You screen not on main (feature/bs013-you unmerged) |
| Witness shots (notif-normal, notif-advisory, lockscreen-hidden) | Mac-only; sim required |
| Delivery window picker | Spec says "constant default is fine, note it" |

## Presence Mapping

The gate reads `coach_presence` from SharedPreferences (key: `coach_presence`).
This pref is set by the You screen (feature/bs013-you). Until merged, the gate
defaults to `moderate` (the spec default).

## Verification

```
flutter analyze  → No issues found!
flutter test     → 262 tests passed (15 gate-specific)
```

## N3 Delivery Layer — Implementation

| Component | Status |
|-----------|--------|
| `flutter_local_notifications` dependency | Added v18.0.1 + timezone v0.10.0 |
| `NotificationService` singleton | Initializes plugin, schedules via zonedSchedule |
| App resume trigger | WidgetsBindingObserver in TodayScreen |
| Post-ingest trigger | Called after _loadHomeData completes |
| Sensitive lock-screen | NotificationVisibility.secret (Android) |
| badge:false | DarwinNotificationDetails(presentBadge: false) |
| Tap→Today navigation | Global navigator key in main.dart |
| Default delivery time | 07:00 local (constant, not configurable) |

## DoD Checklist

- [x] Gate service with three reasons to speak
- [x] Presence mapping (Off/Quiet/Moderate)
- [x] Engine words verbatim (DR-021 N1/N2) — fatigueState pass-through
- [x] Locked state palette colors (DR-021 N3) — from tokens.dart
- [x] Calibration milestone detection
- [x] Same-day deduplication (lastDeliveredDate)
- [x] Unit tests (15 cases, ≥9 required)
- [x] flutter_local_notifications wiring (DR-021 N3)
- [x] App resume scheduling trigger
- [x] Post-ingest scheduling trigger
- [x] Tap→Today navigation
- [x] badge:false (iOS)
- [x] Sensitive lock-screen body (Android visibility: secret)
- [x] analyze green
- [x] test green (262 tests passed)
- [ ] Debug preview row (blocked: You screen not on main)
- [ ] Witness shots (blocked: Mac-only)

---

*Updated: 2026-07-06 (DR-021 N1/N2/N3 complete)*
