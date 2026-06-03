import '../dev_monitor.dart';

/// Drop-in wrapper around GetStorage (or any similar key-value store
/// with `read` / `write` / `remove` / `erase` API).
///
/// ```dart
/// // Before
/// final box = GetStorage();
/// final token = box.read('auth_token');
/// box.write('theme', 'dark');
///
/// // After — no other changes needed
/// final box = MonitorGetStorage(GetStorage(), source: 'GetStorage');
/// final token = box.read('auth_token');  // ↓ READ auto-logged
/// box.write('theme', 'dark');           // ↑ WRITE auto-logged
/// ```
class MonitorGetStorage {
  final dynamic _store;
  final String source;

  MonitorGetStorage(dynamic store, {this.source = 'GetStorage'})
      : _store = store;

  // ── Reads ────────────────────────────────────────────────────────────

  T? read<T>(String key) {
    final v = _store.read(key) as T?;
    DevMonitor.trackLocal(source: source, key: key, value: v);
    return v;
  }

  bool hasData(String key) => _store.hasData(key) as bool;

  // ── Writes ───────────────────────────────────────────────────────────

  Future<void> write(String key, dynamic value) {
    DevMonitor.trackLocal(
        source: source, key: key, value: value, isWrite: true);
    return _store.write(key, value) as Future<void>;
  }

  Future<void> remove(String key) {
    DevMonitor.trackLocal(
        source: source, key: key, value: '(removed)', isWrite: true);
    return _store.remove(key) as Future<void>;
  }

  Future<void> erase() {
    DevMonitor.trackLocal(source: source, key: '* (erase)', isWrite: true);
    return _store.erase() as Future<void>;
  }

  // ── Snapshot ─────────────────────────────────────────────────────────

  /// Log every key-value pair currently stored in this GetStorage container.
  /// Call in [initState] to see what the screen loaded from storage.
  ///
  /// Requires GetStorage to expose its internal map — pass it explicitly:
  /// ```dart
  /// box.snapshotKeys(['auth_token', 'user_id', 'theme']);
  /// ```
  void snapshotKeys(List<String> keys) {
    for (final key in keys) {
      final v = _store.read(key);
      if (v != null) {
        DevMonitor.trackLocal(source: source, key: key, value: v);
      }
    }
  }
}
