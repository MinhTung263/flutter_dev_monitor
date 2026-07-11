import 'dart:io';

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
  }

  Future<String> fetchDeviceModel() async {
    try {
      if (Platform.isIOS) {
        final data = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDeviceModel');
        if (data != null) {
          final machine = data['machine'] as String? ?? '';
          final systemVersion = data['systemVersion'] as String? ?? '';
          final model = kIosDeviceMap[machine] ?? machine;
          return '$model • iOS $systemVersion';
        }
      } else if (Platform.isAndroid) {
        final model = await _channel.invokeMethod<String>('getDeviceModel');
        if (model != null) return model;
      }
    } catch (_) {}
    return Platform.isIOS ? 'iPhone' : 'Android';
  }
}
