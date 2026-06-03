# PR-I: ProGuard/R8 keep rules for MiValta release builds.
#
# Native bindings loaded via System.loadLibrary() need JNI method stubs
# preserved. Without these rules, R8 strips the Java-side JNI declarations
# and native calls crash at runtime.
#
# WARNING: If you add a new native library or FFI binding, add keep rules here.

# =============================================================================
# FLUTTER RUST BRIDGE — rust/src/frb_generated.rs ↔ lib/src/rust/frb_generated.dart
# =============================================================================
#
# FRB generates a RustLib class with native method declarations that call into
# libmivalta_rust_bridge.so. R8 must not strip these.

-keep class com.mivalta.mivalta_flutter.** { *; }

# Keep all native method declarations in any class.
# This is the catch-all for JNI — ensures System.loadLibrary targets survive.
-keepclasseswithmembernames class * {
    native <methods>;
}

# =============================================================================
# HEALTH PLUGIN — Health Connect API access via reflection
# =============================================================================
#
# The `health` plugin uses reflection to access Health Connect APIs.
# Keep the plugin classes and Health Connect SDK classes.

-keep class cachet.plugins.health.** { *; }
-keep class androidx.health.connect.client.** { *; }

# Health Connect permission-related classes
-keep class androidx.health.** { *; }

# =============================================================================
# SHARE_PLUS PLUGIN — platform share sheet
# =============================================================================

-keep class dev.fluttercommunity.plus.share.** { *; }

# =============================================================================
# DEVICE_INFO_PLUS PLUGIN — hardware telemetry
# =============================================================================

-keep class dev.fluttercommunity.plus.device_info.** { *; }

# =============================================================================
# FLUTTER ENGINE — standard Flutter keep rules
# =============================================================================

# Keep Flutter embedding classes
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Dart VM snapshot data access
-keep class io.flutter.view.FlutterMain { *; }
-keep class io.flutter.view.FlutterNativeView { *; }

# =============================================================================
# PATH_PROVIDER PLUGIN — file system access
# =============================================================================

-keep class io.flutter.plugins.pathprovider.** { *; }

# =============================================================================
# GENERAL SAFETY — don't strip Kotlin metadata, serialization
# =============================================================================

# Keep Kotlin metadata for reflection
-keep class kotlin.Metadata { *; }

# Don't warn about missing javax.annotation classes (not needed at runtime)
-dontwarn javax.annotation.**

# Don't warn about missing Kotlin reflect classes if not using full reflection
-dontwarn kotlin.reflect.jvm.internal.**

# =============================================================================
# PLAY CORE — deferred components (Flutter engine references these)
#
# MiValta doesn't use deferred components, but Flutter engine includes
# PlayStoreDeferredComponentManager which references these classes.
# =============================================================================

-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# =============================================================================
# DEBUGGING — uncomment to get clearer stack traces in release crashes
# =============================================================================

# -keepattributes SourceFile,LineNumberTable
# -renamesourcefileattribute SourceFile
