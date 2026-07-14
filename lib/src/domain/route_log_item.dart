/// Represents a route transition event log (e.g. push, pop).
class RouteLogItem {
  /// Event type for pushing a route.
  static const String eventPush    = 'PUSH';

  /// Event type for popping a route.
  static const String eventPop     = 'POP';

  /// Event type for replacing a route.
  static const String eventReplace = 'REPLACE';

  /// Identifier for the route log entry.
  final int id;

  /// The type of transition event (PUSH, POP, REPLACE).
  final String event;

  /// The target route path.
  final String route;

  /// The source route path being navigated from, if any.
  final String? from;

  /// The timestamp of the navigation event.
  final DateTime timestamp;

  /// The duration the user spent on the route (set on POP/REPLACE).
  final Duration? duration;

  /// The type of route ('page', 'bottomSheet', 'dialog', 'popup').
  final String routeType;

  /// Creates a new [RouteLogItem] entry.
  const RouteLogItem({
    required this.id,
    required this.event,
    required this.route,
    this.from,
    required this.timestamp,
    this.duration,
    this.routeType = 'page',
  });
}
