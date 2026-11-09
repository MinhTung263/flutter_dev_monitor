import 'dart:collection';

/// Nội dung body request/response của một log — dùng CHUNG giữa các bản sao
/// [ApiLogItem.copyWith] (gộp log trùng) để giải phóng một lần là áp dụng cho
/// mọi bản sao. Body chỉ mã hoá thành chuỗi khi có người đọc.
class _LogBodies {
  _LogBodies({
    String? request,
    String? Function()? requestBuilder,
    String? response,
    String? Function()? responseBuilder,
  })  : _request = request,
        _requestBuilder = requestBuilder,
        _response = response,
        _responseBuilder = responseBuilder;

  String? _request;
  String? Function()? _requestBuilder;
  String? _response;
  String? Function()? _responseBuilder;
  bool released = false;

  bool get hasContent =>
      _request != null ||
      _requestBuilder != null ||
      _response != null ||
      _responseBuilder != null;

  String? get request {
    final b = _requestBuilder;
    if (_request == null && b != null) {
      _request = b();
      _requestBuilder = null;
    }
    return _request;
  }

  String? get response {
    final b = _responseBuilder;
    if (_response == null && b != null) {
      _response = b();
      _responseBuilder = null;
    }
    return _response;
  }

  /// Bỏ nội dung (và tham chiếu tới dữ liệu gốc của request/response) để GC
  /// thu hồi RAM.
  void release() {
    if (!hasContent) return;
    _request = _response = ApiLogItem.releasedBodyNote;
    _requestBuilder = _responseBuilder = null;
    released = true;
  }
}

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
  final int _responseBytes;

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

  /// Body content of the request, if any (lazily encoded on first read).
  String? get requestBody => _bodies.request;

  /// Flat map of the response headers received.
  final Map<String, String> responseHeaders;

  final _LogBodies _bodies;

  /// Body content of the response, if any (lazily encoded on first read).
  String? get responseBody => _bodies.response;

  /// Body đã được giải phóng để tiết kiệm RAM (xem [bodyRetentionLimit]).
  bool get isBodyReleased => _bodies.released;

  /// The total size of the response payload in bytes.
  int get responseBytes {
    if (_responseBytes > 0) return _responseBytes;
    final cached = _bodies._response;
    if (cached != null && !_bodies.released) return cached.length;
    return 0;
  }

  /// Nội dung hiển thị thay cho body đã giải phóng.
  static const String releasedBodyNote =
      '[Đã giải phóng để tiết kiệm RAM: khi DevMonitor đang ẩn chỉ giữ nội dung '
      'của các request gần nhất]';

  /// Số log gần nhất còn giữ body; 0 = giữ tất cả. DevMonitor đặt giá trị nhỏ
  /// khi overlay/dashboard đang ẩn (bản prod/staging): giữ body của mọi request
  /// nghĩa là giữ nguyên dữ liệu response đã parse (danh sách sản phẩm, bảng
  /// giá...) trong RAM — tăng áp lực GC, dễ hết RAM trên máy POS yếu.
  static int get bodyRetentionLimit => _bodyRetentionLimit;
  static int _bodyRetentionLimit = 0;
  static set bodyRetentionLimit(int value) {
    _bodyRetentionLimit = value < 0 ? 0 : value;
    _trimRetained();
  }

  static final Queue<_LogBodies> _retained = Queue<_LogBodies>();

  static void _retain(_LogBodies bodies) {
    if (!bodies.hasContent) return;
    _retained.addLast(bodies);
    _trimRetained();
  }

  static void _trimRetained() {
    final limit = _bodyRetentionLimit;
    if (limit == 0) {
      // Giữ tất cả: hàng đợi chỉ cần đủ để cắt khi chuyển sang chế độ ẩn —
      // tránh hàng đợi phình vô hạn khi DevMonitor mở lâu.
      while (_retained.length > 2000) {
        _retained.removeFirst();
      }
      return;
    }
    while (_retained.length > limit) {
      _retained.removeFirst().release();
    }
  }

  static final RegExp _statusCodeRegExp = RegExp(r'^[1-5][0-9]{2}$');

  /// Creates a new [ApiLogItem] log entry.
  ApiLogItem({
    int? id,
    required this.url,
    required this.method,
    required this.statusCode,
    required this.duration,
    required this.screen,
    required this.timestamp,
    int responseBytes = 0,
    this.callerName = 'unknown',
    this.phase = phaseInit,
    this.callCount = 1,
    this.refreshCycle = 0,
    this.queryParams = const {},
    this.requestHeaders = const {},
    String? requestBody,
    String? Function()? requestBodyBuilder,
    this.responseHeaders = const {},
    String? responseBody,
    String? Function()? responseBodyBuilder,
  })  : id = id ?? _nextId++,
        _responseBytes = responseBytes,
        _bodies = _LogBodies(
          request: requestBody,
          requestBuilder: requestBody == null ? requestBodyBuilder : null,
          response: responseBody,
          responseBuilder: responseBody == null ? responseBodyBuilder : null,
        ) {
    _retain(_bodies);
  }

  ApiLogItem._copy({
    required this.id,
    required this.url,
    required this.method,
    required this.statusCode,
    required this.duration,
    required this.screen,
    required this.timestamp,
    required int responseBytes,
    required this.callerName,
    required this.phase,
    required this.callCount,
    required this.refreshCycle,
    required this.queryParams,
    required this.requestHeaders,
    required this.responseHeaders,
    required _LogBodies bodies,
  })  : _responseBytes = responseBytes,
        _bodies = bodies;

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
    // Dùng CHUNG body với bản gốc (không mã hoá lại, giải phóng một lần là
    // áp dụng cho mọi bản sao); chỉ tạo body mới khi truyền body khác vào.
    final _LogBodies bodies;
    if (requestBody == null && responseBody == null) {
      bodies = _bodies;
    } else {
      bodies = _LogBodies(
        request: requestBody ?? _bodies._request,
        requestBuilder: requestBody == null ? _bodies._requestBuilder : null,
        response: responseBody ?? _bodies._response,
        responseBuilder: responseBody == null ? _bodies._responseBuilder : null,
      );
      _retain(bodies);
    }
    return ApiLogItem._copy(
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
      responseHeaders: responseHeaders ?? this.responseHeaders,
      bodies: bodies,
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
    if (_statusCodeRegExp.hasMatch(query)) {
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
