import 'package:flutter/material.dart';

import '../../core/monitor_constants.dart';
import '../controller/monitor_controller.dart';

/// A navigator observer that tracks screen transitions and routes to DevMonitor.
class MonitorNavigatorObserver extends NavigatorObserver {
  static MonitorNavigatorObserver? _instance;

  static bool isMonitorRoute(Route<dynamic>? route) {
    if (route == null) return false;
    final name = route.settings.name;
    if (name == null) return false;
    return name.contains('Monitor') ||
        name.contains('MonitorDashboardPage') ||
        name.contains('MonitorLogsPage') ||
        name.contains('MonitorApiDetailPage');
  }

  /// Creates a new [MonitorNavigatorObserver] instance.
  MonitorNavigatorObserver() {
    _instance = this;
  }

  /// The NavigatorState of the host app — available after the first route push.
  static NavigatorState? get navigatorState => _instance?.navigator;

  /// The history stack of visited page route names.
  static final List<String> pageStack = [];

  /// The most recently pushed page route name (excludes popups and dashboard).
  static String _currentContentRoute = '/unknown';
  static String _cachedCurrentContentRoute = '/unknown';

  static String get currentContentRoute {
    _scheduleTabRouteResolution();
    return _cachedCurrentContentRoute;
  }

  static set currentContentRoute(String value) {
    _currentContentRoute = value;
    _cachedCurrentContentRoute = _resolveTabRouteFor(value);
  }

  /// The topmost active route (including popups).
  static String _currentRoute = '/unknown';
  static String _cachedCurrentRoute = '/unknown';
  static String _lastResolvedRoute = '/unknown';
  static String? _lastResolvedTabName;
  static String? _lastTabTitle;
  static bool _tabResolutionScheduled = false;
  static DateTime _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);

  static String get currentRoute {
    _scheduleTabRouteResolution();
    return _cachedCurrentRoute;
  }

  static set currentRoute(String value) {
    _currentRoute = value;
    _cachedCurrentRoute = _resolveTabRouteFor(value);
  }

  /// Synchronously resolves the active tab route and title. Call only from user interaction handlers.
  static void resolveTabRouteContent() {
    final nav = navigatorState;
    if (nav == null) return;
    try {
      final resolved = _resolveNestedTabRoute(_currentContentRoute);
      if (resolved != '/unknown') {
        final oldRoute = _lastResolvedRoute;
        final isNewRoute = resolved != oldRoute;
        if (isNewRoute) {
          _lastResolvedRoute = resolved;
          final ctrl = MonitorController.instance;
          ctrl.startSession(resolved);
          if (oldRoute != '/unknown' &&
              oldRoute != resolved &&
              !resolved.startsWith('$oldRoute/')) {
            ctrl.logRouteReplace(oldRoute, resolved);
          }
        }
        String? displayTitle;
        if (_lastResolvedTabName != null) {
          displayTitle = _lastTabTitle;
        } else {
          displayTitle = _findActiveAppBarTitle();
        }

        if (displayTitle != null) {
          MonitorController.instance.updateCustomRouteName(
            resolved,
            displayTitle,
          );
        }
      }
    } catch (_) {}
  }

  static void scheduleTabRouteResolutionForce() {
    final now = DateTime.now();
    if (now.difference(_lastResolveTime).inMilliseconds < 500) return;
    _lastResolveTime = now;
    _scheduleTabRouteResolution();
  }

  static void _scheduleTabRouteResolution() {
    if (_tabResolutionScheduled) return;
    final nav = navigatorState;
    if (nav == null) return;

    final now = DateTime.now();
    if (now.difference(_lastResolveTime).inMilliseconds < 1500) return;

    _tabResolutionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tabResolutionScheduled = false;
      _lastResolveTime = DateTime.now();
      
      final resolvedContent = _resolveNestedTabRoute(_currentContentRoute);
      final resolvedCurrent = _resolveNestedTabRoute(_currentRoute);

      if (resolvedContent != '/unknown') {
        _cachedCurrentContentRoute = resolvedContent;
      } else {
        _cachedCurrentContentRoute = _resolveTabRouteFor(_currentContentRoute);
      }

      if (resolvedCurrent != '/unknown') {
        _cachedCurrentRoute = resolvedCurrent;
      } else {
        _cachedCurrentRoute = _resolveTabRouteFor(_currentRoute);
      }

      final resolved = _cachedCurrentContentRoute;
      if (resolved != '/unknown') {
        final oldRoute = _lastResolvedRoute;
        final isNewRoute = resolved != oldRoute;

        if (isNewRoute) {
          _lastResolvedRoute = resolved;
          final ctrl = MonitorController.instance;
          ctrl.startSession(resolved);
          if (oldRoute != '/unknown' &&
              oldRoute != resolved &&
              !resolved.startsWith('$oldRoute/')) {
            ctrl.logRouteReplace(oldRoute, resolved);
          }
          // 1. Update instantly with static tab title if available to eliminate any latency
          if (_lastResolvedTabName != null && _lastTabTitle != null) {
            ctrl.updateCustomRouteName(resolved, _lastTabTitle!);
          }
          // 2. Schedule a delayed resolution to let the tab transition animation complete and refine with active AppBar title
          Future.delayed(const Duration(milliseconds: 120), () {
            _instance?._updateActiveRouteTitle();
            _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
            _scheduleTabRouteResolution();
          });
        }

        String? displayTitle = _findActiveAppBarTitle();
        if (displayTitle == null && _lastResolvedTabName != null) {
          displayTitle = _lastTabTitle;
        }

        if (displayTitle != null) {
          MonitorController.instance.updateCustomRouteName(
            resolved,
            displayTitle,
          );
        }
      }
    });
  }

  static String _resolveTabRouteFor(String route) {
    // Keep the dashboard route as is
    if (route == '/MonitorDashboardPage') return route;

    if (_lastResolvedRoute != '/unknown' && _lastResolvedTabName != null) {
      final suffix = '/$_lastResolvedTabName';
      if (_lastResolvedRoute.endsWith(suffix)) {
        final cleanBase = _lastResolvedRoute.substring(
          0,
          _lastResolvedRoute.length - suffix.length,
        );
        if (route == cleanBase) {
          return _lastResolvedRoute;
        }
      }
    }
    return route;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
    super.didPush(route, previousRoute);
    if (isMonitorRoute(route)) return;
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;

    if (name == MonitorConstants.dashboardRoute) return;

    currentRoute = name;

    if (route is PageRoute) {
      _currentContentRoute = name;
      _lastResolvedRoute = name;
      _lastResolvedTabName = null;
      pageStack.add(name);
      final ctrl = MonitorController.instance;
      ctrl.startSession(name);
      ctrl.logRoutePush(name, previousRoute?.settings.name);
      _updateActiveRouteTitle();
    } else if (route is PopupRoute) {
      MonitorController.instance.setActivePopup(name);
      MonitorController.instance.logRoutePush(
        name,
        previousRoute?.settings.name,
      );
      _updateActiveRouteTitle();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
    super.didPop(route, previousRoute);
    if (isMonitorRoute(route)) return;
    final name = route.settings.name;
    final prevName = previousRoute?.settings.name;

    if (prevName != null &&
        prevName.isNotEmpty &&
        prevName != MonitorConstants.dashboardRoute) {
      currentRoute = prevName;
    } else {
      final tempStack = List<String>.from(pageStack);
      if (name != null) {
        tempStack.remove(name);
      }
      currentRoute = tempStack.isNotEmpty ? tempStack.last : '/unknown';
    }

    if (name == null || name.isEmpty || name == MonitorConstants.dashboardRoute) {
      return;
    }

    if (route is PageRoute) {
      pageStack.remove(name);
      final prevContentName =
          pageStack.isNotEmpty ? pageStack.last : '/unknown';
      _currentContentRoute = prevContentName;
      _lastResolvedRoute = prevContentName;
      _lastResolvedTabName = null;

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
    _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
    super.didRemove(route, previousRoute);
    if (isMonitorRoute(route)) return;
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
    _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (isMonitorRoute(newRoute)) return;
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

  /// Public static method to trigger a dynamic route title update.
  static void updateActiveRouteTitle() {
    _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
    _instance?._updateActiveRouteTitle();
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
    if (nav == null) {
      return null;
    }

    String? foundTitle;
    String? fallbackTitle;

    Element? findElementForWidget(Element root, Widget target) {
      if (root.widget == target) return root;
      Element? found;
      root.visitChildren((child) {
        if (found != null) return;
        found = findElementForWidget(child, target);
      });
      return found;
    }

    String? findTextInElement(Element root) {
      final widget = root.widget;
      if (widget is Text) {
        if (widget.data != null && widget.data!.isNotEmpty) {
          return widget.data;
        }
      }
      if (widget is RichText) {
        final plainText = widget.text.toPlainText();
        if (plainText.isNotEmpty) {
          return plainText;
        }
      }
      String? found;
      root.visitChildren((child) {
        if (found != null) return;
        found = findTextInElement(child);
      });
      return found;
    }

    void visitor(Element element, int depth) {
      if (foundTitle != null) return;
      if (depth > 120) return;

      final widget = element.widget;
      final typeStr = widget.runtimeType.toString();

      final isCustomAppBar = typeStr.contains('AppBar') || typeStr.contains('Header');

      // Support for custom app bars/headers with a String title property (e.g. BaseAppBar)
      if (isCustomAppBar) {
        try {
          final dynamic w = widget;
          final dynamic t = w.title;
          if (t is String && t.isNotEmpty) {
            final route = _findModalRouteOf(element);
            if (route != null && isMonitorRoute(route)) {
              return;
            }
            final isTargetRoute = route != null &&
                (route.isCurrent || route.settings.name == currentRoute);
            if (isTargetRoute && !_isElementOffstage(element)) {
              fallbackTitle = t;
            }
          }
        } catch (_) {}
      }

      if (widget is AppBar) {
        final route = _findModalRouteOf(element);
        if (route != null && isMonitorRoute(route)) {
          return;
        }
        final isTargetRoute = route != null &&
            (route.isCurrent || route.settings.name == currentRoute);
        if (!isTargetRoute || _isElementOffstage(element)) {
          return;
        }
        if (route.settings.name == MonitorConstants.dashboardRoute) {
          return;
        }
        final titleWidget = widget.title;
        if (titleWidget != null) {
          final titleElement = findElementForWidget(element, titleWidget);
          if (titleElement != null) {
            final text = findTextInElement(titleElement);
            if (text != null && text.isNotEmpty) {
              foundTitle = text;
              return;
            }
          }
        }
      }

      // Optimize: If we hit a Scaffold, traverse ONLY its appBar widget and skip the rest (like body)
      if (widget is Scaffold && !_isElementOffstage(element)) {
        final appBar = widget.appBar;
        if (appBar != null) {
          final appBarElement = findElementForWidget(element, appBar);
          if (appBarElement != null) {
            visitor(appBarElement, depth + 1);
            return;
          }
        }
      }

      // Prune subtrees that cannot contain an AppBar to optimize performance
      if (widget is Scrollable ||
          widget is ListView ||
          widget is GridView ||
          widget is CustomScrollView ||
          widget is SingleChildScrollView ||
          widget is ListTile ||
          widget is Card ||
          widget is Text ||
          widget is RichText ||
          widget is Icon ||
          widget is Image) {
        return;
      }

      final children = <Element>[];
      element.visitChildren((child) => children.add(child));
      for (final child in children.reversed) {
        visitor(child, depth + 1);
      }
    }

    try {
      nav.context.visitChildElements((child) {
        visitor(child, 0);
      });
    } catch (_) {}

    return foundTitle ?? fallbackTitle;
  }

  static String _resolveNestedTabRoute(String baseRoute) {
    final nav = navigatorState;
    if (nav == null) return baseRoute;

    dynamic foundBottomBarWidget;

    void visitor(Element element, int depth) {
      if (foundBottomBarWidget != null) return;
      if (depth > 80) return;

      final widget = element.widget;
      try {
        final dynamic w = widget;
        final int? index = w.currentIndex as int?;
        if (index != null) {
          final route = _findModalRouteOf(element);
          if (route == null) return;
          // Only match if the bottom bar is part of the topmost route,
          // or part of the current active content route (e.g. if the dashboard is overlayed on top)
          if (!route.isCurrent && route.settings.name != _currentContentRoute) {
            return;
          }

          dynamic list;
          try {
            list = w.items;
          } catch (_) {}
          try {
            list ??= w.itemsData;
          } catch (_) {}
          try {
            list ??= w.tabs;
          } catch (_) {}

          if (list != null && list is Iterable) {
            foundBottomBarWidget = widget;
            return;
          }
        }
      } catch (_) {}

      // Prune subtrees that cannot contain a navigation bar to optimize performance
      if (widget is Scrollable ||
          widget is ListView ||
          widget is GridView ||
          widget is CustomScrollView ||
          widget is SingleChildScrollView ||
          widget is ListTile ||
          widget is Card ||
          widget is Text ||
          widget is RichText ||
          widget is Icon ||
          widget is Image) {
        return;
      }

      final children = <Element>[];
      element.visitChildren((child) => children.add(child));
      for (final child in children.reversed) {
        visitor(child, depth + 1);
      }
    }

    try {
      nav.context.visitChildElements((element) {
        visitor(element, 0);
      });
    } catch (_) {}

    if (foundBottomBarWidget != null) {
      try {
        final dynamic w = foundBottomBarWidget;
        final int currentIndex = w.currentIndex as int;

        dynamic rawItems;
        try {
          rawItems = w.items;
        } catch (_) {}
        try {
          rawItems ??= w.itemsData;
        } catch (_) {}
        try {
          rawItems ??= w.tabs;
        } catch (_) {}

        final list = rawItems as Iterable;

        if (currentIndex >= 0 && currentIndex < list.length) {
          final dynamic item = list.elementAt(currentIndex);

          // Get localized title/label dynamically
          String? title;
          try {
            title = item.title as String?;
          } catch (_) {}
          try {
            title ??= item.label as String?;
          } catch (_) {}

          // Get route segment identifier dynamically
          String? tabName;
          try {
            final dynamic tabEnum = item.tabEnum;
            tabName = tabEnum.toString().split('.').last;
          } catch (_) {}
          tabName ??= title?.toLowerCase().replaceAll(' ', '_');
          tabName ??= 'tab_$currentIndex';

          _lastResolvedTabName = tabName;
          _lastTabTitle =
              (title != null && title.isNotEmpty) ? title : 'Tab $currentIndex';

          // Normalize baseRoute: strip any existing /tabName suffix to avoid infinite nesting
          String cleanBase = baseRoute;
          for (final dynamic it in list) {
            String? itName;
            try {
              itName = it.tabEnum.toString().split('.').last;
            } catch (_) {}
            try {
              itName ??= (it.label as String?)?.toLowerCase().replaceAll(
                    ' ',
                    '_',
                  );
            } catch (_) {}
            try {
              itName ??= (it.title as String?)?.toLowerCase().replaceAll(
                    ' ',
                    '_',
                  );
            } catch (_) {}

            if (itName != null &&
                itName.isNotEmpty &&
                cleanBase.endsWith('/$itName')) {
              cleanBase = cleanBase.substring(
                0,
                cleanBase.length - itName.length - 1,
              );
              break;
            }
          }
          final finalRoute = '$cleanBase/$tabName';
          return finalRoute;
        }
      } catch (_) {}
    }

    _lastResolvedTabName = null;
    return baseRoute;
  }

  static bool _isElementOffstage(Element element) {
    bool offstage = false;
    element.visitAncestorElements((ancestor) {
      final w = ancestor.widget;
      if (w is Offstage && w.offstage) {
        offstage = true;
        return false;
      }
      if (w is Visibility && !w.visible) {
        offstage = true;
        return false;
      }
      return true;
    });
    return offstage;
  }

  static String? _findActiveAppBarTitle() {
    final nav = navigatorState;
    if (nav == null) return null;

    String? foundTitle;
    String? fallbackTitle;

    Element? findElementForWidget(Element root, Widget target) {
      if (root.widget == target) return root;
      Element? found;
      root.visitChildren((child) {
        if (found != null) return;
        found = findElementForWidget(child, target);
      });
      return found;
    }

    String? findTextInElement(Element root) {
      final widget = root.widget;
      if (widget is Text) {
        if (widget.data != null && widget.data!.isNotEmpty) {
          return widget.data;
        }
      }
      if (widget is RichText) {
        final plainText = widget.text.toPlainText();
        if (plainText.isNotEmpty) {
          return plainText;
        }
      }
      String? found;
      root.visitChildren((child) {
        if (found != null) return;
        found = findTextInElement(child);
      });
      return found;
    }

    void visitor(Element element, int depth) {
      if (foundTitle != null) return;
      if (depth > 120) return;

      final widget = element.widget;

      // Support for custom app bars/headers with a String title property (e.g. BaseAppBar)
      final typeStr = widget.runtimeType.toString();
      final isCustomAppBar = typeStr.contains('AppBar') || typeStr.contains('Header');
      if (isCustomAppBar) {
        try {
          final dynamic w = widget;
          final dynamic t = w.title;
          if (t is String && t.isNotEmpty) {
            final route = _findModalRouteOf(element);
            if (route != null && isMonitorRoute(route)) {
              return;
            }
            final isContentRoute =
                route != null && route.settings.name == _currentContentRoute;
            if (route != null && (route.isCurrent || isContentRoute) && !_isElementOffstage(element)) {
              fallbackTitle = t;
            }
          }
        } catch (_) {}
      }

      if (widget is AppBar) {
        final route = _findModalRouteOf(element);
        if (route != null && isMonitorRoute(route)) {
          return;
        }
        final isContentRoute =
            route != null && route.settings.name == _currentContentRoute;
        if (route != null &&
            (route.isCurrent || isContentRoute) &&
            !_isElementOffstage(element)) {
          if (route.settings.name == MonitorConstants.dashboardRoute) return;
          final titleWidget = widget.title;
          if (titleWidget != null) {
            final titleElement = findElementForWidget(element, titleWidget);
            if (titleElement != null) {
              final text = findTextInElement(titleElement);
              if (text != null && text.isNotEmpty) {
                foundTitle = text;
                return;
              }
            }
          }
        }
      }

      // Optimize: If we hit a Scaffold, traverse ONLY its appBar widget and skip the rest (like body)
      if (widget is Scaffold && !_isElementOffstage(element)) {
        final appBar = widget.appBar;
        if (appBar != null) {
          final appBarElement = findElementForWidget(element, appBar);
          if (appBarElement != null) {
            visitor(appBarElement, depth + 1);
            return;
          }
        }
      }

      // Prune subtrees that cannot contain an AppBar to optimize performance
      if (widget is Scrollable ||
          widget is ListView ||
          widget is GridView ||
          widget is CustomScrollView ||
          widget is SingleChildScrollView ||
          widget is ListTile ||
          widget is Card ||
          widget is Text ||
          widget is RichText ||
          widget is Icon ||
          widget is Image) {
        return;
      }

      final children = <Element>[];
      element.visitChildren((child) => children.add(child));
      for (final child in children.reversed) {
        visitor(child, depth + 1);
      }
    }

    try {
      nav.context.visitChildElements((element) {
        visitor(element, 0);
      });
    } catch (_) {}

    return foundTitle ?? fallbackTitle;
  }

  static ModalRoute? _findModalRouteOf(Element element) {
    ModalRoute? route;
    element.visitAncestorElements((ancestor) {
      final w = ancestor.widget;
      if (w is InheritedWidget) {
        try {
          final dynamic scope = w;
          final dynamic possibleRoute = scope.route;
          if (possibleRoute is ModalRoute) {
            route = possibleRoute;
            return false; // stop traversal
          }
        } catch (_) {}
      }
      return true;
    });
    return route;
  }
}
