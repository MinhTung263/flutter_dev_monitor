import 'package:dio/dio.dart';

import '../presentation/controller/monitor_controller.dart';
import '../domain/api_log_item.dart';
import '../presentation/navigation/monitor_navigator_observer.dart';

class MonitorInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['caller_name'] =
        _extractCallerName(StackTrace.current.toString());
    options.extra['request_time'] = DateTime.now().millisecondsSinceEpoch;
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _sendToMonitor(
      response.requestOptions,
      response.statusCode ?? 200,
      responseBytes: _estimateBytes(response),
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _sendToMonitor(err.requestOptions, err.response?.statusCode ?? 500);
    super.onError(err, handler);
  }

  void _sendToMonitor(RequestOptions options, int statusCode,
      {int responseBytes = 0}) {
    final startTime = options.extra['request_time'] as int? ??
        DateTime.now().millisecondsSinceEpoch;
    final callerName = options.extra['caller_name'] as String? ?? 'unknown';

    MonitorController.instance.addLog(ApiLogItem(
      orderNumber: 0,
      url: options.path,
      method: options.method,
      statusCode: statusCode,
      duration: DateTime.now().millisecondsSinceEpoch - startTime,
      responseBytes: responseBytes,
      screen: MonitorNavigatorObserver.currentRoute,
      timestamp: DateTime.now(),
      callerName: callerName,
    ));
  }

  int _estimateBytes(Response response) {
    final contentLength =
        int.tryParse(response.headers.value('content-length') ?? '') ?? 0;
    if (contentLength > 0) return contentLength;
    final data = response.data;
    if (data is String) return data.length;
    return 0;
  }

  String _extractCallerName(String trace) {
    for (final line in trace.split('\n')) {
      if (line.isEmpty || _isFrameworkFrame(line)) continue;
      final match = RegExp(r'#\d+\s+(.+?)\s+\(').firstMatch(line);
      if (match != null) {
        return match
            .group(1)!
            .replaceAll('.<anonymous closure>', '')
            .replaceAll('<anonymous closure>', 'λ');
      }
    }
    return 'unknown';
  }

  bool _isFrameworkFrame(String line) {
    final lower = line.toLowerCase();
    return lower.contains('monitor_interceptor') ||
        lower.contains('package:dio/') ||
        lower.contains('package:flutter/') ||
        lower.contains('package:get/') ||
        lower.contains('dart:async') ||
        lower.contains('dart:core') ||
        lower.contains('dart:isolate') ||
        lower.contains('_rootzone') ||
        lower.contains('_customzone') ||
        lower.contains('_timer');
  }
}
