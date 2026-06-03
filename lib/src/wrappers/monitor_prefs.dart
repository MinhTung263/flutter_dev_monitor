import '../dev_monitor.dart';

/// Drop-in wrapper around any SharedPreferences-compatible instance.
///
/// Pass your existing `SharedPreferences` object and replace every
/// access through this wrapper. All reads and writes are automatically
/// logged to the Monitor **LOCAL** tab with READ/WRITE indicators.
///
/// ```dart
/// // Before
/// final prefs = await SharedPreferences.getInstance();
/// final token = prefs.getString('auth_token');
/// await prefs.setString('auth_token', newToken);
///
/// // After — no other code changes needed
/// final prefs = MonitorPrefs(await SharedPreferences.getInstance());
/// final token = prefs.getString('auth_token');   // logged as READ
/// await prefs.setString('auth_token', newToken); // logged as WRITE
/// ```
class MonitorPrefs {
  final dynamic _prefs;
  final String source;

  MonitorPrefs(dynamic prefs, {this.source = 'SharedPreferences'})
      : _prefs = prefs;

  // ── Reads ────────────────────────────────────────────────────────────

  dynamic get(String key) {
    final v = _prefs.get(key);
    _log(key, v);
    return v;
  }

  String? getString(String key) {
    final v = _prefs.getString(key) as String?;
    _log(key, v);
    return v;
  }

  bool? getBool(String key) {
    final v = _prefs.getBool(key) as bool?;
    _log(key, v == null ? null : '$v');
    return v;
  }

  int? getInt(String key) {
    final v = _prefs.getInt(key) as int?;
    _log(key, v == null ? null : '$v');
    return v;
  }

  double? getDouble(String key) {
    final v = _prefs.getDouble(key) as double?;
    _log(key, v == null ? null : '$v');
    return v;
  }

  List<String>? getStringList(String key) {
    final v = _prefs.getStringList(key) as List<String>?;
    _log(key, v == null ? null : v);
    return v;
  }

  Set<String> getKeys() => (_prefs.getKeys() as Set<String>);

  bool containsKey(String key) => _prefs.containsKey(key) as bool;

  // ── Writes ───────────────────────────────────────────────────────────

  Future<bool> setString(String key, String value) {
    _logWrite(key, value);
    return _prefs.setString(key, value) as Future<bool>;
  }

  Future<bool> setBool(String key, bool value) {
    _logWrite(key, '$value');
    return _prefs.setBool(key, value) as Future<bool>;
  }

  Future<bool> setInt(String key, int value) {
    _logWrite(key, '$value');
    return _prefs.setInt(key, value) as Future<bool>;
  }

  Future<bool> setDouble(String key, double value) {
    _logWrite(key, '$value');
    return _prefs.setDouble(key, value) as Future<bool>;
  }

  Future<bool> setStringList(String key, List<String> value) {
    _logWrite(key, value);
    return _prefs.setStringList(key, value) as Future<bool>;
  }

  Future<bool> remove(String key) {
    _logWrite(key, '(removed)');
    return _prefs.remove(key) as Future<bool>;
  }

  Future<bool> clear() {
    DevMonitor.trackLocal(source: source, key: '* (clear all)', isWrite: true);
    return _prefs.clear() as Future<bool>;
  }

  Future<void> reload() => _prefs.reload() as Future<void>;

  // ── Snapshot ─────────────────────────────────────────────────────────

  /// Log the current value of every key in this SharedPreferences instance.
  /// Call in [initState] to see what the screen loaded from storage.
  void snapshot() {
    final keys = _prefs.getKeys() as Set<String>;
    for (final key in keys) {
      final v = _prefs.get(key);
      _log(key, v);
    }
  }

  /// Log the current value of the given [keys] only.
  /// Useful when you only care about keys relevant to the current screen.
  void snapshotKeys(List<String> keys) {
    for (final key in keys) {
      final v = _prefs.get(key);
      if (v != null) _log(key, v);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  void _log(String key, dynamic value) =>
      DevMonitor.trackLocal(source: source, key: key, value: value);

  void _logWrite(String key, dynamic value) =>
      DevMonitor.trackLocal(
          source: source, key: key, value: value, isWrite: true);
}
