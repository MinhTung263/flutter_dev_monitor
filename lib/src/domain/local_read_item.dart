class LocalReadItem {
  final int id;
  final String source;
  final String key;
  final String? value;
  final DateTime timestamp;
  final String screen;

  const LocalReadItem({
    required this.id,
    required this.source,
    required this.key,
    this.value,
    required this.timestamp,
    required this.screen,
  });

  bool get hasValue => value != null && value!.isNotEmpty;
}
