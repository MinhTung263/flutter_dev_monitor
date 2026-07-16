import '../../domain/route_log_item.dart';

class RouteLogController {
  final List<RouteLogItem> _logs = [];
  final Map<String, DateTime> _pushTimes = {};
  int _nextId = 1;
  static const int _max = 150;

  List<RouteLogItem> get logs => List.unmodifiable(_logs);
  int get count => _logs.length;

  void logPush(String route, String? from, {String routeType = 'page'}) {
    _pushTimes[route] = DateTime.now();
    _insert(RouteLogItem(
      id: _nextId++,
      event: RouteLogItem.eventPush,
      route: route,
      from: from,
      timestamp: DateTime.now(),
      routeType: routeType,
    ));
  }

  void logPop(String route, String? to, {String routeType = 'page'}) {
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
      routeType: routeType,
    ));
  }

  void logReplace(String oldRoute, String newRoute, {String routeType = 'page'}) {
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
      routeType: routeType,
    ));
  }

  void clearAll() {
    _logs.clear();
    _pushTimes.clear();
  }

  void renameSession(String oldScreen, String newScreen) {
    if (oldScreen == newScreen) return;

    if (_pushTimes.containsKey(oldScreen)) {
      _pushTimes[newScreen] = _pushTimes.remove(oldScreen)!;
    }

    for (int i = 0; i < _logs.length; i++) {
      final log = _logs[i];
      final newRoute = log.route == oldScreen ? newScreen : log.route;
      final newFrom = log.from == oldScreen ? newScreen : log.from;
      if (newRoute != log.route || newFrom != log.from) {
        _logs[i] = RouteLogItem(
          id: log.id,
          event: log.event,
          route: newRoute,
          from: newFrom,
          timestamp: log.timestamp,
          duration: log.duration,
          routeType: log.routeType,
        );
      }
    }
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
