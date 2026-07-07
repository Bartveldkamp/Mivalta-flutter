STATUS: ACTIVE AUDIT (2026-07-06) — engine wiring truth, per screen.
# WIRE-001 — what is really wired vs placeholder vs fallback

Everything below is SOURCE-VERIFIED by Design (not reported). Verified at:
today_screen @ b073f96 · you_screen @ 8bf7ea2 · auth/onboarding @ post-copy-fix
· gate/notification @ DR-021 close · advisor @ DR-018 · journey @ DR-019.

## ✅ REAL — live FFI calls, engine decides
| Surface | Seams (all real calls in source) |
|---|---|
| Today | readinessIndicator · stateAdvisory · realizeAdvisorLine · viterbiFatigueState · readDailyLoads · getAcwr · lastObservationSourceTier · readBiometricHistory (sleep_hours) · zoneCapWithAdvisories · recommendWorkout · personalizationDiagnostics |
| Morning read | morningReadVerdict (engine decides fire/silent) |
| Advisor | recommendWorkout options · why/purpose fields |
| Journey | readReadinessHistory · readDailyLoads · fitnessSeries · computeTimeInZone |
| You | personalizationDiagnostics · validationReport · isLearningPaused/pause/resume · exportBiometricsCsv · exportEncryptedVault · clearAllUserData · cryptoEraseCache |
| Session | recorder → ingest → completedWorkoutFacts (reveal reads AFTER ingest — Gate B fix) |
| Onboarding | buildOnboardingProfile · writeProfileToVault · constructEnginesFresh |

## ⚠ PLACEHOLDER — looks wired, is not (each labeled honestly in UI, but verify)
1. **Sources card**: `buildSourceOverview(sourcesJson: '[]')` — always empty
   until source plumbing lands (FTY1). Real seam, fake input.
2. **Sleep stages**: `SleepStageRing(stages: null)` hardcoded — engine gap G1.
3. **Daily activity card**: hardcoded honest-absent, no call at all — gap G2.
4. **Auth verification**: `_verifyCode` always succeeds; Apple sign-in stub.
5. **Voice surfaces S1/S3-offer/S4**: seams now live; build in flight (BS-016).
6. **Edit profile / text size / units**: stub sheets (labeled).

## 🕳 THE BLIND SPOT — silent catch(_) on every seam
Every FFI call is wrapped `try { … } catch (_) { /* honest absence */ }`.
By design — but it makes A BROKEN SEAM INDISTINGUISHABLE FROM AN EMPTY ONE.
If getAcwr started throwing tomorrow, Load would show "range still building"
forever and no one would know.

**Fix (BS-018, build with the witness pass): the wiring stamp.**
kDebugMode-only panel under the existing build stamp on Today: one row per
seam — name · last call result (ok / error+type / not-called) · ms. Collect
via a tiny `SeamLog.record(name, result)` helper called in every catch and
success path (one line each; no behavior change, compiled out of release).
The witness pass then reads the stamp on device: every row must say `ok`
against a real profile before its surface can go ⚠→✓. This converts "we
think it's wired" into "the device says it's wired."

## Witness-pass rule (extends BETA-001 P2)
A surface is ✓ only when BOTH: (a) real data renders, AND (b) its seam rows
read `ok` in the wiring stamp. An absent-state render with an `error` row is
a WIRING BUG, not honest absence — file it.
