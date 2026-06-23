class ErrorLogItem {
  static const String typeFlutter = 'FLUTTER';
  static const String typeDart = 'DART';

  final int id;
  final String message;
  final String stackTrace;
  final String type;
  final DateTime timestamp;
  final String screen;

  const ErrorLogItem({
    required this.id,
    required this.message,
    required this.stackTrace,
    required this.type,
    required this.timestamp,
    required this.screen,
  });
}
