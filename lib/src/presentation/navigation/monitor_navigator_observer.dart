import 'package:flutter/material.dart';

import '../controller/monitor_controller.dart';

class MonitorNavigatorObserver extends NavigatorObserver {
  static MonitorNavigatorObserver? _instance;

  MonitorNavigatorObserver() {
    _instance = this;
  }

  /// The NavigatorState of the host app — available after the first route push.
  static NavigatorState? get navigatorState => _instance?.navigator;

  static final List<String> pageStack = [];

  /// The most recently pushed page route name (excludes popups and dashboard).
  static String currentContentRoute = '/unknown';

  /// The topmost active route (including popups).
  static String currentRoute = '/unknown';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;

    currentRoute = name;

    if (name == '/MonitorDashboardPage') return;

    if (route is PageRoute) {
      pageStack.add(name);
      final ctrl = MonitorController.instance;
      ctrl.startSession(name);
      ctrl.logRoutePush(name, previousRoute?.settings.name);
    } else if (route is PopupRoute) {
      MonitorController.instance.setActivePopup(name);
      MonitorController.instance.logRoutePush(name, previousRoute?.settings.name);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final name = route.settings.name;
    final prevName = previousRoute?.settings.name;

    if (prevName != null && prevName.isNotEmpty) {
      currentRoute = prevName;
    }

    if (name == null || name.isEmpty || name == '/MonitorDashboardPage') return;

    if (route is PageRoute) {
      pageStack.remove(name);
      if (!pageStack.contains(name)) {
        MonitorController.instance.logRoutePop(name, prevName);
      }
    } else if (route is PopupRoute) {
      MonitorController.instance
        ..clearActivePopup(name)
        ..logRoutePop(name, prevName);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null || name.isEmpty || name == '/MonitorDashboardPage') return;

    pageStack.remove(name);
    MonitorController.instance.logRoutePop(name, previousRoute?.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final oldName = oldRoute is PageRoute ? oldRoute.settings.name : null;
    final newName = newRoute is PageRoute ? newRoute.settings.name : null;

    if (oldName != null) pageStack.remove(oldName);

    if (newName != null && newName.isNotEmpty &&
        newName != '/MonitorDashboardPage') {
      currentRoute = newName;
      pageStack.add(newName);
      MonitorController.instance.startSession(newName);
    }

    if (oldName != null && newName != null &&
        newName != '/MonitorDashboardPage') {
      MonitorController.instance.logRouteReplace(oldName, newName);
    }
  }
}
