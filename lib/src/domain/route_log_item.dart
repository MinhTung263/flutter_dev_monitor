class RouteLogItem {
  static const String eventPush    = 'PUSH';
  static const String eventPop     = 'POP';
  static const String eventReplace = 'REPLACE';

  final int id;
  final String event;
  final String route;
  final String? from;
  final DateTime timestamp;
  final Duration? duration; // active time — set on POP / REPLACE

  const RouteLogItem({
    required this.id,
    required this.event,
    required this.route,
    this.from,
    required this.timestamp,
    this.duration,
  });
}
