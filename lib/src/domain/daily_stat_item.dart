/// Represents a lightweight log item used for daily statistics.
class DailyStatItem {
  /// The epoch timestamp in milliseconds when this event occurred.
  final int timestamp;

  /// The type of log event: 'route', 'api', or 'error'.
  final String type;

  /// The screen/route name where the event occurred.
  final String route;

  /// The API endpoint URL (only present if type is 'api').
  final String? url;

  /// The HTTP method, e.g., 'GET', 'POST' (only present if type is 'api').
  final String? method;

  /// The API request duration in milliseconds (only present if type is 'api').
  final int? duration;

  /// The HTTP status code, e.g., 200, 404 (only present if type is 'api').
  final int? status;

  /// The error description or exception message (only present if type is 'error').
  final String? error;

  /// Creates a new [DailyStatItem] log entry.
  const DailyStatItem({
    required this.timestamp,
    required this.type,
    required this.route,
    this.url,
    this.method,
    this.duration,
    this.status,
    this.error,
  });

  /// Converts the item into a JSON-compatible Map.
  Map<String, dynamic> toMap() {
    return {
      't': timestamp,
      'type': type,
      'route': route,
      if (url != null) 'url': url,
      if (method != null) 'method': method,
      if (duration != null) 'duration': duration,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
    };
  }

  /// Creates a new [DailyStatItem] from a JSON Map.
  factory DailyStatItem.fromMap(Map<String, dynamic> map) {
    return DailyStatItem(
      timestamp: map['t'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      type: map['type'] as String? ?? 'api',
      route: map['route'] as String? ?? '',
      url: map['url'] as String?,
      method: map['method'] as String?,
      duration: map['duration'] as int?,
      status: map['status'] as int?,
      error: map['error'] as String?,
    );
  }
}
