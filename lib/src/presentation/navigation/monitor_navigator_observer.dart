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
      _updateActiveRouteTitle();
    } else if (route is PopupRoute) {
      MonitorController.instance.setActivePopup(name);
      MonitorController.instance
          .logRoutePush(name, previousRoute?.settings.name);
      _updateActiveRouteTitle();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final name = route.settings.name;
    final prevName = previousRoute?.settings.name;

    if (prevName != null && prevName.isNotEmpty) {
      currentRoute = prevName;
    } else {
      final tempStack = List<String>.from(pageStack);
      if (name != null) {
        tempStack.remove(name);
      }
      currentRoute = tempStack.isNotEmpty ? tempStack.last : '/unknown';
    }

    if (name == null || name.isEmpty || name == '/MonitorDashboardPage') return;

    if (route is PageRoute) {
      pageStack.remove(name);
      if (!pageStack.contains(name)) {
        MonitorController.instance.logRoutePop(name, prevName);
      }
      if (prevName != null &&
          prevName.isNotEmpty &&
          prevName != '/MonitorDashboardPage') {
        MonitorController.instance.updateDashboardView(prevName);
      }
      _updateActiveRouteTitle();
    } else if (route is PopupRoute) {
      MonitorController.instance
        ..clearActivePopup(name)
        ..logRoutePop(name, prevName);
      MonitorController.instance.updateDashboardView(currentContentRoute);
      _updateActiveRouteTitle();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null || name.isEmpty || name == '/MonitorDashboardPage') return;

    final prevName = previousRoute?.settings.name;
    pageStack.remove(name);
    MonitorController.instance.logRoutePop(name, prevName);
    if (prevName != null &&
        prevName.isNotEmpty &&
        prevName != '/MonitorDashboardPage') {
      MonitorController.instance.updateDashboardView(prevName);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final oldName = oldRoute is PageRoute ? oldRoute.settings.name : null;
    final newName = newRoute is PageRoute ? newRoute.settings.name : null;

    if (oldName != null) pageStack.remove(oldName);

    if (newName != null &&
        newName.isNotEmpty &&
        newName != '/MonitorDashboardPage') {
      currentRoute = newName;
      pageStack.add(newName);
      MonitorController.instance.startSession(newName);
      _updateActiveRouteTitle();
    }

    if (oldName != null &&
        newName != null &&
        newName != '/MonitorDashboardPage') {
      MonitorController.instance.logRouteReplace(oldName, newName);
    }
  }

  void _updateActiveRouteTitle() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final title = _findAppBarTitle();
      if (title != null && title.isNotEmpty) {
        MonitorController.instance.updateCustomRouteName(currentRoute, title);
      }
    });
  }

  static String? _findAppBarTitle() {
    final nav = navigatorState;
    if (nav == null) return null;

    String? foundTitle;

    void visitor(Element element) {
      if (foundTitle != null) return;

      final widget = element.widget;
      if (widget is AppBar) {
        final titleWidget = widget.title;
        if (titleWidget is Text) {
          final text = titleWidget.data;
          if (text != null && text.isNotEmpty) {
            foundTitle = text;
            return;
          }
        }
      }

      final children = <Element>[];
      element.visitChildren((child) => children.add(child));
      for (final child in children.reversed) {
        visitor(child);
      }
    }

    try {
      nav.context.visitChildElements((element) {
        visitor(element);
      });
    } catch (_) {}

    return foundTitle;
  }
}
