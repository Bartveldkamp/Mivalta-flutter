#!/bin/bash
# SessionStart hook — install the Flutter SDK in Claude Code web sessions so
# `flutter analyze`, `flutter test`, and `flutter_rust_bridge_codegen generate`
# (which shells out to `flutter`) all work in-session. cargo + frb_codegen are
# already present; only the Flutter/Dart SDK is missing.
set -euo pipefail

# Remote (web) sessions only — local machines already have their toolchain.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_VERSION="3.44.0"        # keep in lockstep with .github/workflows CI
FLUTTER_DIR="$HOME/flutter"

# Install once; idempotent (post-hook container state is cached).
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 -b "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
# Persist PATH for the session's subsequent tool calls.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

git config --global --add safe.directory "$FLUTTER_DIR" || true
flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version

# Pre-resolve Dart deps so analyze/test are ready immediately.
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
flutter pub get
