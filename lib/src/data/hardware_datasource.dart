import 'dart:io';
import 'dart:isolate';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

import '../core/monitor_constants.dart';
import 'ios_device_map.dart';

class HardwareSnapshot {
  final double ramUsed;
  final double ramTotal;
  final double appDiskUsed;
  final double diskTotal;

  const HardwareSnapshot({
    required this.ramUsed,
    required this.ramTotal,
    required this.appDiskUsed,
    required this.diskTotal,
  });
}

class HardwareDatasource {
  static const _channel = MethodChannel(MonitorConstants.hardwareChannel);

  Future<HardwareSnapshot?> fetch() async {
    try {
      final data =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getSystemHardware');
      if (data == null) return null;
      return HardwareSnapshot(
        ramUsed: (data['ramUsed'] as num).toDouble(),
        ramTotal: (data['ramTotal'] as num).toDouble(),
        appDiskUsed: (data['appDiskUsed'] as num).toDouble(),
        diskTotal: (data['diskTotal'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<int?> measurePing() async {
    try {
      return await Isolate.run(() async {
        try {
          final sw = Stopwatch()..start();
          final socket = await Socket.connect(
            '1.1.1.1', 80,
            timeout: const Duration(seconds: 2),
          );
          final ms = sw.elapsedMilliseconds;
          socket.destroy();
          return ms;
        } catch (_) {
          return null;
        }
      });
    } catch (_) {
      return null;
    }
  }

  Future<String> fetchDeviceModel() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        final model = kIosDeviceMap[ios.utsname.machine] ?? ios.utsname.machine;
        return '$model • iOS ${ios.systemVersion}';
      } else if (Platform.isAndroid) {
        final android = await info.androidInfo;
        final brand = android.brand.isNotEmpty
            ? android.brand[0].toUpperCase() + android.brand.substring(1)
            : android.manufacturer;
        return '$brand ${android.model} • Android ${android.version.release}';
      }
    } catch (_) {}
    return Platform.isIOS ? 'iPhone' : 'Android';
  }
}
