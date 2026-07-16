# BUILD REPORT — BS-013 You Tab

**Spec:** BS-013-you.md (MCP Design)
**Branch:** feature/bs013-you-tab
**Build SHA:** 4929182

## Summary

The "You" tab: profile summary, learning status, sources, sovereignty controls.
One scroll, grouped cards. Engine DECIDES, Dart DISPLAYS. Every toggle reflects
REAL state read at open — no optimistic UI lies.

## Files Created

| File | Purpose |
|------|---------|
| `lib/screens/you_screen.dart` | You tab screen (1220 lines) |
| `review/you/BUILD-REPORT-you-v1.md` | This build report |

## Screen Structure

```
YouScreen
├── _buildHeader()         # "You" title
├── _buildProfileCard()    # Sport, level, goal from profile JSON
├── _buildLearningCard()   # personalization_diagnostics + validation_report
├── _buildSourcesCard()    # build_source_overview → tier chips (or honest absence)
├── _buildSovereigntyCard() # Promise banner + pause/export/erase
├── _buildDisplayCard()    # Text size, units (stubs)
└── _buildDebugStamp()     # kDebugMode: engine hello
```

## Engine Integration

The screen bootstraps its own engine connection and reads:

1. `personalizationDiagnostics()` → observation count, confidence bucket
2. `validationReport()` → data sufficiency, paired observations, model score
3. `isLearningPaused()` → pause toggle state
4. `buildSourceOverview()` → connected sources with tier classification

## Sovereignty Actions (wired to FFI)

| Action | FFI Method | Notes |
|--------|------------|-------|
| Pause learning | `pauseLearning()` / `resumeLearning()` | Toggle, reads actual state after change |
| Export data | `exportBiometricsCsv(days: 90)` | Returns CSV string |
| Erase everything | `clearAllUserData()` + `cryptoEraseCache()` | Two-step confirm |

## Design Decisions

1. **REAL state only**: Toggle state is re-read from engine after every change —
   no optimistic UI that lies about what the engine did.
2. **Two-step erase confirm**: First dialog lists what dies, second confirms —
   no dark pattern, no guilt copy.
3. **Honest absence**: Sources card shows "No sources connected" when empty,
   with connect affordance.
4. **Edit stub**: Profile editing routes to a stub sheet naming what will be
   editable (re-running intake is not offered yet).

## Source Tier Colors

Uses `kSourceTierColor` from `lib/theme/source_tier.dart` (locked tokens):
- Medical: `#2BD974`
- Device: `#00C6A7`
- Partial: `#E6872F`
- Manual: `#878C8C`

## Verification

```
flutter analyze  → No issues found!
flutter test     → 254 tests passed
```

## DoD Checklist

- [x] Profile card (sport, level, goal from profile)
- [x] Learning you card (diagnostics + validation)
- [x] Sources card (with tier chips, honest absence)
- [x] Sovereignty card with promise banner
- [x] Pause learning toggle (wired to FFI, reads real state)
- [x] Export data button (wired to FFI)
- [x] Erase everything with two-step confirm (wired to FFI)
- [x] Display card (stubs for text size, units)
- [x] Debug stamp (kDebugMode only)
- [x] analyze green
- [x] test green (254 tests)

---

*Generated: 2026-07-05*
