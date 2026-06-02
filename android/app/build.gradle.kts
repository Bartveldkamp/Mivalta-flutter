// PR-I: Release hardening — signing, R8/minify, ProGuard rules for native bindings.
//
// SIGNING:
// - Debug builds use the default debug keystore (auto-generated).
// - Release builds read from key.properties (gitignored, never committed).
// - If key.properties doesn't exist, release falls back to debug signing
//   (for CI builds that just verify the pipeline compiles).
//
// NATIVE BINDINGS:
// - Rust FFI (libgatc_ffi.so, libmivalta_rust_bridge.so) loaded via System.loadLibrary
// - llama.cpp AAR (libs/llama-cpp-dart.aar) loaded via System.loadLibrary
// - Health plugin uses reflection for Health Connect APIs
// - All require ProGuard keep rules to prevent R8 from stripping JNI entry points.

import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties if it exists (for release signing).
// File is gitignored — each dev/CI creates their own.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    // namespace is for R class generation, can differ from applicationId.
    // Keep aligned with package in AndroidManifest.xml and MainActivity location.
    namespace = "com.mivalta.mivalta_flutter"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // PR-I: Finalized app identity for Play Store.
        // applicationId must never change after first upload — it's the stable identifier.
        applicationId = "com.mivalta.app"

        // SDK levels:
        // - minSdk 26: required by llama-cpp-dart AAR (Android 8.0+)
        // - targetSdk 35: current Play Store requirement (Android 15)
        minSdk = 26
        targetSdk = 35

        // Version: read from pubspec.yaml via Flutter plugin.
        // Bump version in pubspec.yaml, not here.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ABI filter: arm64-v8a only.
        // - llama-cpp-dart AAR ships arm64-v8a only
        // - Rust FFI .so files built for arm64-v8a only
        // Adding other ABIs would cause missing native lib crashes.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    signingConfigs {
        // Release signing config — reads from key.properties.
        // If key.properties doesn't exist, returns null and release falls back to debug.
        create("release") {
            val storePath = keyProperties.getProperty("storeFile")
            if (storePath != null) {
                storeFile = file(storePath)
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // Debug builds: no minification, fast iteration.
            isMinifyEnabled = false
            isShrinkResources = false
        }

        release {
            // PR-I: R8/minify enabled for release.
            // Reduces APK size and enables whole-program optimization.
            isMinifyEnabled = true
            isShrinkResources = true

            // ProGuard rules: keep JNI entry points for native bindings.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // Signing: use release keystore if available, else fall back to debug.
            // This allows CI to build unsigned/debug-signed release APKs for testing.
            val releaseConfig = signingConfigs.findByName("release")
            signingConfig = if (releaseConfig?.storeFile != null) {
                releaseConfig
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // V10.1 perf spike: llama.cpp prebuilt CPU AAR from
    // netdur/llama_cpp_dart v0.9.0-dev.6 GitHub release. sha256:
    // 005fb18cf74a3827f23dddefa9284e57462dbaec7f4d764c0b4f8971a47a0f53
    implementation(files("libs/llama-cpp-dart.aar"))
}
