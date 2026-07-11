import Flutter
import UIKit

public class FlutterDevMonitorPlugin: NSObject, FlutterPlugin {
    private var lastDiskUsedCheckTime: Double = 0
    private var cachedAppDiskUsed: Double = 0.0

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_dev_monitor/system_monitor",
            binaryMessenger: registrar.messenger()
        )
        let instance = FlutterDevMonitorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getSystemHardware":
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else {
                    result(nil)
                    return
                }
                let stats = self.getIosHardwareStats()
                DispatchQueue.main.async {
                    result(stats)
                }
            }
        case "getDeviceModel":
            var systemInfo = utsname()
            uname(&systemInfo)
            let machineMirror = Mirror(reflecting: systemInfo.machine)
            let machine = machineMirror.children.reduce("") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else { return identifier }
                return identifier + String(UnicodeScalar(UInt8(value)))
            }
            let systemVersion = UIDevice.current.systemVersion
            result([
                "machine": machine,
                "systemVersion": systemVersion
            ])
        case "getTheme":
            let saved = UserDefaults.standard.object(forKey: "flutter_dev_monitor_dark_theme")
            result(saved as? Bool ?? false)
        case "setTheme":
            if let isDark = call.arguments as? Bool {
                UserDefaults.standard.set(isDark, forKey: "flutter_dev_monitor_dark_theme")
            }
            result(nil)
        case "getOverlayConfig":
            let saved = UserDefaults.standard.dictionary(forKey: "flutter_dev_monitor_overlay_config")
            result(saved ?? [:])
        case "saveOverlayConfig":
            if let dict = call.arguments as? [String: Any] {
                UserDefaults.standard.set(dict, forKey: "flutter_dev_monitor_overlay_config")
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getIosHardwareStats() -> [String: Any] {
        let ramTotal = Double(ProcessInfo.processInfo.physicalMemory) / (1024.0 * 1024.0)

        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        let ramUsed = kerr == KERN_SUCCESS
            ? Double(info.resident_size) / (1024.0 * 1024.0)
            : 0.0

        let now = Date().timeIntervalSince1970
        if now - lastDiskUsedCheckTime > 300 {
            let homePath = NSHomeDirectory()
            cachedAppDiskUsed = getDirectorySize(url: URL(fileURLWithPath: homePath))
            lastDiskUsedCheckTime = now
        }

        var diskTotal: Double = 0.0
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let space = attrs[.systemSize] as? Int64 {
            diskTotal = Double(space) / (1024.0 * 1024.0 * 1024.0)
        }

        return [
            "ramUsed": ramUsed,
            "ramTotal": ramTotal,
            "appDiskUsed": cachedAppDiskUsed,
            "diskTotal": diskTotal
        ]
    }

    private func getDirectorySize(url: URL) -> Double {
        let fileManager = FileManager.default
        var totalSize: UInt64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [],
            errorHandler: nil
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += UInt64(fileSize)
            }
        }
        return Double(totalSize) / (1024.0 * 1024.0)
    }
}
