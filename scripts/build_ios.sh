#!/bin/bash
# Atomic iOS build — Layer-3 drift-guard (2026-06-17).
#
# WHY THIS EXISTS: the day-long "expected i32" hash-mismatch hunt was a Layer-3
# BUILD problem wearing a Layer-2 mask. Codegen and the native build were
# hand-ordered, so a stale binary could be packaged against fresh bindings (or
# fresh bindings committed against a stale binary) — and the only symptom was a
# runtime type error on the simulator, chased with slow visible-app cycles.
#
# This script makes the build ATOMIC and refuses to package stale:
#   1. flutter_rust_bridge_codegen generate    — regenerate the FFI bindings
#   2. assert `git diff` is EMPTY on the generated files   <-- THE GUARD
#   3. build + package the xcframework (build_ios_xcframework.sh)
#
# Step 2 is the whole point. After codegen, if anything changed, the COMMITTED
# bindings did not match rust/src/api.rs — i.e. they were stale. STOP before
# building: commit the regenerated files, then re-run. A green run proves the
# committed Dart bindings (lib/src/rust/) AND the rust glue (rust/src/
# frb_generated.rs) exactly match the shim, so the .so packaged in step 3
# cannot be stale against them. The class of bug that cost the day fails here,
# in seconds, instead of on the simulator.
#
# Prereqs:
#   - flutter_rust_bridge_codegen pinned to 2.12.0 (matches rust/Cargo.toml +
#     pubspec.yaml; install: `cargo install flutter_rust_bridge_codegen
#     --version 2.12.0 --locked`).
#   - The Xcode/Rust-target prereqs of build_ios_xcframework.sh.
#   - Run from a committed tree (so the diff reflects codegen output, not your
#     own uncommitted edits).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Every path flutter_rust_bridge_codegen writes (both sides of the boundary).
GEN_PATHS=(lib/src/rust rust/src/frb_generated.rs)

echo "=== [1/3] flutter_rust_bridge_codegen generate ==="
flutter_rust_bridge_codegen generate

echo "=== [2/3] drift-guard: committed bindings must match the shim ==="
if ! git diff --quiet -- "${GEN_PATHS[@]}"; then
    echo ""
    echo "ERROR: FRB bindings are STALE — codegen produced changes that are not committed."
    echo "The committed bindings do not match rust/src/api.rs. Packaging now would ship"
    echo "a binary against bindings that don't match it (the 'expected i32' class)."
    echo "Fix: commit the regenerated files below, then re-run this script."
    echo ""
    git --no-pager diff --stat -- "${GEN_PATHS[@]}"
    exit 1
fi
echo "bindings match the shim — safe to build."

echo "=== [3/3] build + package xcframework ==="
exec "$SCRIPT_DIR/build_ios_xcframework.sh"
