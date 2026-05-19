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
        // llama-cpp-dart.aar requires minSdk 26 (Android 8.0).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // V10.1 spike is arm64-v8a only — matches the AAR's jniLibs.
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
