import 'package:flutter/widgets.dart';

import 'data/monitor_interceptor.dart';
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
}
