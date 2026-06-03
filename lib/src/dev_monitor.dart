import 'package:flutter/widgets.dart';

import 'data/monitor_interceptor.dart';
import 'presentation/controller/monitor_controller.dart';
import 'presentation/navigation/monitor_navigator_observer.dart';
import 'presentation/ui/widgets/fps_overlay.dart';

/// One-stop setup helpers — reduces boilerplate to two MaterialApp params.
///
/// ```dart
/// // Dio
/// dio.interceptors.add(DevMonitor.interceptor);
///
/// // MaterialApp
/// MaterialApp(
///   navigatorObservers: [DevMonitor.observer],
///   builder: DevMonitor.appBuilder,
///   home: HomeScreen(),
/// )
/// ```
abstract final class DevMonitor {
  /// Singleton [MonitorNavigatorObserver] — pass to `navigatorObservers`.
  static final MonitorNavigatorObserver observer = MonitorNavigatorObserver();

  /// Singleton [MonitorInterceptor] — add to your Dio instance.
  static final MonitorInterceptor interceptor = MonitorInterceptor();

  /// Pass to `MaterialApp.builder` to inject the floating FPS overlay
  /// automatically. No need to wrap `home` with [FpsOverlay] manually.
  static Widget appBuilder(BuildContext context, Widget? child) =>
      FpsOverlay(child: child ?? const SizedBox.shrink());

  /// Log a local storage read for the current screen.
  ///
  /// Call this whenever you read from SharedPreferences, Hive, SQLite,
  /// SecureStorage, or any local cache. The read will appear in the
  /// **LOCAL** tab of the Monitor Dashboard.
  ///
  /// ```dart
  /// final token = await prefs.getString('auth_token');
  /// DevMonitor.trackLocal(source: 'SharedPreferences', key: 'auth_token');
  ///
  /// final products = box.get('products');
  /// DevMonitor.trackLocal(
  ///   source: 'Hive',
  ///   key: 'products',
  ///   value: '${products.length} items',
  /// );
  /// ```
  static void trackLocal({
    required String source,
    required String key,
    dynamic value,
    bool isWrite = false,
  }) =>
      MonitorController.instance.addLocalRead(
          source: source, key: key, value: value, isWrite: isWrite);

  /// Log a write to an in-memory Singleton for the current screen.
  ///
  /// [singletonName] is the class name of the Singleton (e.g. `'UserService'`).
  /// [key] is the field or property being written.
  /// [value] is an optional string representation of the new value.
  ///
  /// ```dart
  /// class UserService {
  ///   static final instance = UserService._();
  ///   User? _user;
  ///
  ///   set user(User? u) {
  ///     _user = u;
  ///     DevMonitor.trackSingleton('UserService', 'user', u?.name);
  ///   }
  /// }
  /// ```
  /// Snapshot a Map of key-value pairs from any storage source.
  ///
  /// Use this for libraries that don't have a dedicated Monitor wrapper,
  /// such as ObjectBox, Isar, Drift, or any custom cache. Call it in
  /// [initState] to see what the screen loaded from storage.
  ///
  /// ```dart
  /// // Sqflite
  /// final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
  /// DevMonitor.snapshotMap('SQLite:users', {
  ///   for (final row in rows) '${row['id']}': row,
  /// });
  ///
  /// // ObjectBox / Isar
  /// final items = itemBox.getAll();
  /// DevMonitor.snapshotMap('ObjectBox:Item', {
  ///   for (final item in items) '${item.id}': item.toJson(),
  /// });
  ///
  /// // Any in-memory map/cache
  /// DevMonitor.snapshotMap('Cache:products', productCache);
  /// ```
  static void snapshotMap(String source, Map<dynamic, dynamic> data) {
    for (final e in data.entries) {
      MonitorController.instance.addLocalRead(
        source: source,
        key: '${e.key}',
        value: e.value,
      );
    }
  }

  static void trackSingleton(
    String singletonName,
    String key, [
    dynamic value,
  ]) =>
      MonitorController.instance.addLocalRead(
        source: 'Singleton:$singletonName',
        key: key,
        value: value,
      );
}
