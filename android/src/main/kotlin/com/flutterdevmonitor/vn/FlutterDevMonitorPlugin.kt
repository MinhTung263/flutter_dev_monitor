package com.flutterdevmonitor.vn

import android.app.ActivityManager
import android.app.usage.StorageStatsManager
import android.content.Context
import android.os.Build
import android.os.Debug
import android.os.Environment
import android.os.Process
import android.os.StatFs
import android.os.storage.StorageManager
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
    private val backgroundExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()

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
                backgroundExecutor.execute {
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
                }
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
                    } catch (_: Exception) {}
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
        try {
            backgroundExecutor.shutdown()
        } catch (_: Exception) {}
    }

    private fun getHardwareStats(): Map<String, Any> {
        val ramUsed = getRamUsedMb()
        val ramTotal = getRamTotalMb()
        val appDiskUsed = getAppDiskUsedMb()
        val diskTotal = getDiskTotalGb()
        val diskFree = getDiskFreeGb()

        return mapOf(
            "ramUsed" to ramUsed,
            "ramTotal" to ramTotal,
            "appDiskUsed" to appDiskUsed,
            "diskTotal" to diskTotal,
            "diskFree" to diskFree
        )
    }

    private fun getRamUsedMb(): Double {
        var ramUsed = 0.0
        // 1. Try ActivityManager.getProcessMemoryInfo (most reliable on Android & Xiaomi MIUI)
        try {
            val actManager = applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            if (actManager != null) {
                val pids = intArrayOf(Process.myPid())
                val memInfos = actManager.getProcessMemoryInfo(pids)
                if (memInfos.isNotEmpty() && memInfos[0].totalPss > 0) {
                    ramUsed = memInfos[0].totalPss / 1024.0
                }
            }
        } catch (_: Exception) {}

        // 2. Fallback to Debug.getMemoryInfo
        if (ramUsed <= 0.0) {
            try {
                val memInfo = Debug.MemoryInfo()
                Debug.getMemoryInfo(memInfo)
                if (memInfo.totalPss > 0) {
                    ramUsed = memInfo.totalPss / 1024.0
                }
            } catch (_: Exception) {}
        }

        // 3. Fallback to Runtime heap + Native heap (guaranteed non-zero)
        if (ramUsed <= 0.0) {
            try {
                val runtime = Runtime.getRuntime()
                val heapUsed = runtime.totalMemory() - runtime.freeMemory()
                val nativeUsed = Debug.getNativeHeapAllocatedSize()
                ramUsed = (heapUsed + nativeUsed) / (1024.0 * 1024.0)
            } catch (_: Exception) {}
        }

        return Math.round(ramUsed * 10.0) / 10.0
    }

    private fun getRamTotalMb(): Double {
        try {
            val actManager = applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val sysMemInfo = ActivityManager.MemoryInfo()
            actManager?.getMemoryInfo(sysMemInfo)
            if (sysMemInfo.totalMem > 0) {
                return sysMemInfo.totalMem / (1024.0 * 1024.0)
            }
        } catch (_: Exception) {}
        return 4096.0
    }

    private fun getAppDiskUsedMb(): Double {
        val now = System.currentTimeMillis()
        if (cachedAppDiskUsed > 0.0 && now - lastDiskUsedCheckTime < 60000) {
            return cachedAppDiskUsed
        }

        // 1. Android 8.0+ (API 26+) StorageStatsManager: instantaneous and 100% permission-safe
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val storageStatsManager = applicationContext.getSystemService(Context.STORAGE_STATS_SERVICE) as? StorageStatsManager
                val appInfo = applicationContext.applicationInfo
                if (storageStatsManager != null && appInfo != null) {
                    val stats = storageStatsManager.queryStatsForUid(appInfo.storageUuid, appInfo.uid)
                    val dataAndCacheBytes = stats.dataBytes + stats.cacheBytes
                    if (dataAndCacheBytes > 0) {
                        cachedAppDiskUsed = Math.round((dataAndCacheBytes / (1024.0 * 1024.0)) * 10.0) / 10.0
                        lastDiskUsedCheckTime = now
                        return cachedAppDiskUsed
                    }
                }
            } catch (_: Exception) {}
        }

        // 2. Safe directory traversal (skips lib symlinks and suppresses permission errors on Xiaomi)
        try {
            var totalBytes = 0L
            val dirsToScan = mutableListOf<File>()

            applicationContext.filesDir?.let { dirsToScan.add(it) }
            applicationContext.cacheDir?.let { dirsToScan.add(it) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                applicationContext.codeCacheDir?.let { dirsToScan.add(it) }
            }
            try {
                applicationContext.externalCacheDir?.let { dirsToScan.add(it) }
                applicationContext.getExternalFilesDir(null)?.let { dirsToScan.add(it) }
            } catch (_: Exception) {}

            try {
                val dataDir = File(applicationContext.applicationInfo.dataDir)
                File(dataDir, "databases").takeIf { it.exists() }?.let { dirsToScan.add(it) }
                File(dataDir, "shared_prefs").takeIf { it.exists() }?.let { dirsToScan.add(it) }
                File(dataDir, "app_flutter").takeIf { it.exists() }?.let { dirsToScan.add(it) }
            } catch (_: Exception) {}

            for (dir in dirsToScan) {
                totalBytes += getDirBytesSafe(dir)
            }

            cachedAppDiskUsed = Math.round((totalBytes / (1024.0 * 1024.0)) * 10.0) / 10.0
            lastDiskUsedCheckTime = now
        } catch (_: Exception) {}

        return cachedAppDiskUsed
    }

    private fun getDiskTotalGb(): Double {
        // 1. StorageStatsManager.getTotalBytes(UUID_DEFAULT) reports true device flash capacity (API 26+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val storageStatsManager = applicationContext.getSystemService(Context.STORAGE_STATS_SERVICE) as? StorageStatsManager
                if (storageStatsManager != null) {
                    val totalBytes = storageStatsManager.getTotalBytes(StorageManager.UUID_DEFAULT)
                    if (totalBytes > 0) {
                        return roundToCommercialStorageTier(totalBytes)
                    }
                }
            } catch (_: Exception) {}
        }

        // 2. Fallback: StatFs on Environment.getDataDirectory() (/data)
        try {
            val stat = StatFs(Environment.getDataDirectory().path)
            if (stat.totalBytes > 0) {
                return roundToCommercialStorageTier(stat.totalBytes)
            }
        } catch (_: Exception) {}

        // 3. Fallback: applicationInfo.dataDir
        try {
            val stat = StatFs(applicationContext.applicationInfo.dataDir)
            if (stat.totalBytes > 0) {
                return roundToCommercialStorageTier(stat.totalBytes)
            }
        } catch (_: Exception) {}

        return 0.0
    }

    private fun getDiskFreeGb(): Double {
        return try {
            val stat = StatFs(Environment.getDataDirectory().path)
            Math.round((stat.availableBytes / (1024.0 * 1024.0 * 1024.0)) * 10.0) / 10.0
        } catch (_: Exception) {
            0.0
        }
    }

    private fun roundToCommercialStorageTier(bytes: Long): Double {
        if (bytes <= 0) return 0.0
        val gbDecimal = bytes / 1_000_000_000.0
        val gbBinary = bytes / (1024.0 * 1024.0 * 1024.0)

        // Matches commercial advertised storage tiers (accounting for OEM system partition reservations)
        val standardTiers = doubleArrayOf(16.0, 32.0, 64.0, 128.0, 256.0, 512.0, 1024.0)
        for (tier in standardTiers) {
            if (gbDecimal in (tier * 0.70)..(tier * 1.08) || gbBinary in (tier * 0.65)..(tier * 1.05)) {
                return tier
            }
        }
        return Math.round(gbBinary * 10.0) / 10.0
    }

    private fun getDirBytesSafe(dir: File?): Long {
        if (dir == null || !dir.exists()) return 0L
        return try {
            dir.walkTopDown()
                .onFail { _, _ -> /* Suppress permission/access errors safely on MIUI/Xiaomi */ }
                .filter { file ->
                    try {
                        !file.name.equals("lib", ignoreCase = true) && file.isFile
                    } catch (_: Exception) {
                        false
                    }
                }
                .sumOf { file ->
                    try {
                        file.length()
                    } catch (_: Exception) {
                        0L
                    }
                }
        } catch (_: Exception) {
            0L
        }
    }
}
