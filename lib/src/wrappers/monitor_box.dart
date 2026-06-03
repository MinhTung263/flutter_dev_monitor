import '../dev_monitor.dart';

/// Drop-in wrapper around any Hive `Box`-compatible instance.
///
/// Pass your existing Hive `Box<T>` and access it through this wrapper.
/// All reads and writes are automatically logged to the Monitor **LOCAL** tab.
///
/// ```dart
/// // Before
/// final box = Hive.box<Product>('products');
/// final product = box.get('p_1');
/// await box.put('p_1', updatedProduct);
///
/// // After — no other code changes needed
/// final box = MonitorBox<Product>(Hive.box<Product>('products'),
///     source: 'Hive:products');
/// final product = box.get('p_1');          // logged as READ
/// await box.put('p_1', updatedProduct);    // logged as WRITE
/// ```
class MonitorBox<T> {
  final dynamic _box;
  final String source;

  MonitorBox(dynamic box, {String? source})
      : _box = box,
        source = source ?? 'Hive:${_boxName(box)}';

  static String _boxName(dynamic box) {
    try {
      return box.name as String? ?? 'box';
    } catch (_) {
      return 'box';
    }
  }

  // ── Reads ────────────────────────────────────────────────────────────

  T? get(dynamic key, {T? defaultValue}) {
    final v = _box.get(key, defaultValue: defaultValue) as T?;
    DevMonitor.trackLocal(source: source, key: '$key', value: v);
    return v;
  }

  T getAt(int index) {
    final v = _box.getAt(index) as T;
    DevMonitor.trackLocal(source: source, key: '[$index]', value: v);
    return v;
  }

  bool containsKey(dynamic key) => _box.containsKey(key) as bool;

  Iterable<dynamic> get keys => _box.keys as Iterable<dynamic>;

  Iterable<T> get values => (_box.values as Iterable).cast<T>();

  int get length => _box.length as int;

  bool get isEmpty => _box.isEmpty as bool;

  bool get isNotEmpty => _box.isNotEmpty as bool;

  Map<dynamic, T> toMap() => (_box.toMap() as Map).cast<dynamic, T>();

  // ── Writes ───────────────────────────────────────────────────────────

  Future<void> put(dynamic key, T value) {
    DevMonitor.trackLocal(
        source: source, key: '$key', value: value, isWrite: true);
    return _box.put(key, value) as Future<void>;
  }

  Future<void> putAt(int index, T value) {
    DevMonitor.trackLocal(
        source: source, key: '[$index]', value: value, isWrite: true);
    return _box.putAt(index, value) as Future<void>;
  }

  Future<int> add(T value) {
    DevMonitor.trackLocal(
        source: source, key: '(add)', value: value, isWrite: true);
    return _box.add(value) as Future<int>;
  }

  Future<Iterable<int>> addAll(Iterable<T> values) {
    DevMonitor.trackLocal(
        source: source,
        key: '(addAll)',
        value: '${values.length} items',
        isWrite: true);
    return (_box.addAll(values) as Future).then((v) => v as Iterable<int>);
  }

  Future<void> putAll(Map<dynamic, T> entries) {
    DevMonitor.trackLocal(
        source: source,
        key: '(putAll)',
        value: '${entries.length} entries',
        isWrite: true);
    return _box.putAll(entries) as Future<void>;
  }

  Future<void> delete(dynamic key) {
    DevMonitor.trackLocal(
        source: source, key: '$key', value: '(deleted)', isWrite: true);
    return _box.delete(key) as Future<void>;
  }

  Future<void> deleteAt(int index) {
    DevMonitor.trackLocal(
        source: source, key: '[$index]', value: '(deleted)', isWrite: true);
    return _box.deleteAt(index) as Future<void>;
  }

  Future<void> deleteAll(Iterable<dynamic> keys) {
    DevMonitor.trackLocal(
        source: source,
        key: '(deleteAll)',
        value: '${keys.length} keys',
        isWrite: true);
    return _box.deleteAll(keys) as Future<void>;
  }

  Future<void> clear() {
    DevMonitor.trackLocal(
        source: source, key: '* (clear all)', isWrite: true);
    return _box.clear() as Future<void>;
  }

  Future<void> close() => _box.close() as Future<void>;

  // ── Snapshot ─────────────────────────────────────────────────────────

  /// Log every key-value pair currently stored in this Box.
  /// Call in [initState] to see what the screen loaded from Hive.
  void snapshot() {
    try {
      final map = _box.toMap() as Map;
      for (final e in map.entries) {
        DevMonitor.trackLocal(source: source, key: '${e.key}', value: e.value);
      }
    } catch (_) {}
  }
}
