import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/monitor_constants.dart';
import '../../core/monitor_strings.dart';
import '../ui/theme/monitor_theme.dart';
import '../../data/hardware_datasource.dart';
import '../../domain/api_log_item.dart';
import '../../domain/error_log_item.dart';
import '../../domain/route_log_item.dart';
import '../navigation/monitor_navigator_observer.dart';
import 'api_log_controller.dart';
import 'error_log_controller.dart';
import 'fps_controller.dart';
import 'hardware_controller.dart';
import 'route_log_controller.dart';

/// The main controller that holds the state of the dev monitor (logs, metrics, etc.).
class MonitorController extends ChangeNotifier {
  MonitorController._() {
    _init();
  }

  static MonitorController? _instance;

  /// The singleton instance of [MonitorController].
  static MonitorController get instance => _instance ??= MonitorController._();

  final _apiLog = ApiLogController();
  final _fps = FpsController();
  final _hardware = HardwareController();
  final _errorLog = ErrorLogController();
  final _routeLog = RouteLogController();
  final _datasource = HardwareDatasource();

  // All screen names seen this session — ordered by last visit (most recent last).
  // A screen that is re-visited is moved to the end so .reversed gives newest-first.
  final List<String> _visitedScreens = [];

  Timer? _hardwareTimer;
  Timer? _pingTimer;
  int? _currentPingMs;
  bool _disposed = false;
  bool _isReportingError = false;
  bool _isOverlayVisible = true;

  bool _isDashboardOpen = false;
  bool get isDashboardOpen => _isDashboardOpen;
  set isDashboardOpen(bool value) {
    if (_isDashboardOpen != value) {
      _isDashboardOpen = value;
      _apiLog.isDashboardOpen = value;
      _apiLog.updateView(_apiLog.currentViewedScreen);
      updatePingMonitoring();
      updateHardwareMonitoring();
      notifyListeners();
    }
  }

  bool _alertsDismissed = false;
  bool get alertsDismissed => _alertsDismissed;

  void dismissAlerts() {
    if (!_alertsDismissed) {
      _alertsDismissed = true;
      notifyListeners();
    }
  }

  /// Custom route name mappings (e.g., {'/home': 'Home Screen'})
  static Map<String, String> customRouteNames = {};

  void updateCustomRouteName(String route, String title) {
    if (customRouteNames[route] != title) {
      customRouteNames[route] = title;
      notifyListeners();
    }
  }

  static String formatRouteName(String route) {
    // If route has a #title suffix (e.g. "/~PRODUCT/PRODDETAIL#Tạo sản phẩm mới"),
    // extract the title part as the display name.
    if (route.contains('#')) {
      final title = route.split('#').last;
      if (title.isNotEmpty) return title;
    }
    if (customRouteNames.containsKey(route)) {
      return customRouteNames[route]!;
    }
    if (route == MonitorConstants.allScreensKey) {
      return LocaleKeys.allScreens.tr;
    }
    if (route == MonitorConstants.unknownRoute) {
      return LocaleKeys.unknownScreen.tr;
    }
    if (route.isEmpty) return '';

    String path = route;
    if (path.contains('/')) {
      path = path.split('/').last;
    }
    return path;
  }

  // ── Expose API log state ──────────────────────────────────────────────

  List<ApiLogItem> get apiLogs => _apiLog.apiLogs;
  List<ApiLogItem> get globalApiLogs => _apiLog.globalApiLogs;
  Map<String, List<ApiLogItem>> get initLogsMap => _apiLog.initLogsMap;
  Map<String, List<ApiLogItem>> get refreshLogsMap => _apiLog.refreshLogsMap;
  int get initApiCount => _apiLog.initApiCount;
  int get refreshApiCount => _apiLog.refreshApiCount;
  int get initTotalDuration => _apiLog.initTotalDuration;
  int get refreshTotalDuration => _apiLog.refreshTotalDuration;
  int get totalRefreshApiCount => _apiLog.totalRefreshApiCount;
  int get totalRefreshDuration => _apiLog.totalRefreshDuration;
  int get errorCount => _apiLog.errorCount;
  int get globalApiErrorCount => _apiLog.globalApiErrorCount;
  int get globalSlowApiCount => _apiLog.globalSlowApiCount;

  DateTime? sessionStartTime(String screen) => _apiLog.sessionStartTime(screen);

  ({
    int openCount,
    int openMs,
    int visitCount,
    int actionCount,
    int actionMs,
    int actionCycles
  }) screenStats(String screen) => _apiLog.statsForScreen(screen);

  bool get isCurrentScreenInRefresh =>
      _apiLog.isInRefresh(MonitorNavigatorObserver.currentRoute);

  int get currentPhaseApiCount {
    if (isDashboardOpen) {
      return _apiLog.apiLogs.length;
    } else {
      return isCurrentScreenInRefresh ? refreshApiCount : initApiCount;
    }
  }

  // ── Expose FPS state ──────────────────────────────────────────────────

  double get currentFps => _fps.currentFps;
  double get currentBuildMs => _fps.currentBuildMs;
  double get currentGpuMs => _fps.currentGpuMs;
  int get jankFrameCount => _fps.jankFrameCount;
  Map<String, List<double>> get fpsHistoryMap => _fps.fpsHistoryMap;
  List<double> get overlayFpsHistory => _fps.overlayFpsHistory;
  List<double> get overlayGpuHistory => _fps.overlayGpuHistory;
  List<double> get overlayBuildHistory => _fps.overlayBuildHistory;

  // ── Visited screens (never cleared on pop, ordered by last visit) ────

  /// Returns screen names in last-visited-first order (newest at index 0).
  List<String> get visitedScreens =>
      List.unmodifiable(_visitedScreens.reversed.toList());

  // ── Expose error log state ────────────────────────────────────────────

  List<ErrorLogItem> get errorLogs => _errorLog.errors;
  int get flutterErrorCount => _errorLog.count;

  // ── Expose route log state ────────────────────────────────────────────

  List<RouteLogItem> get routeLogs => _routeLog.logs;
  int get routeLogCount => _routeLog.count;

  void logRoutePush(String route, String? from, {String routeType = 'page'}) {
    _routeLog.logPush(route, from, routeType: routeType);
    notifyListeners();
  }

  void logRoutePop(String route, String? to, {String routeType = 'page'}) {
    _routeLog.logPop(route, to, routeType: routeType);
    notifyListeners();
  }

  void logRouteReplace(String oldRoute, String newRoute,
      {String routeType = 'page'}) {
    _routeLog.logReplace(oldRoute, newRoute, routeType: routeType);
    notifyListeners();
  }

  // ── Expose ping state ────────────────────────────────────────────────

  int? get currentPingMs => _currentPingMs;

  // ── Expose hardware state ─────────────────────────────────────────────

  double get currentRam => _hardware.currentRam;
  double get totalRam => _hardware.totalRam;
  double get appDiskUsed => _hardware.appDiskUsed;
  double get totalDisk => _hardware.totalDisk;
  Map<String, List<double>> get ramHistoryMap => _hardware.ramHistoryMap;
  List<double> get globalRamHistory => _hardware.globalRamHistory;
  String get deviceModel => _hardware.deviceModel;

  // ── Lifecycle ─────────────────────────────────────────────────────────

  void _init() {
    _loadDeviceModel();
    updateHardwareMonitoring();
    updatePingMonitoring();
    _hookFlutterErrors();
    MonitorColors.load(); // fire-and-forget: restores persisted theme
  }

  bool _shouldIgnoreError(String exception, String stack) {
    final excLower = exception.toLowerCase();
    final stackLower = stack.toLowerCase();

    if (stackLower.contains('flutter_dev_monitor') ||
        excLower.contains('flutter_dev_monitor')) {
      return true;
    }

    final currentRoute = MonitorNavigatorObserver.currentRoute;
    if (currentRoute.contains('Monitor') || currentRoute.contains('monitor')) {
      return true;
    }

    return false;
  }

  void _hookFlutterErrors() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (_isReportingError) {
        originalOnError?.call(details);
        return;
      }
      _isReportingError = true;
      try {
        final exceptionStr = details.exceptionAsString();
        final stackStr = details.stack?.toString() ?? '';
        if (!_shouldIgnoreError(exceptionStr, stackStr)) {
          _alertsDismissed = false;
          _errorLog.addError(
            exceptionStr,
            stackStr,
            ErrorLogItem.typeFlutter,
            MonitorNavigatorObserver.currentRoute.isEmpty
                ? MonitorConstants.unknownRoute
                : MonitorNavigatorObserver.currentRoute,
          );
          if (!_disposed) {
            scheduleMicrotask(() {
              if (!_disposed) {
                notifyListeners();
              }
            });
          }
        }
      } catch (_) {
      } finally {
        _isReportingError = false;
      }
      originalOnError?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (_isReportingError) {
        return false;
      }
      _isReportingError = true;
      try {
        final exceptionStr = error.toString();
        final stackStr = stack.toString();
        if (!_shouldIgnoreError(exceptionStr, stackStr)) {
          _alertsDismissed = false;
          _errorLog.addError(
            exceptionStr,
            stackStr,
            ErrorLogItem.typeDart,
            MonitorNavigatorObserver.currentRoute.isEmpty
                ? MonitorConstants.unknownRoute
                : MonitorNavigatorObserver.currentRoute,
          );
          if (!_disposed) {
            scheduleMicrotask(() {
              if (!_disposed) {
                notifyListeners();
              }
            });
          }
        }
      } catch (_) {
      } finally {
        _isReportingError = false;
      }
      return false;
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _hardwareTimer?.cancel();
    _pingTimer?.cancel();
    super.dispose();
  }

  // ── Session management ────────────────────────────────────────────────

  void startSession(String screenName) {
    if (screenName.isNotEmpty &&
        screenName != MonitorConstants.dashboardRoute &&
        screenName != MonitorConstants.unknownRoute) {
      final String baseName = screenName.contains('#')
          ? screenName.split('#')[0]
          : screenName;

      // Remove any existing screen that matches the base route or is a sub/parent route.
      // E.g. we want to replace the raw parent route /home with the resolved nested tab /home/home.
      _visitedScreens.removeWhere((s) {
        final String sBase = s.contains('#') ? s.split('#')[0] : s;
        if (sBase == baseName) return true;
        if (baseName.startsWith('$sBase/')) return true;
        if (sBase.startsWith('$baseName/')) return true;
        return false;
      });
      _visitedScreens.add(screenName);
    }
    _apiLog.startSession(screenName);
    notifyListeners();
  }

  void renameActiveSession(String oldScreen, String newScreen) {
    if (oldScreen == newScreen) return;

    final idx = _visitedScreens.indexOf(oldScreen);
    if (idx >= 0) {
      _visitedScreens[idx] = newScreen;
    }

    // Deduplicate the list to ensure all items are unique
    final seen = <String>{};
    _visitedScreens.removeWhere((s) => !seen.add(s));

    _apiLog.renameSession(oldScreen, newScreen);
    _routeLog.renameSession(oldScreen, newScreen);
    _errorLog.renameSession(oldScreen, newScreen);
    notifyListeners();
  }

  void setActivePopup(String popupName) => _apiLog.activePopup = popupName;

  void clearActivePopup(String popupName) {
    if (_apiLog.activePopup == popupName) _apiLog.activePopup = null;
  }

  // ── Log management ────────────────────────────────────────────────────

  void addLog(ApiLogItem item) {
    String screen = item.screen;
    String popupSuffix = '';

    final currentRoute = MonitorNavigatorObserver.currentRoute;
    final currentContent = MonitorNavigatorObserver.currentContentRoute;

    // Reconcile item.screen with the canonical (possibly renamed) session name.
    // The session may have been renamed with a "#Title" suffix AFTER the API
    // request was created (e.g. /PRODDETAIL → /PRODDETAIL#Tạo sản phẩm mới).
    // We use currentContentRoute as the source of truth because it always
    // reflects the CURRENT active visit — not a historical one with the same path.
    final String screenBase =
        screen.contains('#') ? screen.split('#')[0] : screen;
    final String contentBase = currentContent.contains('#')
        ? currentContent.split('#')[0]
        : currentContent;
    if (contentBase == screenBase && currentContent.isNotEmpty) {
      screen = currentContent;
    }

    final isPopupActive = _apiLog.isPopupRoute(screen) ||
        (currentRoute != currentContent &&
            currentRoute != MonitorConstants.unknownRoute &&
            currentRoute != MonitorConstants.dashboardRoute);

    if (isPopupActive) {
      screen = currentContent;
      final activePopupName =
          _apiLog.isPopupRoute(item.screen) ? item.screen : currentRoute;
      final cleanPopup = activePopupName.contains('#')
          ? activePopupName.split('#')[1]
          : activePopupName;
      popupSuffix = ' -> $cleanPopup';
    }

    if (!item.isSuccess || item.isSlow) {
      _alertsDismissed = false;
    }

    _apiLog.addLog(item, screen, popupSuffix);
    notifyListeners();
  }


  void updateDashboardView(String screen) {
    _apiLog.updateView(screen);
    notifyListeners();
  }

  void clearScreenData(String screenName) {
    _apiLog.clearScreen(screenName);
    notifyListeners();
  }

  void clearAll() {
    _apiLog.clearAll();
    _fps.clearAll();
    _hardware.clearAll();
    _errorLog.clearAll();
    _routeLog.clearAll();
    _visitedScreens.clear();
    _alertsDismissed = false;
    notifyListeners();
  }

  void removeVisitedScreen(String screenName) {
    _visitedScreens.remove(screenName);
  }

  void clearErrors() {
    _errorLog.clearAll();
    notifyListeners();
  }

  void clearFlow() {
    _apiLog.clearAll();
    _routeLog.clearAll();
    notifyListeners();
  }

  void clearOverlayHistory() => _fps.clearOverlayHistory();

  // ── FPS ───────────────────────────────────────────────────────────────

  void addOverlaySamples(double fps, double gpuMs, double buildMs) {
    _fps.addOverlaySamples(fps, gpuMs, buildMs);
  }

  void recordJankFrame() => _fps.recordJankFrame();

  void addFpsSample(String screenName, double fps) {
    if (screenName.isEmpty || screenName == MonitorConstants.unknownRoute) {
      return;
    }
    if (screenName != MonitorConstants.dashboardRoute) {
      MonitorNavigatorObserver.currentContentRoute = screenName;
    }
    _fps.addSample(screenName, fps);
  }

  void notifyFpsUpdate(double fps, double buildMs, double gpuMs) {
    _fps.update(fps, buildMs, gpuMs);
    notifyListeners();
  }

  // ── Hardware ──────────────────────────────────────────────────────────

  Future<void> _loadDeviceModel() async {
    _hardware.deviceModel = await _datasource.fetchDeviceModel();
    notifyListeners();
  }

  void updateHardwareMonitoring({bool? visible}) {
    if (visible != null) {
      _isOverlayVisible = visible;
    }
    final shouldMonitor = _isDashboardOpen || _isOverlayVisible;
    if (shouldMonitor) {
      _startHardwareMonitoring();
    } else {
      _stopHardwareMonitoring();
    }
  }

  void _startHardwareMonitoring() {
    if (_hardwareTimer != null) return;
    _fetchHardware();
    _hardwareTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _fetchHardware(),
    );
  }

  void _stopHardwareMonitoring() {
    _hardwareTimer?.cancel();
    _hardwareTimer = null;
  }

  void updatePingMonitoring({bool? visible}) {
    if (visible != null) {
      _isOverlayVisible = visible;
    }
    final shouldPing = _isDashboardOpen || _isOverlayVisible;
    if (shouldPing) {
      _startPingMonitoring();
    } else {
      _stopPingMonitoring();
    }
  }

  void _startPingMonitoring() {
    if (_pingTimer != null) return;
    Future.delayed(const Duration(seconds: 5), () {
      if (_disposed) return;
      final shouldPing = _isDashboardOpen || _isOverlayVisible;
      if (!shouldPing) return;
      _fetchPing();
      _pingTimer =
          Timer.periodic(const Duration(seconds: 20), (_) => _fetchPing());
    });
  }

  void _stopPingMonitoring() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _currentPingMs = null;
    notifyListeners();
  }

  Future<void> _fetchPing() async {
    final ms = await _datasource.measurePing();
    _currentPingMs = ms;
    notifyListeners();
  }

  Future<void> _fetchHardware() async {
    final snapshot = await _datasource.fetch();
    if (snapshot == null) return;
    _hardware.update(snapshot, MonitorNavigatorObserver.currentRoute);
    notifyListeners();
  }
}
