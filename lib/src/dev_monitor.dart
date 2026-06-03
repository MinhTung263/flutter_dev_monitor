import 'package:flutter/widgets.dart';

import 'data/monitor_interceptor.dart';
import 'presentation/navigation/monitor_navigator_observer.dart';
import 'presentation/ui/widgets/fps_overlay.dart';

abstract final class DevMonitor {
  static final MonitorNavigatorObserver observer = MonitorNavigatorObserver();
  static final MonitorInterceptor interceptor = MonitorInterceptor();
  static Widget appBuilder(BuildContext context, Widget? child) =>
      FpsOverlay(child: child ?? const SizedBox.shrink());
}
