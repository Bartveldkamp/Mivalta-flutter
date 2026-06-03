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

## 2. The tiers

Three product tiers — **Monitor / Advisory / Coach**. See [`TIERS.md`](TIERS.md)
for the canonical definition. (These are *product/pricing* tiers, named — not
to be confused with the engine's "Tier 1/2/3" architecture axis in the
rust-engine's `W1_SPEC.md`, which is Viterbi / GATC / Josi.)

| Tier | Price | What the user gets | Josi (LLM) | Engine |
|------|-------|--------------------|-----------|--------|
| **Monitor** | **Free** | Biometric numbers, stats, readiness/state — display only. No account, no network. | ❌ | ViterbiEngine |
| **Advisory** | **Paid** | Monitor + Josi (explains, interactive) + a single-day training idea | ✅ | + AdvisorEngine + Josi |
| **Coach** | **Paid (higher)** | Advisory + full long-term periodized plan, adjusts on request | ✅ | + PlanEngine + ReplanEngine + Josi |

Josi (the on-device LLM) switches on at **Advisory** and stays through
**Coach**; the free **Monitor** has no LLM at all. Build status: the *engine*
behind all three tiers exists today; **Josi (model W) is in development** and is
what gates the paid tiers, and the **entitlement gating itself is future work**
(today's build shows all surfaces open).

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
| **Mivalta-flutter** | The cross-platform app (Android + iOS), Dart. | `CLAUDE.md` → `docs/MIVALTA_OVERVIEW.md` (this file) → `docs/TIERS.md` → `docs/DISTRIBUTION_AND_TIERS.md` → `docs/RELEASE_CHECKLIST.md` |

Two repos **not** in scope for this review: `mivalta-android-client` (legacy
native app, superseded by Flutter) and `mivalta-science-engine` (the Josi
model-training track, relevant only if the LLM is in Apadmi's scope).

---

## 5. What's built today (honest status)

✅ **Functionally complete and connected:**
- The **Monitor** and **Advisory** *engine* (readiness/state + A/B/C workout suggestions), running on real biometrics
- Android end-to-end: Health Connect + Apple Health + manual ingest → engine → readiness/advice
- On-device **SQLCipher** encryption; data export (encrypted backup + CSV) and **crypto-erase** delete
- First-launch onboarding capturing real anchors (honest "I don't know" → no fabricated values)
- iOS data layer + native bridge **foundation** (xcframework, HealthKit mapping, encryption proven)
- **Zero network** — the app holds no INTERNET permission

🔲 **Not yet done (the next phase):**
- **Josi (the LLM, model W)** — in development on a separate model-training track; it's what unlocks the paid **Advisory** and **Coach** tiers.
- **Tier gating / accounts / website upgrade** — the paywall mechanics; today's build shows all surfaces open.
- **Visual design pass** — the app currently renders through a neutral design-token layer (functional, not yet the final look). The architecture is set up so the real design is largely a token-layer swap.
- **iOS built end-to-end** — foundation is in; needs a real `flutter build ios` on a Mac with simulator runtime + signing.
- **Release/store steps** — keystore, Play Console, store listing, privacy policy (drafts in `RELEASE_CHECKLIST.md`).

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
2. **On-device only.** No cloud round-trips for user data. The app holds no
   INTERNET permission today; when the paid tiers ship, the Josi model (W) is
   delivered via Play Asset Delivery (download-only — nothing about the user is
   uploaded).
3. **No fabrication.** If a value is unknown, the app says so — it never
   invents numbers (e.g. an unknown FTP is stored as null, not guessed).
4. **Encryption + erasure are load-bearing.** SQLCipher vault; delete =
   destroy the key. This is the product's core promise, not a feature.
