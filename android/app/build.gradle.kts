// PR-J: Release hardening — signing, R8/minify, ProGuard rules for native bindings.
//
// SIGNING:
// - Debug builds use the default debug keystore (auto-generated).
// - Release builds read from key.properties (gitignored, never committed).
// - If key.properties doesn't exist, release falls back to debug signing
//   (for CI builds that just verify the pipeline compiles).
//
// NATIVE BINDINGS:
// - Rust FFI (libmivalta_rust_bridge.so) loaded via System.loadLibrary
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
    // compileSdk 36: flutter_blue_plus_android (BLE, Task A) requires its
    // dependents to compile against API 36+. compileSdk (which APIs we build
    // against) is independent of targetSdk (runtime behaviour opt-in) and minSdk
    // (install floor) — bumping it does not change Play Store targeting.
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // PR-I: Finalized app identity for Play Store.
        // applicationId must never change after first upload — it's the stable identifier.
        applicationId = "com.mivalta.app"

        // SDK levels:
        // - minSdk 26: Android 8.0+ (Health Connect baseline)
        // - targetSdk 35: current Play Store requirement (Android 15)
        minSdk = 26
        targetSdk = 35

        // Version: read from pubspec.yaml via Flutter plugin.
        // Bump version in pubspec.yaml, not here.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ABI filter: arm64-v8a only.
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
