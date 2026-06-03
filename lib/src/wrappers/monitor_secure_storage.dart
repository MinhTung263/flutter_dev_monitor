import '../dev_monitor.dart';

/// Drop-in wrapper around FlutterSecureStorage (or any async key-value
/// store with `read` / `write` / `delete` / `readAll` API).
///
/// ```dart
/// // Before
/// const storage = FlutterSecureStorage();
/// final token = await storage.read(key: 'auth_token');
/// await storage.write(key: 'auth_token', value: newToken);
///
/// // After — no other changes needed
/// final storage = MonitorSecureStorage(const FlutterSecureStorage());
/// final token = await storage.read(key: 'auth_token');   // ↓ READ
/// await storage.write(key: 'auth_token', value: token);  // ↑ WRITE
/// ```
class MonitorSecureStorage {
  final dynamic _storage;
  final String source;

  MonitorSecureStorage(dynamic storage, {this.source = 'SecureStorage'})
      : _storage = storage;

  // ── Reads ────────────────────────────────────────────────────────────

  Future<String?> read({required String key}) async {
    final v = await (_storage.read(key: key) as Future<String?>);
    DevMonitor.trackLocal(
        source: source, key: key, value: v == null ? null : '***');
    return v;
  }

  Future<bool> containsKey({required String key}) =>
      _storage.containsKey(key: key) as Future<bool>;

  Future<Map<String, String>> readAll() async {
    final all = await (_storage.readAll() as Future<Map<String, String>>);
    for (final e in all.entries) {
      DevMonitor.trackLocal(source: source, key: e.key, value: '***');
    }
    return all;
  }

  // ── Writes ───────────────────────────────────────────────────────────

  Future<void> write({required String key, required String? value}) async {
    // Value masked — SecureStorage data is sensitive
    DevMonitor.trackLocal(
        source: source,
        key: key,
        value: value == null ? null : '***',
        isWrite: true);
    return _storage.write(key: key, value: value) as Future<void>;
  }

  Future<void> delete({required String key}) async {
    DevMonitor.trackLocal(
        source: source, key: key, value: '(deleted)', isWrite: true);
    return _storage.delete(key: key) as Future<void>;
  }

  Future<void> deleteAll() async {
    DevMonitor.trackLocal(source: source, key: '* (deleteAll)', isWrite: true);
    return _storage.deleteAll() as Future<void>;
  }

  // ── Snapshot ─────────────────────────────────────────────────────────

  /// Log which keys exist in secure storage (values masked as ***).
  Future<void> snapshotKeys() async {
    final all =
        await (_storage.readAll() as Future<Map<String, String>>);
    for (final key in all.keys) {
      DevMonitor.trackLocal(source: source, key: key, value: '***');
    }
  }
}
