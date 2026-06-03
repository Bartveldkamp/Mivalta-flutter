# MiValta — Product & Engineering Overview

**Read this first.** A single-page picture of what MiValta is, how it's built,
what exists today, and what's next. Written for an external engineering
partner (Apadmi) doing a first review.

---

## 1. What MiValta is

**A privacy-first AI fitness coach that runs entirely on the device.** It
ingests a user's biometrics (heart rate, HRV, sleep, etc.) and tells them how
recovered they are and what to train today — with no cloud, no account
required, and no data leaving the phone.

**The core principle:** *the engine DECIDES, the app DISPLAYS, and (later) the
LLM EXPLAINS.* All coaching logic lives in a deterministic on-device engine.
The AI layer never makes decisions — it only puts the engine's output into
words. This is what makes the coaching trustworthy and the privacy real.

**The promise, literally:** 100% on-device, 100% user data ownership, no
harvesting. Data is encrypted at rest (SQLCipher), and "delete" means the
encryption key is destroyed — the data becomes unrecoverable noise.

---

## 2. The tier ladder

The product is built in tiers. **Tier 1 and Tier 2 are the first two delivery
steps** and are functionally built today; Tier 3 is the next phase.

| Tier | Name | What the user gets | Status |
|------|------|--------------------|--------|
| **Tier 1** | **Monitor** | Daily readiness & fatigue state from biometrics — "how recovered am I, and how hard can I go today?" | ✅ Built |
| **Tier 2** | **Advisory** | Concrete workout recommendations (A/B/C options) tuned to today's state — "what exactly should I do?" | ✅ Built |
| **Tier 3** | **Josi** | A conversational AI coach that *explains* the engine's decisions in natural language. Paid; on-device LLM. | 🔲 Next phase (deferred) |

Tiers 1–2 are the free, on-device coaching core. Tier 3 (Josi) is the paid
upgrade and the subject of a separate model-training track.

---

## 3. Architecture at a glance

```
   ┌─────────────────────────┐     FFI (typed JSON, pure pass-through)
   │   mivalta-rust-engine   │ ◄──────────────────────────────────────┐
   │   (core IP — Rust)      │                                         │
   │                         │   • Viterbi monitor (readiness/fatigue) │
   │   • 16 engines          │   • Advisor (A/B/C workouts)            │
   │   • SQLCipher vault     │   • SQLCipher-encrypted on-device vault │
   │   • Health normalizers  │                                         │
   └─────────────────────────┘                                         │
                                                                       │
   ┌─────────────────────────┐                                         │
   │     Mivalta-flutter     │ ── flutter_rust_bridge ─────────────────┘
   │   (the app — Dart)      │
   │                         │   • Android + iOS, one codebase
   │   • Display only        │   • Health Connect / Apple Health ingest
   │   • No business logic   │   • Onboarding, Settings, data control
   └─────────────────────────┘
```

- **The engine is the IP.** It does all readiness, classification, statistics,
  and rule resolution. Deterministic, on-device, ~no external dependencies at
  runtime.
- **The app is display + transport.** Flutter maps engine output to UI; it
  contains zero coaching logic. The FFI layer serialises typed data only.
- **One client, two platforms.** Flutter targets Android and iOS from a single
  codebase. (A legacy native-Android app exists but is being *replaced* by
  Flutter — see §6.)

---

## 4. The two repositories to review

| Repo | What it is | Start reading at |
|------|-----------|------------------|
| **mivalta-rust-engine** | The on-device coaching engine (core IP), Rust. | `CLAUDE.md` → `docs/MIVALTA_FINAL_SPEC.md` → `docs/ARCHITECTURE.md` → `docs/VITERBI.md` (the monitoring model) → `docs/FFI_API_CONTRACT.md` |
| **Mivalta-flutter** | The cross-platform app (Android + iOS), Dart. | `CLAUDE.md` → `docs/MIVALTA_OVERVIEW.md` (this file) → `docs/DISTRIBUTION_AND_TIERS.md` → `docs/RELEASE_CHECKLIST.md` |

Two repos **not** in scope for this review: `mivalta-android-client` (legacy
native app, superseded by Flutter) and `mivalta-science-engine` (the Tier-3
Josi model-training track, relevant only if the LLM is in Apadmi's scope).

---

## 5. What's built today (honest status)

✅ **Functionally complete and connected:**
- Tier 1 Monitor + Tier 2 Advisory, running on real biometrics
- Android end-to-end: Health Connect + Apple Health + manual ingest → engine → readiness/advice
- On-device **SQLCipher** encryption; data export (encrypted backup + CSV) and **crypto-erase** delete
- First-launch onboarding capturing real anchors (honest "I don't know" → no fabricated values)
- iOS data layer + native bridge **foundation** (xcframework, HealthKit mapping, encryption proven)

🔲 **Not yet done (the next phase):**
- **Visual design pass** — the app currently renders through a neutral design-token layer (functional, not yet the final look). The architecture is set up so the real design is largely a token-layer swap.
- **iOS built end-to-end** — foundation is in; needs a real `flutter build ios` on a Mac with simulator runtime + signing.
- **Release/store steps** — keystore, Play Console, store listing, privacy policy (drafts in `RELEASE_CHECKLIST.md`).
- **Tier 3 Josi** — deferred to a later phase (separate model-training track).

⚠️ **Honest caveat for technical reviewers:** the engine's coaching
*constants* (thresholds, recovery curves) are **DRAFT** — grounded in
sport-science literature (Meeusen, Banister, Seiler, Foster, Lolli…) and
reviewed, but **not yet validated against real-athlete data**. The
architecture is sound; field validation is outstanding work.

---

## 6. Where an engineering partner could add value

- **Design implementation** — turn the design-token layer into the finished
  visual product.
- **iOS build-out & release** — complete the iOS build/signing pipeline and
  drive both platforms to store submission.
- **QA & device testing** — real-device matrix, Health Connect / HealthKit
  edge cases, release-build (R8) verification.
- **Field validation tooling** — help validate the engine's draft constants
  against real athlete data.

---

## 7. The non-negotiables (please preserve in any work)

1. **Computation stays in Rust.** No coaching logic, thresholds, or math in
   Dart — the app is display only.
2. **On-device only.** No cloud round-trips for user data. The only network
   exception is a one-time model download for Tier-3 Josi (and even that is
   download-only — nothing about the user is uploaded).
3. **No fabrication.** If a value is unknown, the app says so — it never
   invents numbers (e.g. an unknown FTP is stored as null, not guessed).
4. **Encryption + erasure are load-bearing.** SQLCipher vault; delete =
   destroy the key. This is the product's core promise, not a feature.
