import Flutter
import UIKit

public class FlutterDevMonitorPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_dev_monitor/system_monitor",
            binaryMessenger: registrar.messenger()
        )
        let instance = FlutterDevMonitorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getSystemHardware" {
            result(getIosHardwareStats())
        } else {
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

        let homePath = NSHomeDirectory()
        let appDiskUsed = getDirectorySize(url: URL(fileURLWithPath: homePath))

        var diskTotal: Double = 0.0
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let space = attrs[.systemSize] as? Int64 {
            diskTotal = Double(space) / (1024.0 * 1024.0 * 1024.0)
        }

        return [
            "ramUsed": ramUsed,
            "ramTotal": ramTotal,
            "appDiskUsed": appDiskUsed,
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
