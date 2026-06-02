#!/bin/bash
# Build iOS xcframework from Rust source.
#
# Creates MivaltaRustBridge.xcframework with:
#   - ios-arm64 (device)
#   - ios-arm64_x86_64-simulator (simulator fat binary)
#
# Prerequisites:
#   - Xcode installed at /Applications/Xcode.app
#   - Rust targets: rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
#   - xcode-select pointing to Xcode.app (not CommandLineTools)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RUST_DIR="$PROJECT_ROOT/rust"
FRAMEWORKS_DIR="$PROJECT_ROOT/ios/Frameworks/MivaltaRustBridge"
XCFRAMEWORK_DIR="$FRAMEWORKS_DIR/MivaltaRustBridge.xcframework"

# SDK paths
IPHONEOS_SDK="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
IPHONESIMULATOR_SDK="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"

echo "=== Building iOS xcframework from Rust source ==="
echo "Project root: $PROJECT_ROOT"
echo "Rust crate: $RUST_DIR"
echo ""

# Verify Xcode SDK paths exist
if [[ ! -d "$IPHONEOS_SDK" ]]; then
    echo "ERROR: iPhoneOS SDK not found at $IPHONEOS_SDK"
    echo "Install Xcode from the App Store and ensure iOS platform is installed."
    exit 1
fi

if [[ ! -d "$IPHONESIMULATOR_SDK" ]]; then
    echo "ERROR: iPhoneSimulator SDK not found at $IPHONESIMULATOR_SDK"
    echo "Install Xcode from the App Store and ensure iOS Simulator platform is installed."
    exit 1
fi

# Clean previous xcframework
rm -rf "$XCFRAMEWORK_DIR"
mkdir -p "$FRAMEWORKS_DIR"

# Build for iOS device (arm64)
echo "=== Building aarch64-apple-ios (device) ==="
SDKROOT="$IPHONEOS_SDK" cargo build \
    --manifest-path "$RUST_DIR/Cargo.toml" \
    --target aarch64-apple-ios \
    --release

# Build for iOS simulator (arm64)
echo "=== Building aarch64-apple-ios-sim (simulator arm64) ==="
SDKROOT="$IPHONESIMULATOR_SDK" cargo build \
    --manifest-path "$RUST_DIR/Cargo.toml" \
    --target aarch64-apple-ios-sim \
    --release

# Build for iOS simulator (x86_64)
echo "=== Building x86_64-apple-ios (simulator x86_64) ==="
SDKROOT="$IPHONESIMULATOR_SDK" cargo build \
    --manifest-path "$RUST_DIR/Cargo.toml" \
    --target x86_64-apple-ios \
    --release

# Create fat library for simulator (arm64 + x86_64)
echo "=== Creating simulator fat library ==="
DEVICE_LIB="$RUST_DIR/target/aarch64-apple-ios/release/libmivalta_rust_bridge.a"
SIM_ARM64_LIB="$RUST_DIR/target/aarch64-apple-ios-sim/release/libmivalta_rust_bridge.a"
SIM_X86_LIB="$RUST_DIR/target/x86_64-apple-ios/release/libmivalta_rust_bridge.a"
SIM_FAT_LIB="/tmp/libmivalta_rust_bridge_sim.a"

lipo -create "$SIM_ARM64_LIB" "$SIM_X86_LIB" -output "$SIM_FAT_LIB"
echo "Created fat library: $SIM_FAT_LIB"
lipo -info "$SIM_FAT_LIB"

# Create xcframework
echo "=== Creating xcframework ==="
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -create-xcframework \
    -library "$DEVICE_LIB" \
    -library "$SIM_FAT_LIB" \
    -output "$XCFRAMEWORK_DIR"

echo ""
echo "=== xcframework created successfully ==="
echo "Location: $XCFRAMEWORK_DIR"
ls -la "$XCFRAMEWORK_DIR"
