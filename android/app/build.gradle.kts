plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mivalta.mivalta_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mivalta.mivalta_flutter"
        // llama-cpp-dart.aar (Day 1) requires minSdk 26 (Android 8.0);
        // the rust-engine bridge .so files (Day 2) were built with
        // cargo-ndk --platform 21, so 26 is the binding constraint.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // arm64-v8a is the only ABI shipped — Day-1 llama_cpp_dart AAR
        // ships jniLibs/arm64-v8a/lib*.so, and Day-2 rust-bridge .so
        // files (libgatc_ffi.so + libmivalta_rust_bridge.so) under
        // src/main/jniLibs/arm64-v8a/ match. No other ABI has native libs.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
