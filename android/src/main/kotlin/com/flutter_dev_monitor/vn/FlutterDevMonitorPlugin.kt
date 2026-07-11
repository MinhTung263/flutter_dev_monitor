package com.flutter_dev_monitor.vn

import android.app.ActivityManager
import android.content.Context
import android.os.Debug
import android.os.StatFs
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

class FlutterDevMonitorPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context
    private var lastDiskUsedCheckTime: Long = 0
    private var cachedAppDiskUsed: Double = 0.0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(
            binding.binaryMessenger,
            "flutter_dev_monitor/system_monitor"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getSystemHardware" -> {
                val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
                Thread {
                    try {
                        val stats = getHardwareStats()
                        mainHandler.post {
                            result.success(stats)
                        }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("ERROR", e.message, null)
                        }
                    }
                }.start()
            }
            "getDeviceModel" -> {
                val brand = android.os.Build.BRAND.let {
                    if (it.isNotEmpty()) it[0].uppercaseChar() + it.substring(1) else android.os.Build.MANUFACTURER
                }
                val model = android.os.Build.MODEL
                val release = android.os.Build.VERSION.RELEASE
                result.success("$brand $model • Android $release")
            }
            "getTheme" -> {
                val prefs = applicationContext.getSharedPreferences(
                    "flutter_dev_monitor", android.content.Context.MODE_PRIVATE)
                result.success(prefs.getBoolean("dark_theme", false))
            }
            "setTheme" -> {
                val isDark = call.arguments as? Boolean ?: true
                applicationContext.getSharedPreferences(
                    "flutter_dev_monitor", android.content.Context.MODE_PRIVATE)
                    .edit().putBoolean("dark_theme", isDark).apply()
                result.success(null)
            }
            "getOverlayConfig" -> {
                val prefs = applicationContext.getSharedPreferences(
                    "flutter_dev_monitor", android.content.Context.MODE_PRIVATE)
                val jsonStr = prefs.getString("overlay_config", null)
                if (jsonStr != null) {
                    try {
                        val map = org.json.JSONObject(jsonStr)
                        val resultData = mutableMapOf<String, Any>()
                        val keys = map.keys()
                        while (keys.hasNext()) {
                            val key = keys.next()
                            resultData[key] = map.get(key)
                        }
                        result.success(resultData)
                        return
                    } catch (e: Exception) {}
                }
                result.success(mapOf<String, Any>())
            }
            "saveOverlayConfig" -> {
                val dict = call.arguments as? Map<String, Any>
                if (dict != null) {
                    val jsonStr = org.json.JSONObject(dict).toString()
                    applicationContext.getSharedPreferences(
                        "flutter_dev_monitor", android.content.Context.MODE_PRIVATE)
                        .edit().putString("overlay_config", jsonStr).apply()
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun getHardwareStats(): Map<String, Any> {
        // App RAM usage via PSS (MB)
        val memInfo = Debug.MemoryInfo()
        Debug.getMemoryInfo(memInfo)
        val ramUsed = memInfo.totalPss / 1024.0

        // Total physical RAM (MB)
        val actManager = applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val sysMemInfo = ActivityManager.MemoryInfo()
        actManager.getMemoryInfo(sysMemInfo)
        val ramTotal = sysMemInfo.totalMem / (1024.0 * 1024.0)

        // App disk usage (MB) - throttled to 5 minutes
        val now = System.currentTimeMillis()
        if (now - lastDiskUsedCheckTime > 300000) {
            val dataDir = File(applicationContext.applicationInfo.dataDir)
            cachedAppDiskUsed = getDirBytes(dataDir) / (1024.0 * 1024.0)
            lastDiskUsedCheckTime = now
        }

        // Total disk (GB)
        val dataDir = File(applicationContext.applicationInfo.dataDir)
        val stat = StatFs(dataDir.path)
        val diskTotal = stat.totalBytes / (1024.0 * 1024.0 * 1024.0)

        return mapOf(
            "ramUsed" to ramUsed,
            "ramTotal" to ramTotal,
            "appDiskUsed" to cachedAppDiskUsed,
            "diskTotal" to diskTotal
        )
    }

    private fun getDirBytes(dir: File?): Long {
        if (dir == null || !dir.exists()) return 0
        return dir.walkTopDown().filter { it.isFile }.sumOf { it.length() }
    }
}
