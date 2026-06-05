import '../../domain/route_log_item.dart';

class RouteLogController {
  final List<RouteLogItem> _logs = [];
  final Map<String, DateTime> _pushTimes = {};
  int _nextId = 1;
  static const int _max = 150;

  List<RouteLogItem> get logs => List.unmodifiable(_logs);
  int get count => _logs.length;

  void logPush(String route, String? from) {
    _pushTimes[route] = DateTime.now();
    _insert(RouteLogItem(
      id: _nextId++,
      event: RouteLogItem.eventPush,
      route: route,
      from: from,
      timestamp: DateTime.now(),
    ));
  }

  void logPop(String route, String? to) {
    final pushTime = _pushTimes.remove(route);
    final duration =
        pushTime != null ? DateTime.now().difference(pushTime) : null;
    _insert(RouteLogItem(
      id: _nextId++,
      event: RouteLogItem.eventPop,
      route: route,
      from: to,
      timestamp: DateTime.now(),
      duration: duration,
    ));
  }

  void logReplace(String oldRoute, String newRoute) {
    final pushTime = _pushTimes.remove(oldRoute);
    final duration =
        pushTime != null ? DateTime.now().difference(pushTime) : null;
    _pushTimes[newRoute] = DateTime.now();
    _insert(RouteLogItem(
      id: _nextId++,
      event: RouteLogItem.eventReplace,
      route: newRoute,
      from: oldRoute,
      timestamp: DateTime.now(),
      duration: duration,
    ));
  }

  void clearAll() {
    _logs.clear();
    _pushTimes.clear();
  }

  void _insert(RouteLogItem item) {
    _logs.insert(0, item);
    if (_logs.length > _max) _logs.removeLast();
  }

  static String fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    if (d.inSeconds > 0) return '${d.inSeconds}s';
    return '${d.inMilliseconds}ms';
  }
}
