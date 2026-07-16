import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/api_log_item.dart';
import '../presentation/controller/monitor_controller.dart';
import '../presentation/navigation/monitor_navigator_observer.dart';

/// An interceptor for Dio HTTP client that automatically captures
/// request, response, and error logs for DevMonitor.
class MonitorInterceptor extends Interceptor {

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['caller_name'] = kDebugMode
        ? _extractCallerName(StackTrace.current.toString())
        : 'unknown';
    options.extra['request_time'] = DateTime.now().millisecondsSinceEpoch;
    options.extra['req_headers'] = _flattenHeaders(options.headers);
    options.extra['query_params'] = _flattenMap(options.queryParameters);
    options.extra['req_body'] = _encodeBody(options.data);
    options.extra['request_screen'] = MonitorNavigatorObserver.currentRoute;
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _sendToMonitor(
      response.requestOptions,
      response.statusCode ?? 200,
      responseBytes: _estimateBytes(response),
      responseHeaders: _flattenListHeaders(response.headers.map),
      responseBody: _encodeBody(response.data),
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _sendToMonitor(
      err.requestOptions,
      err.response?.statusCode ?? 500,
      responseHeaders: err.response != null
          ? _flattenListHeaders(err.response!.headers.map)
          : const {},
      responseBody: err.response != null
          ? _encodeBody(err.response!.data)
          : null,
    );
    super.onError(err, handler);
  }

  void _sendToMonitor(
    RequestOptions options,
    int statusCode, {
    int responseBytes = 0,
    Map<String, String> responseHeaders = const {},
    String? responseBody,
  }) {
    final startTime = options.extra['request_time'] as int? ??
        DateTime.now().millisecondsSinceEpoch;
    final requestScreen = options.extra['request_screen'] as String? ??
        MonitorNavigatorObserver.currentRoute;

    MonitorController.instance.addLog(ApiLogItem(
      url: options.uri.toString(),
      method: options.method,
      statusCode: statusCode,
      duration: DateTime.now().millisecondsSinceEpoch - startTime,
      responseBytes: responseBytes,
      screen: requestScreen,
      timestamp: DateTime.fromMillisecondsSinceEpoch(startTime),
      callerName: options.extra['caller_name'] as String? ?? 'unknown',
      queryParams: options.extra['query_params'] as Map<String, String>? ?? {},
      requestHeaders:
          options.extra['req_headers'] as Map<String, String>? ?? {},
      requestBody: options.extra['req_body'] as String?,
      responseHeaders: responseHeaders,
      responseBody: responseBody,
    ));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  int _estimateBytes(Response response) {
    final cl = int.tryParse(response.headers.value('content-length') ?? '') ?? 0;
    if (cl > 0) return cl;
    final data = response.data;
    if (data is String) return data.length;
    return 0;
  }

  Map<String, String> _flattenHeaders(Map<String, dynamic> map) {
    final result = <String, String>{};
    for (final e in map.entries) {
      final v = e.value;
      result[e.key] = v is List ? v.join(', ') : v.toString();
    }
    return result;
  }

  Map<String, String> _flattenListHeaders(Map<String, List<String>> map) {
    return map.map((k, v) => MapEntry(k, v.join(', ')));
  }

  Map<String, String> _flattenMap(Map<String, dynamic> map) {
    return map.map((k, v) => MapEntry(k, v.toString()));
  }

  String? _encodeBody(dynamic data) {
    if (data == null) return null;
    try {
      if (data is FormData) {
        final map = <String, dynamic>{};
        for (final entry in data.fields) {
          map[entry.key] = entry.value;
        }
        for (final entry in data.files) {
          final file = entry.value;
          map[entry.key] = {
            'filename': file.filename,
            'length': file.length,
            if (file.contentType != null) 'contentType': file.contentType.toString(),
          };
        }
        return jsonEncode({
          '@type': 'FormData',
          '@fields': map,
        });
      }
      if (data is Uint8List) {
        return '[Binary Data] ${data.length} bytes';
      }
      if (data is Stream) {
        return '[Stream Data]';
      }
      if (data is String) {
        if (data.isEmpty) return null;
        return data;
      }
      if (data is List || data is Map) {
        return jsonEncode(data);
      }
      return data.toString();
    } catch (_) {
      return null;
    }
  }

  String _extractCallerName(String trace) {
    int newlineCount = 0;
    int truncateIndex = trace.length;
    for (int i = 0; i < trace.length; i++) {
      if (trace.codeUnitAt(i) == 10) { // '\n'
        newlineCount++;
        if (newlineCount == 15) {
          truncateIndex = i;
          break;
        }
      }
    }
    final shortTrace = trace.substring(0, truncateIndex);
    for (final line in shortTrace.split('\n')) {
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
