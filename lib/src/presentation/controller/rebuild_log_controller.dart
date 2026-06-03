class RebuildLogController {
  // screen → {widgetName → count}
  final Map<String, Map<String, int>> _data = {};

  /// Records one rebuild for [widgetName] on [screen].
  void record(String widgetName, String screen) {
    if (screen.isEmpty) return;
    (_data[screen] ??= {})[widgetName] =
        (_data[screen]![widgetName] ?? 0) + 1;
  }

  /// Returns widget rebuild counts for [screen], sorted highest first.
  List<MapEntry<String, int>> sortedForScreen(String screen) {
    final map = _data[screen] ?? {};
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  int totalForScreen(String screen) =>
      (_data[screen] ?? {}).values.fold(0, (s, v) => s + v);

  void clearScreen(String screen) => _data.remove(screen);

  void clearAll() => _data.clear();
}
