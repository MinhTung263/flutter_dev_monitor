import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

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

  /// Runs [callback] immediately if the scheduler is idle with no scheduled frame,
  /// or at the end of the current frame if a frame is active/scheduled.
  static void _runAfterFrameOrNow(VoidCallback callback) {
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.idle &&
        !scheduler.hasScheduledFrame) {
      callback();
    } else {
      scheduler.addPostFrameCallback((_) => callback());
    }
  }

  static final RegExp _rawKeyPattern = RegExp(
    r'^[a-zA-Z0-9]+([_.:][a-zA-Z0-9]+)+$',
  );

  /// Detects if [text] looks like an untranslated localization key
  /// (e.g. `bills_billTitle`, `home_labelEasyInvoice`, `auth.login.title`).
  static bool _looksLikeRawLocalizationKey(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.contains(' ')) return false;
    return _rawKeyPattern.hasMatch(trimmed);
  }

  static String _translateIfNeeded(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;
    if (stringTranslator != null) {
      try {
        final translated = stringTranslator!(trimmed).trim();
        if (translated.isNotEmpty) return translated;
      } catch (_) {}
    }
    return trimmed;
  }

  /// The most recently pushed page route name (excludes popups and dashboard).
  static String _currentContentRoute = MonitorConstants.unknownRoute;
  static String _cachedCurrentContentRoute = MonitorConstants.unknownRoute;

  /// The topmost active route (including popups).
  static String _currentRoute = MonitorConstants.unknownRoute;
  static String _cachedCurrentRoute = MonitorConstants.unknownRoute;
  static String _actualTopRoute = MonitorConstants.unknownRoute;

  static String get actualTopRoute => _actualTopRoute;

  static String _lastResolvedRoute = MonitorConstants.unknownRoute;
  static String? _lastResolvedTabName;
  static String? _lastTabTitle;
  static bool _tabResolutionScheduled = false;
  static DateTime _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
  static int? _lastKnownTabIndex;
  static bool _searchedBottomBarForCurrentRoute = false;

  static Element? _cachedBottomBarElement;
  static Element? _cachedPageViewElement;

  /// Cache of authoritative titles extracted from a screen's own AppBar/Header
  /// (keyed by clean base route, e.g. `/~ACCOUNT/PAGEBUILDER/order_view` -> `'Lịch sử đơn hàng'`).
  /// Ensures a screen's confirmed AppBar title is never overwritten by a shorter
  /// BottomNavigationBar item label (`'Đơn hàng'`) or stolen across tabs.
  static final Map<String, String> _confirmedAppBarTitles = {};

  static int? _extractTabIndex(dynamic w) {
    try {
      final dynamic idx = w.currentIndex;
      if (idx is int) return idx;
    } catch (_) {}
    try {
      final dynamic idx = w.selectedIndex;
      if (idx is int) return idx;
    } catch (_) {}
    try {
      final dynamic idx = w.activeIndex;
      if (idx is int) return idx;
    } catch (_) {}
    try {
      final dynamic ctrl = w.controller;
      final dynamic idx = ctrl?.index;
      if (idx is int) return idx;
    } catch (_) {}
    return null;
  }

  static Iterable<dynamic>? _extractTabItems(dynamic w) {
    try {
      final dynamic items = w.items;
      if (items is Iterable) return items;
    } catch (_) {}
    try {
      final dynamic itemsData = w.itemsData;
      if (itemsData is Iterable) return itemsData;
    } catch (_) {}
    try {
      final dynamic destinations = w.destinations;
      if (destinations is Iterable) return destinations;
    } catch (_) {}
    try {
      final dynamic tabs = w.tabs;
      if (tabs is Iterable) return tabs;
    } catch (_) {}
    return null;
  }

  static int? _extractPageViewIndex() {
    if (_cachedPageViewElement != null && _cachedPageViewElement!.mounted) {
      try {
        final w = _cachedPageViewElement!.widget;
        if (w is PageView && w.controller != null && w.controller!.hasClients) {
          final page = w.controller!.page;
          if (page != null) return page.round();
        }
      } catch (_) {}
    }
    return null;
  }

  static void _syncResolveTabFast() {
    final nav = navigatorState;
    if (nav == null) return;
    if (_cachedBottomBarElement != null && _cachedBottomBarElement!.mounted) {
      try {
        final dynamic w = _cachedBottomBarElement!.widget;
        int? index = _extractTabIndex(w);
        final int? pageIdx = _extractPageViewIndex();
        // PageController.page updates synchronously on jumpToPage(), whereas
        // the bottom bar Widget's currentIndex only updates on the next frame rebuild.
        // Always prefer pageIdx when available so multiple calls within the same
        // pre-build frame never flip-flop back to the old tab index.
        if (pageIdx != null) {
          index = pageIdx;
        }
        if (index != null) {
          final bool tabIndexChanged =
              _lastKnownTabIndex != null && index != _lastKnownTabIndex;
          _lastKnownTabIndex = index;
          if (tabIndexChanged) {
            _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
          }
          final resolvedContent = _resolveNestedTabRoute(_currentContentRoute,
              overrideIndex: index);
          final resolvedCurrent =
              _resolveNestedTabRoute(_currentRoute, overrideIndex: index);
          if (resolvedContent != MonitorConstants.unknownRoute) {
            _cachedCurrentContentRoute = resolvedContent;
          }
          if (resolvedCurrent != MonitorConstants.unknownRoute) {
            _cachedCurrentRoute = resolvedCurrent;
          }
          final resolved = _cachedCurrentContentRoute;
          if (resolved != MonitorConstants.unknownRoute &&
              resolved != _lastResolvedRoute) {
            _applyResolvedTabTransition(_lastResolvedRoute, resolved);
          }
          if (tabIndexChanged) {
            _scheduleTabRouteResolution();
          }
        }
      } catch (_) {}
    } else if (!_searchedBottomBarForCurrentRoute &&
        MonitorController.instance.isMonitoringActive) {
      _scheduleTabRouteResolution();
    }
  }

  static void _applyResolvedTabTransition(String oldRoute, String resolved) {
    _lastResolvedRoute = resolved;
    final ctrl = MonitorController.instance;
    final String oldBase =
        oldRoute.contains('#') ? oldRoute.split('#').first : oldRoute;
    final String resolvedBase =
        resolved.contains('#') ? resolved.split('#').first : resolved;

    // If resolving from parent container route (e.g. '/page_builder') to its
    // initial tab ('/page_builder/home'), upgrade/rename the existing session
    // instead of leaving an orphaned parent session.
    final bool isInitialContainerTab = oldBase.isNotEmpty &&
        oldBase != MonitorConstants.unknownRoute &&
        resolvedBase.startsWith('$oldBase/');

    if (isInitialContainerTab || oldBase == resolvedBase) {
      ctrl.renameActiveSession(oldRoute, resolved);
      _updatePageStackEntry(oldRoute, resolved);
      _currentContentRoute = resolved;
      if (_currentRoute == oldRoute ||
          (_currentRoute.contains('#')
                  ? _currentRoute.split('#').first
                  : _currentRoute) ==
              oldBase) {
        _currentRoute = resolved;
      }
    } else {
      _currentContentRoute = resolved;
      _currentRoute = resolved;
      ctrl.startSession(resolved);
      if (oldRoute != MonitorConstants.unknownRoute &&
          oldBase != resolvedBase) {
        ctrl.logRouteReplace(oldRoute, resolved);
        _updatePageStackEntry(oldRoute, resolved);
      }
    }

    final confirmedAppBarTitle = _confirmedAppBarTitles[resolvedBase];
    if (confirmedAppBarTitle != null && confirmedAppBarTitle.isNotEmpty) {
      _renameActiveRouteSession(
        resolved,
        confirmedAppBarTitle,
        isFromAppBar: true,
      );
    } else if (_lastResolvedTabName != null && _lastTabTitle != null) {
      _renameActiveRouteSession(resolved, _lastTabTitle!, isFromAppBar: false);
    } else {
      final knownTitle = MonitorController.customRouteNames[resolvedBase];
      if (knownTitle != null && knownTitle.isNotEmpty) {
        _renameActiveRouteSession(resolved, knownTitle, isFromAppBar: false);
      }
    }

    // When switching to a new tab, schedule multi-frame AppBar title discovery
    // so that if the tab's inner AppBar (e.g. OrderPageAppBar -> "Lịch sử đơn hàng")
    // mounts asynchronously 1-2 frames after the BottomNavigationBar tap, it
    // upgrades the provisional tab label ("Đơn hàng").
    if (oldBase != resolvedBase && ctrl.isMonitoringActive) {
      _instance?._tryFindTitle(resolvedBase, attempt: 0, withRetry: true);
    }
  }

  static void _updatePageStackEntry(String oldRoute, String newRoute) {
    final String oldBase =
        oldRoute.contains('#') ? oldRoute.split('#').first : oldRoute;
    for (int i = pageStack.length - 1; i >= 0; i--) {
      final entry = pageStack[i];
      final entryBase = entry.contains('#') ? entry.split('#').first : entry;
      if (entry == oldRoute ||
          entryBase == oldBase ||
          newRoute.startsWith('$entryBase/')) {
        pageStack[i] = newRoute;
        return;
      }
    }
  }

  static String get currentContentRoute {
    _syncResolveTabFast();
    return _cachedCurrentContentRoute;
  }

  static set currentContentRoute(String value) {
    _currentContentRoute = value;
    _cachedCurrentContentRoute = _resolveTabRouteFor(value);
  }

  /// Manually sets the current active screen/route. Useful for PageView / Tab navigation.
  static void setCurrentScreen(String screenName) {
    if (screenName.isEmpty) return;
    _currentContentRoute = screenName;
    _cachedCurrentContentRoute = screenName;
    _currentRoute = screenName;
    _cachedCurrentRoute = screenName;
    _lastResolvedRoute = screenName;
    _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
    MonitorController.instance.startSession(screenName);
  }

  static String get currentRoute {
    _syncResolveTabFast();
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
        if (resolved != oldRoute) {
          _applyResolvedTabTransition(oldRoute, resolved);
        }
        final activeTitle = _findActiveAppBarTitle();
        final displayTitle = activeTitle ?? _lastTabTitle;
        if (displayTitle != null && displayTitle.isNotEmpty) {
          _renameActiveRouteSession(_lastResolvedRoute, displayTitle);
        }
      }
    } catch (_) {}
  }

  static void scheduleTabRouteResolutionForce() {
    if (!MonitorController.instance.isMonitoringActive) return;
    _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
    _scheduleTabRouteResolution();
  }

  static void _scheduleTabRouteResolution() {
    if (_tabResolutionScheduled) return;
    if (!MonitorController.instance.isMonitoringActive) return;
    final nav = navigatorState;
    if (nav == null) return;

    final now = DateTime.now();
    if (now.difference(_lastResolveTime).inMilliseconds < 250) return;

    _tabResolutionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tabResolutionScheduled = false;
      _lastResolveTime = DateTime.now();
      _performTabAndTitleResolution(scheduleFollowUp: true);
    });
  }

  static void _performTabAndTitleResolution({required bool scheduleFollowUp}) {
    final nav = navigatorState;
    if (nav == null) return;

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
      final String oldBase =
          oldRoute.contains('#') ? oldRoute.split('#').first : oldRoute;
      final String resolvedBase =
          resolved.contains('#') ? resolved.split('#').first : resolved;
      final isNewRoute = resolvedBase != oldBase;

      if (isNewRoute) {
        _applyResolvedTabTransition(oldRoute, resolved);
        if (scheduleFollowUp) {
          Future.delayed(const Duration(milliseconds: 120), () {
            _runAfterFrameOrNow(() {
              _performTabAndTitleResolution(scheduleFollowUp: false);
            });
          });
        }
      }

      final activeTitle = _findActiveAppBarTitle();
      if (activeTitle != null &&
          activeTitle.isNotEmpty &&
          !_looksLikeRawLocalizationKey(activeTitle)) {
        _renameActiveRouteSession(
          _lastResolvedRoute,
          activeTitle,
          isFromAppBar: true,
        );
      } else if (_lastResolvedTabName != null &&
          _lastTabTitle != null &&
          _lastTabTitle!.isNotEmpty) {
        _renameActiveRouteSession(
          _lastResolvedRoute,
          _lastTabTitle!,
          isFromAppBar: false,
        );
      }
    }
  }

  static String _resolveTabRouteFor(String route) {
    if (route == MonitorConstants.dashboardRoute) return route;

    if (_lastResolvedRoute != MonitorConstants.unknownRoute &&
        _lastResolvedTabName != null) {
      final String lastBase = _lastResolvedRoute.contains('#')
          ? _lastResolvedRoute.split('#').first
          : _lastResolvedRoute;
      final suffix = '/$_lastResolvedTabName';
      if (lastBase.endsWith(suffix)) {
        final cleanBase = lastBase.substring(
          0,
          lastBase.length - suffix.length,
        );
        final String routeBase =
            route.contains('#') ? route.split('#').first : route;
        if (routeBase == cleanBase) {
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
        if (title != null && title.isNotEmpty) {
          return _translateIfNeeded(title);
        }
      } catch (_) {}
    }

    final args = settings.arguments;
    if (args == null) return null;
    if (args is String && args.isNotEmpty) {
      final translated = _translateIfNeeded(args);
      if (!_looksLikeRawLocalizationKey(translated)) return translated;
    }
    if (args is Map) {
      final title =
          args['title'] ?? args['headerTitle'] ?? args['name'] ?? args['label'];
      if (title is String && title.isNotEmpty) {
        final translated = _translateIfNeeded(title);
        if (!_looksLikeRawLocalizationKey(translated)) return translated;
      }
    }
    try {
      final dynamic dArgs = args;
      final t = dArgs.title ?? dArgs.headerTitle ?? dArgs.name;
      if (t is String && t.isNotEmpty) {
        final translated = _translateIfNeeded(t);
        if (!_looksLikeRawLocalizationKey(translated)) return translated;
      }
    } catch (_) {}
    return null;
  }

  static void _renameActiveRouteSession(
    String oldRoute,
    String displayTitle, {
    bool isFromAppBar = false,
  }) {
    if (displayTitle.isEmpty) return;
    final cleanTitle =
        _translateIfNeeded(displayTitle).replaceAll('#', ' ').trim();
    if (cleanTitle.isEmpty) return;

    final String baseRoute =
        oldRoute.contains('#') ? oldRoute.split('#').first : oldRoute;
    final String currentTitle =
        oldRoute.contains('#') ? oldRoute.split('#').last : '';

    // Do not overwrite an already-translated human title with a raw key
    if (currentTitle.isNotEmpty &&
        !_looksLikeRawLocalizationKey(currentTitle) &&
        _looksLikeRawLocalizationKey(cleanTitle)) {
      return;
    }

    if (isFromAppBar && !_looksLikeRawLocalizationKey(cleanTitle)) {
      _confirmedAppBarTitles[baseRoute] = cleanTitle;
    } else if (!isFromAppBar && _confirmedAppBarTitles.containsKey(baseRoute)) {
      // Never allow a shortened BottomNavigationBar label (e.g. "Đơn hàng")
      // to overwrite an already-confirmed AppBar title (e.g. "Lịch sử đơn hàng").
      final confirmed = _confirmedAppBarTitles[baseRoute]!;
      if (currentTitle == confirmed) return;
      return _renameActiveRouteSession(
        oldRoute,
        confirmed,
        isFromAppBar: true,
      );
    }

    if (currentTitle == cleanTitle) return;

    final newRoute = '$baseRoute#$cleanTitle';

    MonitorController.instance.updateCustomRouteName(newRoute, cleanTitle);
    MonitorController.instance.renameActiveSession(oldRoute, newRoute);

    final String currentContentBase = _currentContentRoute.contains('#')
        ? _currentContentRoute.split('#').first
        : _currentContentRoute;
    if (_currentContentRoute == oldRoute || currentContentBase == baseRoute) {
      _currentContentRoute = newRoute;
    }

    final String currentRouteBase = _currentRoute.contains('#')
        ? _currentRoute.split('#').first
        : _currentRoute;
    if (_currentRoute == oldRoute || currentRouteBase == baseRoute) {
      _currentRoute = newRoute;
    }

    final String cachedContentBase = _cachedCurrentContentRoute.contains('#')
        ? _cachedCurrentContentRoute.split('#').first
        : _cachedCurrentContentRoute;
    if (_cachedCurrentContentRoute == oldRoute ||
        cachedContentBase == baseRoute) {
      _cachedCurrentContentRoute = newRoute;
    }

    final String cachedRouteBase = _cachedCurrentRoute.contains('#')
        ? _cachedCurrentRoute.split('#').first
        : _cachedCurrentRoute;
    if (_cachedCurrentRoute == oldRoute || cachedRouteBase == baseRoute) {
      _cachedCurrentRoute = newRoute;
    }

    final String lastResolvedBase = _lastResolvedRoute.contains('#')
        ? _lastResolvedRoute.split('#').first
        : _lastResolvedRoute;
    if (_lastResolvedRoute == oldRoute || lastResolvedBase == baseRoute) {
      _lastResolvedRoute = newRoute;
    }

    _updatePageStackEntry(oldRoute, newRoute);
  }

  static void _resetTabCache() {
    _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
    _cachedBottomBarElement = null;
    _cachedPageViewElement = null;
    _lastKnownTabIndex = null;
    _searchedBottomBarForCurrentRoute = false;
  }

  /// Clears cached AppBar titles and tab resolution state (called on Reset All).
  static void clearResolvedTitles() {
    _confirmedAppBarTitles.clear();
    _resetTabCache();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _resetTabCache();
    super.didPush(route, previousRoute);
    _actualTopRoute = route.settings.name ?? _popupFallbackName(route);
    if (isMonitorRoute(route)) return;

    // Handle PopupRoute (BottomSheet, Dialog) before the name guard
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
      if (MonitorController.instance.isMonitoringActive) {
        _tryFindPopupTitle(route, baseName, attempt: 0);
      }
      return;
    }

    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    if (name == MonitorConstants.dashboardRoute) return;

    final argTitle = _extractTitleFromSettings(route.settings) ??
        MonitorController.customRouteNames[name];
    final initialRouteName =
        (argTitle != null && argTitle.isNotEmpty) ? '$name#$argTitle' : name;

    currentRoute = initialRouteName;

    if (route is PageRoute) {
      _currentContentRoute = initialRouteName;
      _cachedCurrentContentRoute = initialRouteName;
      _lastResolvedRoute = initialRouteName;
      _lastResolvedTabName = null;
      _lastTabTitle = null;
      pageStack.add(initialRouteName);
      final ctrl = MonitorController.instance;
      ctrl.startSession(initialRouteName);
      ctrl.logRoutePush(
        initialRouteName,
        previousRoute?.settings.name,
        routeType: 'page',
      );
      if (ctrl.isMonitoringActive) {
        _updateActiveRouteTitle(withRetry: true);
      }
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _resetTabCache();
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _actualTopRoute =
          previousRoute.settings.name ?? _popupFallbackName(previousRoute);
    } else {
      _actualTopRoute = MonitorConstants.unknownRoute;
    }
    if (isMonitorRoute(route)) return;

    if (route is PopupRoute) {
      final name = _popupNameCache.remove(route) ?? _popupFallbackName(route);
      final prevName = previousRoute?.settings.name;
      MonitorController.instance
        ..clearActivePopup(name)
        ..logRoutePop(name, prevName, routeType: _getRouteType(route));
      MonitorController.instance.updateDashboardView(currentContentRoute);
      if (MonitorController.instance.isMonitoringActive) {
        _updateActiveRouteTitle();
      }
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
        tempStack.removeWhere(
          (r) => r == name || r.startsWith('$name#') || r.startsWith('$name/'),
        );
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
        (r) => r == name || r.startsWith('$name#') || r.startsWith('$name/'),
        orElse: () => name,
      );
      pageStack.remove(stackName);
      final prevContentName =
          pageStack.isNotEmpty ? pageStack.last : MonitorConstants.unknownRoute;
      _currentContentRoute = prevContentName;
      _cachedCurrentContentRoute = prevContentName;
      _currentRoute = prevContentName;
      _cachedCurrentRoute = prevContentName;
      _lastResolvedRoute = prevContentName;
      _lastResolvedTabName = null;
      _lastTabTitle = null;

      if (stackName.isNotEmpty && !pageStack.contains(stackName)) {
        MonitorController.instance
            .logRoutePop(stackName, prevName, routeType: 'page');
      }
      if (prevContentName.isNotEmpty &&
          prevContentName != MonitorConstants.dashboardRoute &&
          prevContentName != MonitorConstants.unknownRoute) {
        MonitorController.instance.updateDashboardView(prevContentName);
      }
      if (MonitorController.instance.isMonitoringActive) {
        _updateActiveRouteTitle();
      }
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _resetTabCache();
    super.didRemove(route, previousRoute);
    if (previousRoute != null) {
      _actualTopRoute =
          previousRoute.settings.name ?? _popupFallbackName(previousRoute);
    } else {
      _actualTopRoute = MonitorConstants.unknownRoute;
    }
    if (isMonitorRoute(route)) return;
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null ||
        name.isEmpty ||
        name == MonitorConstants.dashboardRoute) {
      return;
    }

    final prevName = previousRoute?.settings.name;
    final stackName = pageStack.lastWhere(
      (r) => r == name || r.startsWith('$name#') || r.startsWith('$name/'),
      orElse: () => name,
    );
    pageStack.remove(stackName);
    if (stackName.isNotEmpty) {
      MonitorController.instance.logRoutePop(stackName, prevName);
    }
    if (prevName != null &&
        prevName.isNotEmpty &&
        prevName != MonitorConstants.dashboardRoute) {
      MonitorController.instance.updateDashboardView(prevName);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _resetTabCache();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _actualTopRoute = newRoute.settings.name ?? _popupFallbackName(newRoute);
    }
    if (isMonitorRoute(newRoute)) return;
    final oldName = oldRoute is PageRoute ? oldRoute.settings.name : null;
    final newName = newRoute is PageRoute ? newRoute.settings.name : null;

    String? stackOldName;
    if (oldName != null) {
      stackOldName = pageStack.lastWhere(
        (r) =>
            r == oldName ||
            r.startsWith('$oldName#') ||
            r.startsWith('$oldName/'),
        orElse: () => oldName,
      );
      pageStack.remove(stackOldName);
    }

    final argTitle = newRoute != null
        ? (_extractTitleFromSettings(newRoute.settings) ??
            (newName != null
                ? MonitorController.customRouteNames[newName]
                : null))
        : null;
    final initialNewName =
        (newName != null && argTitle != null && argTitle.isNotEmpty)
            ? '$newName#$argTitle'
            : newName;

    if (initialNewName != null &&
        initialNewName.isNotEmpty &&
        initialNewName != MonitorConstants.dashboardRoute) {
      currentRoute = initialNewName;
      _currentContentRoute = initialNewName;
      _cachedCurrentContentRoute = initialNewName;
      _lastResolvedRoute = initialNewName;
      pageStack.add(initialNewName);
      MonitorController.instance.startSession(initialNewName);
      if (MonitorController.instance.isMonitoringActive) {
        _updateActiveRouteTitle(withRetry: true);
      }
    }

    if (stackOldName != null &&
        initialNewName != null &&
        initialNewName != MonitorConstants.dashboardRoute) {
      MonitorController.instance.logRouteReplace(stackOldName, initialNewName);
    }
  }

  /// Public static method to trigger a dynamic route title update.
  static void updateActiveRouteTitle() {
    _lastResolveTime = DateTime.fromMillisecondsSinceEpoch(0);
    _searchedBottomBarForCurrentRoute = false;
    _instance?._updateActiveRouteTitle(withRetry: true);
  }

  /// Delays between retries when title is not yet available (ms).
  static const _titleRetryDelays = [0, 60, 180, 450, 900];

  void _updateActiveRouteTitle({bool withRetry = false}) {
    if (!MonitorController.instance.isMonitoringActive) return;
    final capturedBase = _stripRouteTitle(_currentContentRoute);
    _tryFindTitle(capturedBase, attempt: 0, withRetry: withRetry);
  }

  static String _stripRouteTitle(String route) {
    return route.contains('#') ? route.split('#').first : route;
  }

  void _tryFindTitle(
    String capturedBase, {
    required int attempt,
    required bool withRetry,
  }) {
    _runAfterFrameOrNow(() {
      if (!MonitorController.instance.isMonitoringActive) return;
      final currentBase = _stripRouteTitle(_currentContentRoute);
      if (currentBase != capturedBase &&
          !currentBase.startsWith('$capturedBase/')) {
        return;
      }

      try {
        // First resolve any nested BottomNavigationBar / PageView tab
        _performTabAndTitleResolution(scheduleFollowUp: false);

        final appBarTitle = _findActiveAppBarTitle();
        if (appBarTitle != null &&
            appBarTitle.isNotEmpty &&
            !_looksLikeRawLocalizationKey(appBarTitle)) {
          _renameActiveRouteSession(
            _currentContentRoute,
            appBarTitle,
            isFromAppBar: true,
          );
          return;
        }

        // Apply provisional BottomNavBar tab label while waiting for AppBar
        if (_lastTabTitle != null &&
            _lastTabTitle!.isNotEmpty &&
            !_looksLikeRawLocalizationKey(_lastTabTitle!)) {
          _renameActiveRouteSession(
            _currentContentRoute,
            _lastTabTitle!,
            isFromAppBar: false,
          );
        }

        if (withRetry && attempt + 1 < _titleRetryDelays.length) {
          final nextDelay = _titleRetryDelays[attempt + 1];
          Future.delayed(Duration(milliseconds: nextDelay), () {
            _tryFindTitle(capturedBase, attempt: attempt + 1, withRetry: true);
          });
        }
      } catch (_) {}
    });
  }

  void _tryFindPopupTitle(
    PopupRoute<dynamic> popupRoute,
    String baseName, {
    required int attempt,
  }) {
    _runAfterFrameOrNow(() {
      if (!popupRoute.isActive) return;
      try {
        final title = _findScreenTitle(targetRoute: popupRoute);
        if (title != null &&
            title.isNotEmpty &&
            !_looksLikeRawLocalizationKey(title)) {
          final oldName = _popupNameCache[popupRoute] ?? baseName;
          final cleanTitle = title.replaceAll('#', ' ').trim();
          final newName = '$baseName#$cleanTitle';
          if (oldName != newName) {
            _popupNameCache[popupRoute] = newName;
            MonitorController.instance.setActivePopup(newName);
            MonitorController.instance.renameActiveSession(oldName, newName);
          }
        } else if (attempt + 1 < _titleRetryDelays.length) {
          final nextDelay = _titleRetryDelays[attempt + 1];
          Future.delayed(Duration(milliseconds: nextDelay), () {
            _tryFindPopupTitle(popupRoute, baseName, attempt: attempt + 1);
          });
        }
      } catch (_) {}
    });
  }

  static bool _isMatchingContentRoute(ModalRoute<dynamic>? route) {
    if (route == null || route is PopupRoute) return false;
    if (isMonitorRoute(route)) return false;
    final routeName = route.settings.name;
    if (routeName == MonitorConstants.dashboardRoute) return false;
    if (route.isCurrent) return true;
    if (routeName == null || routeName.isEmpty) return false;

    final cleanContent = _stripRouteTitle(_currentContentRoute);
    return cleanContent == routeName || cleanContent.startsWith('$routeName/');
  }

  static String? _extractTextFromElement(Element root) {
    final widget = root.widget;
    if (widget is Text) {
      final data = widget.data;
      if (data != null && data.trim().isNotEmpty) {
        return data.trim();
      }
      final span = widget.textSpan;
      if (span != null) {
        final plain = span.toPlainText().trim();
        if (plain.isNotEmpty) return plain;
      }
    }
    if (widget is RichText) {
      final plainText = widget.text.toPlainText().trim();
      if (plainText.isNotEmpty) {
        return plainText;
      }
    }
    String? found;
    root.visitChildren((child) {
      if (found != null) return;
      if (_isElementOffstage(child)) return;
      // Skip action buttons / icon buttons when extracting title text from an AppBar
      final childWidget = child.widget;
      if (childWidget is IconButton ||
          childWidget is TextButton ||
          childWidget is ElevatedButton ||
          childWidget is OutlinedButton ||
          childWidget is PopupMenuButton) {
        return;
      }
      found = _extractTextFromElement(child);
    });
    return found;
  }

  static Element? _findElementForWidget(Element root, Widget target) {
    if (root.widget == target) return root;
    Element? found;
    root.visitChildren((child) {
      if (found != null) return;
      found = _findElementForWidget(child, target);
    });
    return found;
  }

  static String? _extractTabItemTitle(
    dynamic item, {
    Element? bottomBarElement,
    int? itemIndex,
    int? totalItems,
  }) {
    String? rawTitle;

    // 1. Check common string properties on tab data models / BottomNavigationBarItem / Tab
    for (final getter in <dynamic Function(dynamic)>[
      (it) => it.title,
      (it) => it.label,
      (it) => it.text,
      (it) => it.headerTitle,
      (it) => it.name,
      (it) => it.tooltip,
    ]) {
      try {
        final dynamic val = getter(item);
        if (val is String && val.trim().isNotEmpty) {
          final candidate = val.trim();
          if (!_looksLikeRawLocalizationKey(candidate)) {
            rawTitle = candidate;
            break;
          }
          rawTitle ??= candidate;
        } else if (val is Widget && bottomBarElement != null) {
          final el = _findElementForWidget(bottomBarElement, val);
          if (el != null) {
            final t = _extractTextFromElement(el);
            if (t != null && t.isNotEmpty) {
              rawTitle = t;
              break;
            }
          }
        }
      } catch (_) {}
    }

    // 2. If item itself or item.child is a Widget, extract its rendered Text
    if ((rawTitle == null || _looksLikeRawLocalizationKey(rawTitle)) &&
        bottomBarElement != null) {
      try {
        final dynamic childWidget = item is Widget ? item : item.child;
        if (childWidget is Widget) {
          final el = _findElementForWidget(bottomBarElement, childWidget);
          if (el != null) {
            final t = _extractTextFromElement(el);
            if (t != null && t.isNotEmpty) {
              rawTitle = t;
            }
          }
        }
      } catch (_) {}
    }

    // 3. If property held an untranslated key (or no string property), read the
    // rendered Text widget directly from the bottomBarElement at itemIndex.
    // Because Flutter's Element tree always holds the post-translation rendered Text
    // (whether translated via .tr, AppLocalizations.of(context), easy_localization, etc.),
    // this works automatically with zero host-app configuration.
    if ((rawTitle == null || _looksLikeRawLocalizationKey(rawTitle)) &&
        bottomBarElement != null &&
        itemIndex != null) {
      final renderedTexts = <String>[];
      final badgeRegex = RegExp(r'^\d+\+?$');
      void collectBarTexts(Element el) {
        if (_isElementOffstage(el)) return;
        final w = el.widget;
        if (w is Text) {
          final t = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
          if (t.isNotEmpty && !badgeRegex.hasMatch(t)) {
            renderedTexts.add(t);
          }
          return;
        }
        if (w is RichText) {
          final t = w.text.toPlainText().trim();
          if (t.isNotEmpty && !badgeRegex.hasMatch(t)) {
            renderedTexts.add(t);
          }
          return;
        }
        el.visitChildren(collectBarTexts);
      }

      try {
        bottomBarElement.visitChildren(collectBarTexts);
        if (itemIndex >= 0 &&
            itemIndex < renderedTexts.length &&
            (totalItems == null || renderedTexts.length == totalItems)) {
          rawTitle = renderedTexts[itemIndex];
        }
      } catch (_) {}
    }

    if (rawTitle == null || rawTitle.isEmpty) return null;
    final translated = _translateIfNeeded(rawTitle);
    return translated;
  }

  static String _resolveNestedTabRoute(String baseRoute, {int? overrideIndex}) {
    final nav = navigatorState;
    if (nav == null) return baseRoute;

    dynamic foundBottomBarWidget;
    Element? bottomBarElement;

    if (_cachedBottomBarElement != null && _cachedBottomBarElement!.mounted) {
      try {
        final dynamic w = _cachedBottomBarElement!.widget;
        final int? index = _extractTabIndex(w);
        if (index != null) {
          foundBottomBarWidget = w;
          bottomBarElement = _cachedBottomBarElement;
        }
      } catch (_) {}
      if (foundBottomBarWidget == null) {
        _cachedBottomBarElement = null;
        _lastKnownTabIndex = null;
      }
    }

    void visitor(Element element, int depth) {
      if (depth > 80) return;
      final widget = element.widget;

      if (widget is PageView && !_isElementOffstage(element)) {
        final route = _findModalRouteOf(element);
        if (_isMatchingContentRoute(route)) {
          _cachedPageViewElement = element;
        }
      }

      if (foundBottomBarWidget == null) {
        try {
          final dynamic w = widget;
          final int? index = _extractTabIndex(w);
          if (index != null) {
            final route = _findModalRouteOf(element);
            if (_isMatchingContentRoute(route) &&
                !_isElementOffstage(element)) {
              final list = _extractTabItems(w);
              if (list != null) {
                foundBottomBarWidget = widget;
                bottomBarElement = element;
                _cachedBottomBarElement = element;
              }
            }
          }
        } catch (_) {}
      }

      if (foundBottomBarWidget != null && _cachedPageViewElement != null) {
        return;
      }

      // Prune subtrees that cannot contain a navigation bar or PageView
      if (widget is ListView ||
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

      if (widget is Scrollable &&
          widget.axisDirection != AxisDirection.right &&
          widget.axisDirection != AxisDirection.left) {
        return;
      }

      element.visitChildren((child) {
        visitor(child, depth + 1);
      });
    }

    if (foundBottomBarWidget == null ||
        (_cachedPageViewElement == null || !_cachedPageViewElement!.mounted)) {
      _searchedBottomBarForCurrentRoute = true;
      try {
        nav.context.visitChildElements((element) {
          visitor(element, 0);
        });
      } catch (_) {}
    }

    if (foundBottomBarWidget != null) {
      try {
        final dynamic w = foundBottomBarWidget;
        final list = _extractTabItems(w);
        if (list == null) return baseRoute;

        int? currentIndex =
            overrideIndex ?? _extractPageViewIndex() ?? _extractTabIndex(w);
        if (currentIndex != null &&
            (currentIndex < 0 || currentIndex >= list.length)) {
          currentIndex = _extractTabIndex(w);
        }

        if (currentIndex != null &&
            currentIndex >= 0 &&
            currentIndex < list.length) {
          _lastKnownTabIndex = currentIndex;
          final dynamic item = list.elementAt(currentIndex);

          // 1. Get route segment identifier dynamically
          String? tabName;
          try {
            final dynamic tabEnum = item.tabEnum;
            if (tabEnum != null) {
              tabName = tabEnum.toString().split('.').last;
            }
          } catch (_) {}
          if (tabName == null || tabName.isEmpty) {
            try {
              final dynamic r = item.route ?? item.key;
              if (r is String && r.trim().isNotEmpty) {
                tabName = r.trim().replaceAll('/', '');
              }
            } catch (_) {}
          }
          tabName ??= 'tab_$currentIndex';

          // 2. Extract the translated human-readable title of the selected tab item
          final extractedTabTitle = _extractTabItemTitle(
            item,
            bottomBarElement: bottomBarElement,
            itemIndex: currentIndex,
            totalItems: list.length,
          );

          _lastResolvedTabName = tabName;
          _lastTabTitle = extractedTabTitle;

          // 3. Normalize baseRoute: strip any existing /tabName suffix
          String existingHashTitle = '';
          String cleanBase = baseRoute;
          if (cleanBase.contains('#')) {
            final parts = cleanBase.split('#');
            cleanBase = parts.first;
            existingHashTitle = parts.sublist(1).join('#');
          }

          String? previousTabName;
          int loopIndex = 0;
          for (final dynamic it in list) {
            String? itName;
            try {
              final dynamic te = it.tabEnum;
              if (te != null) {
                itName = te.toString().split('.').last;
              }
            } catch (_) {}
            if (itName == null || itName.isEmpty) {
              try {
                final dynamic r = it.route ?? it.key;
                if (r is String && r.trim().isNotEmpty) {
                  itName = r.trim().replaceAll('/', '');
                }
              } catch (_) {}
            }
            itName ??= 'tab_$loopIndex';

            if (itName.isNotEmpty && cleanBase.endsWith('/$itName')) {
              previousTabName = itName;
              cleanBase = cleanBase.substring(
                0,
                cleanBase.length - itName.length - 1,
              );
              break;
            }
            loopIndex++;
          }

          final String newTabBase = '$cleanBase/$tabName';
          // Priority:
          // 1. Confirmed AppBar title for this exact tab (e.g. "Lịch sử đơn hàng")
          // 2. Live translated BottomNavBar item title (e.g. "Tổng quan", "Đơn hàng", "Hóa đơn", "Cài đặt")
          // 3. Existing #title if we are still on the exact same tab
          // 4. Known customRouteNames entry
          String finalTitle = '';
          if (_confirmedAppBarTitles.containsKey(newTabBase)) {
            finalTitle = _confirmedAppBarTitles[newTabBase]!;
          } else if (extractedTabTitle != null &&
              extractedTabTitle.isNotEmpty) {
            finalTitle = extractedTabTitle;
          } else if (previousTabName == tabName &&
              existingHashTitle.isNotEmpty) {
            finalTitle = existingHashTitle;
          } else if (MonitorController.customRouteNames
              .containsKey(newTabBase)) {
            finalTitle = MonitorController.customRouteNames[newTabBase]!;
          }

          return finalTitle.isNotEmpty ? '$newTabBase#$finalTitle' : newTabBase;
        }
      } catch (_) {}
    }

    _lastResolvedTabName = null;
    _lastTabTitle = null;
    return baseRoute;
  }

  static bool _isElementOffstage(Element element) {
    final selfPd = element.renderObject?.parentData;
    if (selfPd is KeepAliveParentDataMixin && selfPd.keptAlive) {
      return true;
    }

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
      if (w is Opacity && w.opacity == 0.0) {
        offstage = true;
        return false;
      }
      final pd = ancestor.renderObject?.parentData;
      if (pd is KeepAliveParentDataMixin && pd.keptAlive) {
        offstage = true;
        return false;
      }
      if (pd is SliverMultiBoxAdaptorParentData && pd.index != null) {
        int? enclosingPageIdx;
        ancestor.visitAncestorElements((pvAncestor) {
          final pvWidget = pvAncestor.widget;
          if (pvWidget is PageView) {
            try {
              if (pvWidget.controller != null &&
                  pvWidget.controller!.hasClients) {
                enclosingPageIdx = pvWidget.controller!.page?.round();
              } else if (pvWidget.controller != null) {
                enclosingPageIdx = pvWidget.controller!.initialPage;
              }
            } catch (_) {}
            return false;
          }
          return true;
        });
        if (enclosingPageIdx != null && pd.index != enclosingPageIdx) {
          offstage = true;
          return false;
        }
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
          // Shrink rect slightly by 2px so adjacent PageView pages touching at x == width are excluded
          final screenRect = Rect.fromLTWH(
            2.0,
            2.0,
            (screenSize!.width - 4.0).clamp(1.0, double.infinity),
            (screenSize!.height - 4.0).clamp(1.0, double.infinity),
          );
          if (!bounds.overlaps(screenRect)) {
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }

  static String? _findActiveAppBarTitle() => _findScreenTitle();

  static String? _findScreenTitle({Route<dynamic>? targetRoute}) {
    final nav = navigatorState;
    if (nav == null) return null;

    String? foundTitle;
    String? fallbackTitle;

    bool isRouteEligible(ModalRoute<dynamic>? route) {
      if (route == null || isMonitorRoute(route)) return false;
      if (targetRoute != null) {
        return route == targetRoute;
      }
      return _isMatchingContentRoute(route);
    }

    void recordCandidateTitle(String? candidate, {required bool isPrimary}) {
      if (candidate == null) return;
      final translated = _translateIfNeeded(candidate);
      if (translated.isEmpty) return;

      if (isPrimary && !_looksLikeRawLocalizationKey(translated)) {
        foundTitle ??= translated;
      } else {
        if (fallbackTitle == null ||
            (_looksLikeRawLocalizationKey(fallbackTitle!) &&
                !_looksLikeRawLocalizationKey(translated))) {
          fallbackTitle = translated;
        }
      }
    }

    void visitor(
      Element element,
      int depth, {
      bool insidePageView = false,
      int? activePageViewIndex,
    }) {
      if (foundTitle != null) return;
      if (depth > 120) return;

      final ro = element.renderObject;
      if (ro != null) {
        final pd = ro.parentData;
        if (pd is KeepAliveParentDataMixin && pd.keptAlive) {
          return;
        }
        if (activePageViewIndex != null &&
            pd is SliverMultiBoxAdaptorParentData &&
            pd.index != null &&
            pd.index != activePageViewIndex) {
          return;
        }
      }

      final widget = element.widget;
      final typeStr = widget.runtimeType.toString();

      // 1. Standard Material AppBar / SliverAppBar / CupertinoNavigationBar
      if (widget is AppBar ||
          widget is SliverAppBar ||
          widget is CupertinoNavigationBar ||
          widget is CupertinoSliverNavigationBar) {
        final route = _findModalRouteOf(element);
        if (!isRouteEligible(route) || _isElementOffstage(element)) {
          return;
        }
        Widget? titleWidget;
        if (widget is AppBar) {
          titleWidget = widget.title;
        } else if (widget is SliverAppBar) {
          titleWidget = widget.title;
        } else if (widget is CupertinoNavigationBar) {
          titleWidget = widget.middle;
        } else if (widget is CupertinoSliverNavigationBar) {
          titleWidget = widget.largeTitle ?? widget.middle;
        }

        if (titleWidget != null) {
          final titleElement = _findElementForWidget(element, titleWidget);
          if (titleElement != null) {
            final text = _extractTextFromElement(titleElement);
            if (text != null && text.isNotEmpty) {
              recordCandidateTitle(text, isPrimary: true);
              if (foundTitle != null) return;
            }
          }
        }
      }

      // 2. Custom AppBar / Header / BottomSheetHeader (e.g. BaseAppBar, OrderPageAppBar, BottomSheetHeader)
      final isCustomAppBar = widget is PreferredSizeWidget ||
          typeStr.contains('AppBar') ||
          typeStr.endsWith('Header') ||
          typeStr == 'BottomSheetHeader';

      if (isCustomAppBar &&
          widget is! AppBar &&
          widget is! SliverAppBar &&
          widget is! TabBar) {
        final route = _findModalRouteOf(element);
        if (isRouteEligible(route) && !_isElementOffstage(element)) {
          // 2a. Check String property (title / headerTitle) as fallback
          try {
            final dynamic w = widget;
            String? propTitle;
            try {
              if (w.title is String) propTitle = w.title as String;
            } catch (_) {}
            if (propTitle == null || propTitle.isEmpty) {
              try {
                if (w.headerTitle is String) {
                  propTitle = w.headerTitle as String;
                }
              } catch (_) {}
            }
            if (propTitle != null && propTitle.trim().isNotEmpty) {
              recordCandidateTitle(propTitle, isPrimary: false);
            }
          } catch (_) {}

          // 2b. Traverse children of custom AppBar/Header first (may contain Material AppBar or rendered Text)
          element.visitChildren((child) {
            if (foundTitle != null) return;
            visitor(
              child,
              depth + 1,
              insidePageView: insidePageView,
              activePageViewIndex: activePageViewIndex,
            );
          });
          if (foundTitle != null) return;

          // 2c. If custom Header does not use Material AppBar (e.g. BottomSheetHeader),
          // extract the rendered Text directly from its subtree (which is already translated!).
          final renderedText = _extractTextFromElement(element);
          if (renderedText != null && renderedText.isNotEmpty) {
            recordCandidateTitle(renderedText, isPrimary: true);
            if (foundTitle != null) return;
          }
          return;
        }
      }

      // 3. Optimize Scaffold traversal:
      // If a Scaffold has an appBar, visit ONLY its appBar!
      // If a Scaffold has NO appBar (e.g. outer PageBuilderPage Scaffold wrapping a PageView,
      // or tablet AdaptiveMasterDetailScaffold), continue into its body!
      if (widget is Scaffold && !_isElementOffstage(element)) {
        final appBar = widget.appBar;
        if (appBar != null) {
          final appBarElement = _findElementForWidget(element, appBar);
          if (appBarElement != null) {
            visitor(
              appBarElement,
              depth + 1,
              insidePageView: insidePageView,
              activePageViewIndex: activePageViewIndex,
            );
            if (foundTitle != null) return;
          }
          return;
        }
      }

      // 4. Optimize IndexedStack: only visit the active index child!
      if (widget is IndexedStack) {
        final activeIdx = widget.index ?? 0;
        int currentIdx = 0;
        element.visitChildren((child) {
          if (currentIdx == activeIdx) {
            visitor(
              child,
              depth + 1,
              insidePageView: true,
              activePageViewIndex: activePageViewIndex,
            );
          }
          currentIdx++;
        });
        return;
      }

      final bool isPageContainer =
          insidePageView || widget is PageView || widget is TabBarView;
      int? nextActivePageViewIndex = activePageViewIndex;
      if (widget is PageView) {
        try {
          if (widget.controller != null && widget.controller!.hasClients) {
            nextActivePageViewIndex = widget.controller!.page?.round();
          } else if (widget.controller != null) {
            nextActivePageViewIndex = widget.controller!.initialPage;
          }
        } catch (_) {}
        nextActivePageViewIndex ??= _lastKnownTabIndex;
      }

      // 5. Prune vertical scrolling content lists & leaf widgets that cannot contain a screen AppBar.
      // IMPORTANT: Do NOT prune horizontal Scrollable inside PageView / TabBarView!
      if (widget is ListView ||
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

      if (widget is Scrollable) {
        final isHorizontalPageScroll = isPageContainer &&
            (widget.axisDirection == AxisDirection.right ||
                widget.axisDirection == AxisDirection.left);
        if (!isHorizontalPageScroll) {
          return;
        }
      }

      // 6. Visit children:
      // - For Stack/Overlay, reverse order visits the topmost visual layer first.
      // - For Row/Column/Flex and other widgets, natural order (0..n-1) visits
      //   top headers and left Master panes (AdaptiveMasterDetailScaffold) first!
      if (widget is Stack || widget is Overlay) {
        final children = <Element>[];
        element.visitChildren(children.add);
        for (final child in children.reversed) {
          if (foundTitle != null) return;
          visitor(
            child,
            depth + 1,
            insidePageView: isPageContainer,
            activePageViewIndex: nextActivePageViewIndex,
          );
        }
      } else {
        element.visitChildren((child) {
          if (foundTitle != null) return;
          visitor(
            child,
            depth + 1,
            insidePageView: isPageContainer,
            activePageViewIndex: nextActivePageViewIndex,
          );
        });
      }
    }

    try {
      nav.context.visitChildElements((element) {
        visitor(element, 0);
      });
    } catch (_) {}

    return foundTitle ?? fallbackTitle;
  }

  static ModalRoute<dynamic>? _findModalRouteOf(Element element) {
    try {
      final route = ModalRoute.of(element);
      if (route != null) return route;
    } catch (_) {}
    ModalRoute<dynamic>? route;
    element.visitAncestorElements((ancestor) {
      final w = ancestor.widget;
      if (w is InheritedWidget) {
        try {
          final dynamic scope = w;
          final dynamic possibleRoute = scope.route;
          if (possibleRoute is ModalRoute) {
            route = possibleRoute;
            return false;
          }
        } catch (_) {}
      }
      return true;
    });
    return route;
  }
}
