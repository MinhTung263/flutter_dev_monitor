import 'package:flutter/services.dart';
import '../core/monitor_constants.dart';

class OverlayConfig {
  final double? top;
  final double? left;
  final bool positionInit;
  final bool? isExpanded;
  final int? gridModeIndex;
  final bool isTucked;
  final bool tuckedLeft;
  final bool wasExpandedBeforeTuck;

  const OverlayConfig({
    this.top,
    this.left,
    this.positionInit = false,
    this.isExpanded,
    this.gridModeIndex,
    this.isTucked = false,
    this.tuckedLeft = false,
    this.wasExpandedBeforeTuck = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'top': top,
      'left': left,
      'positionInit': positionInit,
      'isExpanded': isExpanded,
      'gridMode': gridModeIndex,
      'isTucked': isTucked,
      'tuckedLeft': tuckedLeft,
      'wasExpandedBeforeTuck': wasExpandedBeforeTuck,
    };
  }

  factory OverlayConfig.fromMap(Map<dynamic, dynamic> map) {
    return OverlayConfig(
      top: map['top'] as double?,
      left: map['left'] as double?,
      positionInit: map['positionInit'] as bool? ?? false,
      isExpanded: map['isExpanded'] as bool?,
      gridModeIndex: map['gridMode'] as int?,
      isTucked: map['isTucked'] as bool? ?? false,
      tuckedLeft: map['tuckedLeft'] as bool? ?? false,
      wasExpandedBeforeTuck: map['wasExpandedBeforeTuck'] as bool? ?? false,
    );
  }
}

class OverlayStorageDatasource {
  static const _channel = MethodChannel(MonitorConstants.hardwareChannel);

  Future<void> save(OverlayConfig config) async {
    try {
      await _channel.invokeMethod<void>('saveOverlayConfig', config.toMap());
    } catch (_) {}
  }

  Future<OverlayConfig?> load() async {
    try {
      final data =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getOverlayConfig');
      if (data == null || data.isEmpty) return null;
      return OverlayConfig.fromMap(data);
    } catch (_) {
      return null;
    }
  }
}
