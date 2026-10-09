/// Represents a single captured API request and response log.
class ApiLogItem {
  static int _nextId = 1;

  /// Unique identifier for this log item, stable across deduping and updates.
  final int id;

  /// Label for request triggered during screen initialization.
  static const String phaseInit = 'OPEN';

  /// Label for request triggered by user actions on the screen.
  static const String phaseRefresh = 'ACTION';



  /// The complete endpoint URL of the request.
  final String url;

  /// The HTTP method used (e.g., GET, POST).
  final String method;

  /// The response status code.
  final int statusCode;

  /// The duration of the request in milliseconds.
  final int duration;

  /// The total size of the response payload in bytes.
  final int responseBytes;

  /// The screen route name where this request originated.
  final String screen;

  /// The exact timestamp when this request was recorded.
  final DateTime timestamp;

  /// The name of the calling method/class in the stack trace.
  final String callerName;

  /// The phase of the request log ('OPEN' or 'ACTION').
  final String phase;

  /// The number of repeated calls for deduplication.
  final int callCount;

  /// The refresh loop sequence number.
  final int refreshCycle;

  /// Flat map of the query parameters sent.
  final Map<String, String> queryParams;

  /// Flat map of the request headers sent.
  final Map<String, String> requestHeaders;

  /// Body content of the request, if any.
  final String? requestBody;

  /// Flat map of the response headers received.
  final Map<String, String> responseHeaders;

  /// Body content of the response, if any.
  final String? responseBody;

  /// Creates a new [ApiLogItem] log entry.
  ApiLogItem({
    int? id,
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
    this.queryParams = const {},
    this.requestHeaders = const {},
    this.requestBody,
    this.responseHeaders = const {},
    this.responseBody,
  }) : id = id ?? _nextId++;

  /// Whether the request completed successfully (status 200-299).
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Whether the request duration exceeded 1000 milliseconds.
  bool get isSlow => duration > 1000;

  /// Whether this request was categorized as an ACTION phase log.
  bool get isRefresh => phase == phaseRefresh;

  /// Whether this log has a valid non-unknown caller name.
  bool get hasCallerName => callerName.isNotEmpty && callerName != 'unknown';

  /// Whether this log grouping has more than 1 call.
  bool get hasMultipleCalls => callCount > 1;

  /// Whether the response has a size greater than 0.
  bool get hasResponseSize => responseBytes > 0;

  /// The formatted size string of the response payload (e.g. KB, MB).
  String get responseSizeFormatted {
    if (responseBytes <= 0) return '';
    if (responseBytes < 1024) return '${responseBytes}B';
    if (responseBytes < 1024 * 1024) {
      return '${(responseBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(responseBytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  /// Returns a copy of this log with updated fields.
  ApiLogItem copyWith({
    int? id,
    int? statusCode,
    int? duration,
    int? responseBytes,
    int? callCount,
    String? phase,
    int? refreshCycle,
    DateTime? timestamp,
    String? screen,
    Map<String, String>? queryParams,
    Map<String, String>? requestHeaders,
    String? requestBody,
    Map<String, String>? responseHeaders,
    String? responseBody,
  }) {
    return ApiLogItem(
      id: id ?? this.id,
      url: url,
      method: method,
      statusCode: statusCode ?? this.statusCode,
      duration: duration ?? this.duration,
      responseBytes: responseBytes ?? this.responseBytes,
      screen: screen ?? this.screen,
      timestamp: timestamp ?? this.timestamp,
      callerName: callerName,
      phase: phase ?? this.phase,
      callCount: callCount ?? this.callCount,
      refreshCycle: refreshCycle ?? this.refreshCycle,
      queryParams: queryParams ?? this.queryParams,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      requestBody: requestBody ?? this.requestBody,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
    );
  }

  /// Checks whether this log matches a given search query string.
  /// Handles HTTP method filtering (e.g. searching 'get' only matches GET requests),
  /// status code filtering (e.g. '200', '404'), and URL/caller text search.
  bool matchesQuery(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    const httpMethods = {
      'get',
      'post',
      'put',
      'delete',
      'patch',
      'head',
      'options',
    };

    final itemMethod = method.toLowerCase();

    // 1. If query is an exact HTTP method (e.g. "get", "post", "put", "delete")
    // User intends to filter by HTTP method only!
    if (httpMethods.contains(query)) {
      return itemMethod == query;
    }

    // 2. If query starts with an HTTP method followed by a space (e.g. "get /orders", "post auth")
    final spaceIdx = query.indexOf(' ');
    if (spaceIdx > 0) {
      final firstWord = query.substring(0, spaceIdx);
      if (httpMethods.contains(firstWord)) {
        if (itemMethod != firstWord) return false;
        final restQuery = query.substring(spaceIdx + 1).trim();
        if (restQuery.isEmpty) return true;
        return url.toLowerCase().contains(restQuery) ||
            statusCode.toString().contains(restQuery) ||
            callerName.toLowerCase().contains(restQuery);
      }
    }

    // 3. If query is a 3-digit HTTP status code (e.g. "200", "404", "500")
    if (RegExp(r'^[1-5][0-9]{2}$').hasMatch(query)) {
      return statusCode.toString() == query ||
          url.toLowerCase().contains(query);
    }

    // 4. General search across URL, status code, or caller
    final urlMatch = url.toLowerCase().contains(query);
    final statusMatch = statusCode.toString().contains(query);
    final callerMatch = callerName.toLowerCase().contains(query);

    return urlMatch || statusMatch || callerMatch;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiLogItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
