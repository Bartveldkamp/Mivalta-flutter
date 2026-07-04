# Brief — Flutter engine re-pin to surface `metabolic_level`

**For:** the build executor (Mac). **Scope:** engine-pin bump + build. **No FRB-regen** (proven below).

## Goal
rust-engine `main` (#385) now emits `metabolic_level` on the engine JSON. Re-pin Flutter so the field flows to the app; the display work (Claude Design) then builds the headline against a live field.

## The bump
- `rust/Cargo.toml`: `gatc-ffi` + `gatc-viterbi` rev
  **`a57958458ef8a0bdb74dc80b587070dc0d20a65e` → `7b5e3238048ebb6d0457c6398af268eb37a50859`** (rust-engine `main`).
- Delta is **6 commits, #381–#386** — linear fast-forward (the current pin is a clean ancestor of `main`).
- `cargo update -p gatc-ffi -p gatc-viterbi`.
- `engine_registry` version moves **2.29 → 2.31** — purely additive (see proof).
- Owed: **iOS xcframework rebuild** (Mac-only). Android is proven by the `smoke` CI cross-compile.
- Update `CLAUDE.md` engine-pin section: new rev, delta #381–#386, registry 2.29→2.31 (additive), `metabolic_level` now flows.

## FRB-regen: NOT NEEDED — verified (not inferred)
FRB bindings are generated from the shim `rust/src/api.rs`, which the re-pin does not touch. Bindings can only go stale if the re-pin (a) changes a signature the shim binds, (b) removes a symbol it uses, or (c) changes the shape of a bound type. All three checked against the real code across `a57958458 → 7b5e323`:

1. **All 29 shim-bound symbols — byte-identical signatures.** Extracted every `gatc_ffi::*` the shim calls (7 engine constructors + 26 methods + 3 free functions: `build_onboarding_profile`, `realize_advisor_line`, `hello_uniffi`), then diffed each one's *full multi-line* signature at both revs. **0 changed.** (Extractor validated to return real non-empty signatures — not a false pass.)
2. **`BridgeError` enum — identical.** Same 6 variants (`Vault/Input/State/Policy/Consistency/General`, all `(String)`). The bound error type does not shift.
3. **Registry — additive only.** Zero removals/renames; the new methods (`attach_advisories`, `enable_card_emissions`, `update_power_bests`, `read_power_bests`) are appended and the shim doesn't call them.

**Conclusion:** every symbol the shim references is unchanged, nothing it uses was removed, the error type is stable, and the shim source is untouched → FRB bindings cannot change → **no regen**. The `smoke` CI compile is the final rubber-stamp; `frb-drift-guard` is the mechanical gate if you want belt-and-suspenders.

**Honest limit:** the proof is an exhaustive signature/type diff of every referenced symbol; it is not a literal `cargo build` of the shim crate against `7b5e323` (run in a Flutter toolchain, which the authoring session lacked). A compile break would require exactly the change class ruled out above, so `smoke` confirms rather than tests it.

## Sequence note
`metabolic_level` only becomes *useful* once (a) the first-run onboarding routing fix lands (a real user can create a profile) and (b) the display binds the field (Claude Design, per `docs/DESIGN_DATA_CONTRACT.md`). The re-pin itself is independent and safe to land in parallel — it just makes the field available.

---
*Verified against rust-engine `main` `7b5e323` and Flutter `main` `0036264` (2026-07-04). Field map for the display side: `docs/DESIGN_DATA_CONTRACT.md`.*
