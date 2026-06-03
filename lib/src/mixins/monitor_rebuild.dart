import 'package:flutter/widgets.dart';

import '../presentation/controller/monitor_controller.dart';
import '../presentation/navigation/monitor_navigator_observer.dart';

/// Add this mixin to a [State] and call [trackRebuild] at the top of
/// [build] to log widget rebuild counts in the Monitor Dashboard.
///
/// ```dart
/// class _HomeScreenState extends State<HomeScreen> with MonitorRebuild {
///   @override
///   Widget build(BuildContext context) {
///     trackRebuild(); // ← one line
///     return Scaffold(...);
///   }
/// }
/// ```
///
/// Rebuild counts appear in the **WIDGET REBUILDS** section of the
/// dashboard header, grouped by screen and sorted highest-first.
mixin MonitorRebuild<T extends StatefulWidget> on State<T> {
  void trackRebuild() {
    MonitorController.instance.recordRebuild(
      widget.runtimeType.toString(),
      MonitorNavigatorObserver.currentRoute,
    );
  }
}
