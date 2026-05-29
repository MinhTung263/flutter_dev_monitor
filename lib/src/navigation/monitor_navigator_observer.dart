import 'package:flutter/material.dart';

import '../controller/monitor_controller.dart';

class MonitorNavigatorObserver extends NavigatorObserver {
  static MonitorNavigatorObserver? _instance;

  MonitorNavigatorObserver() {
    _instance = this;
  }

  /// The NavigatorState of the host app — available after the first route push.
  /// Use this to navigate from outside the Navigator widget tree (e.g. FpsOverlay).
  static NavigatorState? get navigatorState => _instance?.navigator;

  static final List<String> pageStack = [];
  static final Map<String, String> pageToSessionMap = {};

  /// The most recently pushed page route name (excludes popups and dashboard).
  static String currentContentRoute = '/unknown';

  /// The topmost active route (including popups).
  static String currentRoute = '/unknown';

  static String get _activeAnchor =>
      pageStack.length > 1 ? pageStack[1] : (pageStack.firstOrNull ?? '/unknown');

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;

    currentRoute = name;

    if (name == '/MonitorDashboardPage') return;

    if (route is PageRoute) {
      pageStack.add(name);
      pageToSessionMap[name] = _activeAnchor;
      MonitorController.instance.startSession(name);
    } else if (route is PopupRoute) {
      MonitorController.instance.setActivePopup(name);
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
        final ctrl = MonitorController.instance;
        if (pageToSessionMap[name] == name) {
          ctrl.clearSessionByAnchor(name);
          pageToSessionMap.removeWhere((_, v) => v == name);
        } else {
          ctrl.clearScreenData(name);
          pageToSessionMap.remove(name);
        }
      }
    } else if (route is PopupRoute) {
      MonitorController.instance.clearActivePopup(name);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null || name.isEmpty || name == '/MonitorDashboardPage') return;

    pageStack.remove(name);
    if (!pageStack.contains(name) && pageToSessionMap[name] == name) {
      MonitorController.instance.clearSessionByAnchor(name);
      pageToSessionMap.removeWhere((_, v) => v == name);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute is PageRoute) {
      final oldName = oldRoute.settings.name;
      if (oldName != null) {
        pageStack.remove(oldName);
        if (!pageStack.contains(oldName) &&
            pageToSessionMap[oldName] == oldName) {
          MonitorController.instance.clearSessionByAnchor(oldName);
          pageToSessionMap.removeWhere((_, v) => v == oldName);
        }
      }
    }
    if (newRoute is PageRoute) {
      final name = newRoute.settings.name;
      if (name != null && name.isNotEmpty && name != '/MonitorDashboardPage') {
        currentRoute = name;
        pageStack.add(name);
        pageToSessionMap[name] = _activeAnchor;
      }
    }
  }
}
