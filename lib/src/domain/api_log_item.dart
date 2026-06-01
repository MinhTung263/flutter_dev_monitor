class ApiLogItem {
  static const String phaseInit = 'INIT';
  static const String phaseRefresh = 'ACTION';

  final int orderNumber;
  final String url;
  final String method;
  final int statusCode;
  final int duration;
  final int responseBytes;
  final String screen;
  final DateTime timestamp;
  final String callerName;
  final String phase;
  final int callCount;
  // Which refresh cycle this log belongs to (0 = init, 1+ = refresh cycles)
  final int refreshCycle;

  const ApiLogItem({
    required this.orderNumber,
    required this.url,
    required this.method,
    required this.statusCode,
    required this.duration,
    required this.screen,
    required this.timestamp,
    this.responseBytes = 0,
    this.callerName = 'unknown',
    this.phase = phaseInit,
    this.callCount = 1,
    this.refreshCycle = 0,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isSlow => duration > 1000;
  bool get isRefresh => phase == phaseRefresh;
  bool get hasCallerName => callerName.isNotEmpty && callerName != 'unknown';
  bool get hasMultipleCalls => callCount > 1;
  bool get hasResponseSize => responseBytes > 0;

  String get responseSizeFormatted {
    if (responseBytes <= 0) return '';
    if (responseBytes < 1024) return '${responseBytes}B';
    if (responseBytes < 1024 * 1024) {
      return '${(responseBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(responseBytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  ApiLogItem copyWith({
    int? orderNumber,
    int? statusCode,
    int? duration,
    int? responseBytes,
    int? callCount,
    String? phase,
    int? refreshCycle,
  }) {
    return ApiLogItem(
      orderNumber: orderNumber ?? this.orderNumber,
      url: url,
      method: method,
      statusCode: statusCode ?? this.statusCode,
      duration: duration ?? this.duration,
      responseBytes: responseBytes ?? this.responseBytes,
      screen: screen,
      timestamp: timestamp,
      callerName: callerName,
      phase: phase ?? this.phase,
      callCount: callCount ?? this.callCount,
      refreshCycle: refreshCycle ?? this.refreshCycle,
    );
  }
}
