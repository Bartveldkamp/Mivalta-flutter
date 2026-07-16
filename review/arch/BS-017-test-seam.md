STATUS: ACTIVE
**Surface:** Flutter test architecture · **Grounded in source:** main @ `ddb9a830` · **Author:** Design seat

# BS-017 — the headless engine seam + test-tier policy

The decision the DR-026 CI burn exposed: how the display layer becomes
testable in the inner loop (cloud CI, headless, no native engine), as one
coherent pattern. Answer below is (a) one seam, (b) one tier policy, (c) the
golden invariant list. This is a small deliberate refactor of the screen
bootstrap seam — not a rush, not a rewrite.

---

## (a) THE SEAM — optional constructor injection, real default
**One pattern, already house style. Do NOT add a provider, InheritedWidget,
or `RustEngineBinding.overrideForTest` global.**

Rationale — this is not a new invention, it is finishing one already in the
tree:
- `AdvisorScreen` / `WorkoutDetailScreen` and every service already take
  `final RustEngineBinding binding; final EnginesHandle handle;` as
  constructor fields, and their headless tests already pump them with
  `_RecordingBinding implements RustEngineBinding` + `_FakeHandle` (88 call
  sites in test/). The seam works; it just isn't on every screen.
- DR-026's clock seam — `DateTime Function()? now` on TodayScreen, optional
  inject with `?? DateTime.now` fallback — is the exact precedent. Extend the
  same idiom to the engine binding.

Rule-9 clean: the double is a **pure fake at the binding seam** (`implements
RustEngineBinding`, returns canned JSON), never a second engine or an
assembler tier. It computes nothing; it replays engine output the test author
pins. Engine still DECIDES, fake just stands in for the wire.

Why not the alternatives:
- **Global `overrideForTest` static** — mutable global → test-order
  fragility, and a second source of truth for "which engine" → Rule-9 smell.
- **Provider / InheritedWidget** — a whole DI tier for one dependency the app
  already passes by constructor everywhere else. Inconsistent, heavier, and
  the screens don't otherwise read context for engine data.

### The refactor (per self-bootstrapping screen)
Add optional params; keep the real path the default so production is byte-for-
byte unchanged:
```dart
const TodayScreen({super.key, this.binding, this.now = DateTime.now});
final RustEngineBinding? binding;      // null in prod → bootstrap()
// initState / _load:
final b = widget.binding ?? await RustEngineBinding.bootstrap();
final h = widget.handle  ?? await b.constructEngines(...);
```
Real app constructs nothing → bootstraps as today. Tests pass a fake binding
whose handle is `_FakeHandle()` → screen pumps headless with zero native
engine. Leaf screens already pushed with a live handle (Advisor,
WorkoutDetail) keep `required` — parent owns construction, passes down.
Screens to seam: Today, You, Journey, Splash, SessionReveal, SensorCheck,
Onboarding.

---

## (b) TEST-TIER POLICY (what runs where, real vs fake engine)

| Tier | Where | Engine | Guards | Inner loop? |
|---|---|---|---|---|
| **1 · Headless widget** | ubuntu `analyze-and-test`, `flutter test` | **Fake** (`_RecordingBinding`) | Every screen's *rendered contract* given canned engine JSON — the corridor invariants in (c) | **Yes — this is the inner loop** |
| **2 · Drift-guard / analyze** | ubuntu | none | FRB binding shape, `flutter analyze`, token adherence | Yes |
| **3 · Sim-witness (final acceptance)** | Mac + iOS sim, witnessed | **Real** (FRB + Rust) | Real compute correctness, full-app navigation flow, visual/token render, timing, notification/permission native layer | **No — never the inner loop** |

**The line:** *renders engine JSON → Tier 1 (headless, fake).* *Requires the
engine to actually compute, or requires the device/native layer → Tier 3
(Mac).* The full-app real-engine corridor (`app.main()` + FRB) stays a Tier-3
Mac witness — it can never run in cloud CI because CI builds no engine (the
DR-026 lesson, already ratified: "the simulator is final acceptance, never
the inner loop"). Its **individual invariants** move down to Tier 1 so drift
is caught headless in CI without a device — ever.

---

## (c) GOLDEN CORRIDOR INVARIANTS (each → one Tier-1 headless widget test)
The contract each screen must render given canned engine JSON. These are the
drift tripwires the F3 bug slipped through because they lived only at Tier 3.

1. **Bottom nav** — `find.byType(MivaltaBottomNav)` present on Today, Journey,
   You; three tabs, correct labels. (The type, not `BottomNavigationBar`.)
2. **You eyebrows — exact strings** — WHO YOU ARE / LEARNING YOU / YOUR
   SOURCES / YOUR DATA, YOUR DEVICE / HOW MIVALTA SPEAKS / DISPLAY. (This is
   the exact contract the F3 'YOUR BODY' bug violated.) Sovereignty banner
   present; erase is red text.
3. **No fabricated values** — a rendered score exists ONLY when engine JSON
   carries it. Score display clamps ≤100 (the F4 tripwire, now a widget
   assertion, matches `(\d+)\s*%`). Engine-absence → honest absence: no
   number, no placeholder, never a composed value.
4. **Josi voice cards** — rendered line is the engine's verbatim string;
   engine failure → the honest fallback ("Logged, not judged." etc.);
   degraded render == normal render (no extra chrome on the sad path).
5. **Today evening swap** — with the clock seam past threshold, the CLOSING
   THE DAY eyebrow + day-summary JosiCard appear; before threshold they do
   not. Summary line is the engine line, never composed in Dart.
6. **Journey day record** — reuses the same JosiCard contract as #4/#5.

Each is a `pumpWidget(Screen(binding: fake..returns pinnedJson))` +
`expect(...)`. No device. Together they are the corridor, headless.

---

## DoD (a small, staged refactor — not one PR)
1. Seam the 7 self-bootstrapping screens (optional binding/handle, real
   default). Production path byte-identical — prove with the existing sim
   witness once after.
2. Land invariants #1–#6 as Tier-1 headless tests in `test/`, fake engine.
3. Full-app real-engine corridor stays in `integration_test/`, Mac-only,
   **out of cloud CI** (DR-026 already removed the CI job — keep it removed).
4. No `Colors.*` / magic numbers introduced; every value token-named.
PR open per stage — no merge without Design source-verify.
