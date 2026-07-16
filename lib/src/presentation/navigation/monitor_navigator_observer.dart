import 'package:flutter/material.dart';

import '../../core/monitor_constants.dart';
import '../controller/monitor_controller.dart';

/// A navigator observer that tracks screen transitions and routes to DevMonitor.
class MonitorNavigatorObserver extends NavigatorObserver {
  static MonitorNavigatorObserver? _instance;

  static bool isMonitorRoute(Route<dynamic>? route) {
    if (route == null) return false;

    final typeName = route.runtimeType.toString().toLowerCase();
    final name = route.settings.name;
    final nameLower = name?.toLowerCase() ?? '';

    final shouldIgnore = typeName.contains('flush') ||
        typeName.contains('flash') ||
        typeName.contains('notification') ||
        typeName.contains('message') ||
        typeName.contains('snackbar') ||
        typeName.contains('toast') ||
        typeName.contains('tooltip') ||
        nameLower.contains('monitor') ||
        nameLower.contains('flush') ||
        nameLower.contains('flash') ||
        nameLower.contains('notification') ||
        nameLower.contains('message') ||
        nameLower.contains('snackbar') ||
        nameLower.contains('toast') ||
        nameLower.contains('tooltip');

    return shouldIgnore;
  }

  /// Creates a new [MonitorNavigatorObserver] instance.
  MonitorNavigatorObserver() {
    _instance = this;
  }

  /// The NavigatorState of the host app — available after the first route push.
  static NavigatorState? get navigatorState => _instance?.navigator;

  /// The history stack of visited page route names.
  static final List<String> pageStack = [];

  /// Optional custom title mapper based on route name and route settings.
  static String? Function(String route, RouteSettings settings)?
      routeTitleMapper;

  /// Optional callback to translate localization keys (e.g. key -> key.tr).
  static String Function(String key)? stringTranslator;

  /// Tracks generated names for PopupRoutes that have no settings.name.
  final Map<Route<dynamic>, String> _popupNameCache = {};

  /// Generates a fallback route name from a popup route's runtime type.
  static String _popupFallbackName(Route<dynamic> route) {
    final typeName = route.runtimeType.toString();
    // e.g. '_ModalBottomSheetRoute' → 'bottomSheet', 'DialogRoute' → 'dialog'
    if (typeName.toLowerCase().contains('bottomsheet')) return 'bottomSheet';
    if (typeName.toLowerCase().contains('dialog')) return 'dialog';
    return typeName;
  }

  static String _getRouteType(Route<dynamic> route) {
    if (route is PageRoute) return 'page';
    final typeName = route.runtimeType.toString().toLowerCase();
    if (typeName.contains('bottomsheet')) return 'bottomSheet';
    if (typeName.contains('dialog')) return 'dialog';
    return 'popup';
  }

  /// The most recently pushed page route name (excludes popups and dashboard).
  static String _currentContentRoute = MonitorConstants.unknownRoute;
  static String _cachedCurrentContentRoute = MonitorConstants.unknownRoute;

  static String get currentContentRoute {
    _scheduleTabRouteResolution();
    return _cachedCurrentContentRoute;
  }

  static set currentContentRoute(String value) {
    _currentContentRoute = value;
    _cachedCurrentContentRoute = _resolveTabRouteFor(value);
  }

  /// The topmost active route (including popups).
  static String _currentRoute = MonitorConstants.unknownRoute;
  static String _cachedCurrentRoute = MonitorConstants.unknownRoute;
  static String _lastResolvedRoute = MonitorConstants.unknownRoute;
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
      if (resolved != MonitorConstants.unknownRoute) {
        final oldRoute = _lastResolvedRoute;
        final isNewRoute = resolved != oldRoute;
        if (isNewRoute) {
          _lastResolvedRoute = resolved;
          final ctrl = MonitorController.instance;
          ctrl.startSession(resolved);
          if (oldRoute != MonitorConstants.unknownRoute &&
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
          _renameActiveRouteSession(resolved, displayTitle);
        }
      }
    } catch (_) {}
  }

  static void scheduleTabRouteResolutionForce() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0); // Bypass the 1.5s throttling
      _scheduleTabRouteResolution();
    });
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

      if (resolvedContent != MonitorConstants.unknownRoute) {
        _cachedCurrentContentRoute = resolvedContent;
      } else {
        _cachedCurrentContentRoute = _resolveTabRouteFor(_currentContentRoute);
      }

      if (resolvedCurrent != MonitorConstants.unknownRoute) {
        _cachedCurrentRoute = resolvedCurrent;
      } else {
        _cachedCurrentRoute = _resolveTabRouteFor(_currentRoute);
      }

      final resolved = _cachedCurrentContentRoute;
      if (resolved != MonitorConstants.unknownRoute) {
        final oldRoute = _lastResolvedRoute;
        final isNewRoute = resolved != oldRoute;

        if (isNewRoute) {
          _lastResolvedRoute = resolved;
          final ctrl = MonitorController.instance;
          ctrl.startSession(resolved);
          if (oldRoute != MonitorConstants.unknownRoute &&
              oldRoute != resolved &&
              !resolved.startsWith('$oldRoute/')) {
            ctrl.logRouteReplace(oldRoute, resolved);
          }
          // 1. Update instantly with static tab title if available to eliminate any latency
          if (_lastResolvedTabName != null && _lastTabTitle != null) {
            _renameActiveRouteSession(resolved, _lastTabTitle!);
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
          _renameActiveRouteSession(resolved, displayTitle);
        }
      }
    });
  }

  static String _resolveTabRouteFor(String route) {
    // Keep the dashboard route as is
    if (route == '/MonitorDashboardPage') return route;

    if (_lastResolvedRoute != MonitorConstants.unknownRoute &&
        _lastResolvedTabName != null) {
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

  static String? _extractTitleFromSettings(RouteSettings settings) {
    final name = settings.name;
    if (name != null && name.isNotEmpty && routeTitleMapper != null) {
      try {
        final title = routeTitleMapper!(name, settings);
        if (title != null && title.isNotEmpty) return title;
      } catch (_) {}
    }

    final args = settings.arguments;

    if (args == null) return null;
    if (args is String && args.isNotEmpty) {
      return args;
    }
    if (args is Map) {
      final title =
          args['title'] ?? args['headerTitle'] ?? args['name'] ?? args['label'];
      if (title is String && title.isNotEmpty) {
        return title;
      }
    }
    try {
      final dynamic dArgs = args;
      final t = dArgs.title ?? dArgs.headerTitle ?? dArgs.name;
      if (t is String && t.isNotEmpty) {
        return t;
      }
    } catch (_) {}
    return null;
  }

  static void _renameActiveRouteSession(String oldRoute, String displayTitle) {
    if (displayTitle.isEmpty) return;
    final cleanTitle = displayTitle.replaceAll('#', ' ').trim();
    if (cleanTitle.isEmpty) return;

    final String baseRoute = oldRoute.contains('#') ? oldRoute.split('#').first : oldRoute;
    final String currentTitle = oldRoute.contains('#') ? oldRoute.split('#').last : '';

    if (currentTitle == cleanTitle) return; // No change needed

    final newRoute = '$baseRoute#$cleanTitle';

    MonitorController.instance.updateCustomRouteName(newRoute, cleanTitle);
    MonitorController.instance.renameActiveSession(oldRoute, newRoute);

    if (_currentContentRoute == oldRoute) {
      _currentContentRoute = newRoute;
    }
    if (_currentRoute == oldRoute) {
      _currentRoute = newRoute;
    }
    if (_cachedCurrentContentRoute == oldRoute) {
      _cachedCurrentContentRoute = newRoute;
    }
    if (_cachedCurrentRoute == oldRoute) {
      _cachedCurrentRoute = newRoute;
    }
    if (_lastResolvedRoute == oldRoute) {
      _lastResolvedRoute = newRoute;
    }
    final idx = pageStack.lastIndexOf(oldRoute);
    if (idx >= 0) {
      pageStack[idx] = newRoute;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
    _cachedBottomBarElement = null;
    super.didPush(route, previousRoute);
    if (isMonitorRoute(route)) return;

    // Handle PopupRoute (BottomSheet, Dialog) before the name guard
    // because they often have no settings.name.
    if (route is PopupRoute) {
      final rawName = route.settings.name;
      final baseName = (rawName != null && rawName.isNotEmpty)
          ? rawName
          : _popupFallbackName(route);
      final argTitle = _extractTitleFromSettings(route.settings);
      final name = (argTitle != null && argTitle.isNotEmpty)
          ? '$baseName#$argTitle'
          : baseName;

      _popupNameCache[route] = name;
      MonitorController.instance.setActivePopup(name);
      MonitorController.instance.logRoutePush(
        name,
        previousRoute?.settings.name,
        routeType: _getRouteType(route),
      );
      _updateActiveRouteTitle(withRetry: true);
      return;
    }

    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    if (name == MonitorConstants.dashboardRoute) return;

    final argTitle = _extractTitleFromSettings(route.settings);
    final initialRouteName =
        (argTitle != null && argTitle.isNotEmpty) ? '$name#$argTitle' : name;

    currentRoute = initialRouteName;

    if (route is PageRoute) {
      _currentContentRoute = initialRouteName;
      _lastResolvedRoute = initialRouteName;
      _lastResolvedTabName = null;
      pageStack.add(initialRouteName);
      final ctrl = MonitorController.instance;
      ctrl.startSession(initialRouteName);
      ctrl.logRoutePush(
        initialRouteName,
        previousRoute?.settings.name,
        routeType: 'page',
      );
      _updateActiveRouteTitle(withRetry: true);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
    _cachedBottomBarElement = null;
    super.didPop(route, previousRoute);
    if (isMonitorRoute(route)) return;

    // Handle PopupRoute before the name guard (BottomSheet may have no name).
    if (route is PopupRoute) {
      final name = _popupNameCache.remove(route) ?? _popupFallbackName(route);
      final prevName = previousRoute?.settings.name;
      MonitorController.instance
        ..clearActivePopup(name)
        ..logRoutePop(name, prevName, routeType: _getRouteType(route));
      MonitorController.instance.updateDashboardView(currentContentRoute);
      _updateActiveRouteTitle();
      return;
    }

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
      currentRoute =
          tempStack.isNotEmpty ? tempStack.last : MonitorConstants.unknownRoute;
    }

    if (name == null ||
        name.isEmpty ||
        name == MonitorConstants.dashboardRoute) {
      return;
    }

    if (route is PageRoute) {
      final stackName = pageStack.lastWhere(
        (r) => r == name || r.startsWith('$name#'),
        orElse: () => name,
      );
      pageStack.remove(stackName);
      final prevContentName =
          pageStack.isNotEmpty ? pageStack.last : MonitorConstants.unknownRoute;
      _currentContentRoute = prevContentName;
      _lastResolvedRoute = prevContentName;
      _lastResolvedTabName = null;

      if (stackName.isNotEmpty && !pageStack.contains(stackName)) {
        MonitorController.instance
            .logRoutePop(stackName, prevName, routeType: 'page');
      }
      if (prevName != null &&
          prevName.isNotEmpty &&
          prevName != '/MonitorDashboardPage') {
        MonitorController.instance.updateDashboardView(prevName);
      }
      _updateActiveRouteTitle();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
    _cachedBottomBarElement = null;
    super.didRemove(route, previousRoute);
    if (isMonitorRoute(route)) return;
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null || name.isEmpty || name == '/MonitorDashboardPage') return;

    final prevName = previousRoute?.settings.name;
    final stackName = pageStack.lastWhere(
      (r) => r == name || r.startsWith('$name#'),
      orElse: () => name,
    );
    pageStack.remove(stackName);
    if (stackName.isNotEmpty) {
      MonitorController.instance.logRoutePop(stackName, prevName);
    }
    if (prevName != null &&
        prevName.isNotEmpty &&
        prevName != '/MonitorDashboardPage') {
      MonitorController.instance.updateDashboardView(prevName);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
    _cachedBottomBarElement = null;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (isMonitorRoute(newRoute)) return;
    final oldName = oldRoute is PageRoute ? oldRoute.settings.name : null;
    final newName = newRoute is PageRoute ? newRoute.settings.name : null;

    String? stackOldName;
    if (oldName != null) {
      stackOldName = pageStack.lastWhere(
        (r) => r == oldName || r.startsWith('$oldName#'),
        orElse: () => oldName,
      );
      pageStack.remove(stackOldName);
    }

    final argTitle =
        newRoute != null ? _extractTitleFromSettings(newRoute.settings) : null;
    final initialNewName =
        (newName != null && argTitle != null && argTitle.isNotEmpty)
            ? '$newName#$argTitle'
            : newName;

    if (initialNewName != null &&
        initialNewName.isNotEmpty &&
        initialNewName != '/MonitorDashboardPage') {
      currentRoute = initialNewName;
      pageStack.add(initialNewName);
      MonitorController.instance.startSession(initialNewName);
      _updateActiveRouteTitle();
    }

    if (stackOldName != null &&
        initialNewName != null &&
        initialNewName != '/MonitorDashboardPage') {
      MonitorController.instance.logRouteReplace(stackOldName, initialNewName);
    }
  }

  /// Public static method to trigger a dynamic route title update.
  static void updateActiveRouteTitle() {
    _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
    _instance?._updateActiveRouteTitle();
  }

  /// Delays between retries when title is not yet available (ms).
  static const _titleRetryDelays = [0, 250, 600, 1200];

  void _updateActiveRouteTitle({bool withRetry = false}) {
    final capturedRoute = currentRoute;
    _tryFindTitle(capturedRoute, attempt: 0, withRetry: withRetry);
  }

  void _tryFindTitle(String capturedRoute,
      {required int attempt, required bool withRetry}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Stop if user navigated away or route was already renamed with a title.
      if (currentRoute != capturedRoute) return;

      final title = _findAppBarTitle();
      if (title != null && title.isNotEmpty) {
        _renameActiveRouteSession(currentRoute, title);
      } else if (withRetry && attempt + 1 < _titleRetryDelays.length) {
        // Title not ready yet (e.g. async controller state) — retry after delay.
        final nextDelay = _titleRetryDelays[attempt + 1];
        Future.delayed(Duration(milliseconds: nextDelay), () {
          _tryFindTitle(capturedRoute, attempt: attempt + 1, withRetry: true);
        });
      }
    });
  }

  static String? _findAppBarTitle() {
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
      final typeStr = widget.runtimeType.toString();

      final isCustomAppBar =
          typeStr.contains('AppBar') || typeStr.contains('Header');

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

    final result = foundTitle ?? fallbackTitle;
    if (result == null) return null;
    return stringTranslator != null ? stringTranslator!(result) : result;
  }

  static Element? _cachedBottomBarElement;

  static String _resolveNestedTabRoute(String baseRoute) {
    final nav = navigatorState;
    if (nav == null) return baseRoute;

    dynamic foundBottomBarWidget;

    if (_cachedBottomBarElement != null) {
      try {
        final dynamic w = _cachedBottomBarElement!.widget;
        final int? index = w.currentIndex as int?;
        if (index != null) {
          foundBottomBarWidget = w;
        }
      } catch (_) {}
      if (foundBottomBarWidget == null) {
        _cachedBottomBarElement = null;
      }
    }

    Element? findElementForWidget(Element root, Widget target) {
      if (root.widget == target) return root;
      Element? found;
      root.visitChildren((child) {
        if (found != null) return;
        found = findElementForWidget(child, target);
      });
      return found;
    }

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
          final String baseContent = _currentContentRoute.contains('#')
              ? _currentContentRoute.split('#').first
              : _currentContentRoute;
          if (!route.isCurrent && route.settings.name != baseContent) {
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
            _cachedBottomBarElement = element;
            return;
          }
        }
      } catch (_) {}

      // Optimize: If we hit a Scaffold, traverse ONLY its bottomNavigationBar widget and skip the rest (like body)
      if (widget is Scaffold && !_isElementOffstage(element)) {
        final bottomBar = widget.bottomNavigationBar;
        if (bottomBar != null) {
          final bottomBarElement = findElementForWidget(element, bottomBar);
          if (bottomBarElement != null) {
            visitor(bottomBarElement, depth + 1);
            return;
          }
        }
      }

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

          // Get route segment identifier dynamically
          String? tabName;
          try {
            final dynamic tabEnum = item.tabEnum;
            tabName = tabEnum.toString().split('.').last;
          } catch (_) {}
          tabName ??= 'tab_$currentIndex';

          _lastResolvedTabName = tabName;
          _lastTabTitle = null; // Do not use BottomNavigationBar title, let Scaffold provide it later

          // Normalize baseRoute: strip any existing /tabName suffix to avoid infinite nesting
          String hashPart = '';
          String cleanBase = baseRoute;
          if (cleanBase.contains('#')) {
            final parts = cleanBase.split('#');
            cleanBase = parts.first;
            hashPart = '#${parts.sublist(1).join('#')}';
          }
          int loopIndex = 0;
          for (final dynamic it in list) {
            String? itName;
            try {
              itName = it.tabEnum.toString().split('.').last;
            } catch (_) {}
            
            itName ??= 'tab_$loopIndex';

            if (itName.isNotEmpty &&
                cleanBase.endsWith('/$itName')) {
              cleanBase = cleanBase.substring(
                0,
                cleanBase.length - itName.length - 1,
              );
              break;
            }
            loopIndex++;
          }
          final finalRoute = '$cleanBase/$tabName$hashPart';
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
    if (offstage) return true;

    // Filter out kept-alive pages in PageView/TabBarView that are rendered off-screen
    try {
      final renderObject = element.renderObject;
      if (renderObject is RenderBox && renderObject.attached) {
        if (!renderObject.hasSize || renderObject.size.isEmpty) return true;
        final position = renderObject.localToGlobal(Offset.zero);
        final bounds = position & renderObject.size;
        
        Size? screenSize;
        element.visitAncestorElements((ancestor) {
          final w = ancestor.widget;
          if (w is MediaQuery) {
            screenSize = w.data.size;
            return false;
          }
          return true;
        });
        
        if (screenSize != null) {
          final screenRect = Offset.zero & screenSize!;
          if (!bounds.overlaps(screenRect)) {
            return true; // The element is completely outside the screen boundaries
          }
        }
      }
    } catch (_) {}

    return false;
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
      final isCustomAppBar =
          typeStr.contains('AppBar') || typeStr.contains('Header');
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
            if (route != null &&
                (route.isCurrent || isContentRoute) &&
                !_isElementOffstage(element)) {
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

    final result = foundTitle ?? fallbackTitle;
    if (result == null) return null;
    return stringTranslator != null ? stringTranslator!(result) : result;
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
