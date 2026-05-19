package com.mivalta.mivalta_flutter

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Debug
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.FileInputStream
import java.security.MessageDigest

/**
 * Day-7 hardware-verification channel. Exposes three calls used by
 * the V10.1 telemetry overlay on SpikeHome:
 *
 *   - `pssKb`        : current process PSS in KB (Debug.MemoryInfo).
 *   - `deviceModel`  : Build.MODEL (e.g. "edge 60").
 *   - `osRelease`    : Build.VERSION.RELEASE (e.g. "14").
 *
 * The PSS read is sampled every 250ms during a V10.1 run from the
 * Dart side via a Timer; this method just returns the latest snapshot
 * each call. No event channels needed — keeping the surface small
 * because the spike-close runbook only formats numbers.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.mivalta.flutter/hw_telemetry"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pssKb" -> result.success(readPssKb())
                    "deviceModel" -> result.success(Build.MODEL ?: "unknown")
                    "osRelease" -> result.success(Build.VERSION.RELEASE ?: "unknown")
                    "apkSha256" -> result.success(readApkSha256())
                    else -> result.notImplemented()
                }
            }
    }

    private fun readApkSha256(): String {
        // Hash the running APK file once per call. The result matches
        // `sha256sum app-debug.apk` on Hetzner, so the founder's
        // results doc lines up with the build artifact identity.
        return try {
            val path = applicationInfo.sourceDir
            val md = MessageDigest.getInstance("SHA-256")
            FileInputStream(path).use { fis ->
                val buf = ByteArray(64 * 1024)
                while (true) {
                    val n = fis.read(buf)
                    if (n < 0) break
                    md.update(buf, 0, n)
                }
            }
            md.digest().joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            "error:${e.javaClass.simpleName}"
        }
    }

    private fun readPssKb(): Int {
        // Debug.MemoryInfo.totalPss is the canonical "how much memory
        // does this process actually own" number — same value `adb
        // shell dumpsys meminfo` reports. Returns KB. We pull the
        // single-process variant via ActivityManager so we don't have
        // to ask the OS for any privileged data.
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val pid = android.os.Process.myPid()
        val infos = am.getProcessMemoryInfo(intArrayOf(pid))
        return infos.firstOrNull()?.totalPss ?: -1
    }
}
