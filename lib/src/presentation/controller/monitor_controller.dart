import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/monitor_constants.dart';
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

class MonitorController extends ChangeNotifier {
  MonitorController._() {
    _init();
  }

  static MonitorController? _instance;

  /// Lazy singleton. Works with any DI: pass [MonitorController.instance] to
  /// Provider, Riverpod, GetX Get.put(), etc.
  static MonitorController get instance => _instance ??= MonitorController._();

  final _apiLog    = ApiLogController();
  final _fps       = FpsController();
  final _hardware  = HardwareController();
  final _errorLog  = ErrorLogController();
  final _routeLog  = RouteLogController();
  final _datasource = HardwareDatasource();

  // All screen names seen this session — never cleared on pop, only on clearAll()
  final Set<String> _visitedScreens = {};

  Timer? _hardwareTimer;
  Timer? _pingTimer;
  int? _currentPingMs;

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
    if (customRouteNames.containsKey(route)) {
      return customRouteNames[route]!;
    }
    if (route == 'ALL') return 'All Screens';
    if (route == '/unknown') return 'Unknown Screen';
    if (route.isEmpty) return '';

    String path = route.startsWith('/') ? route.substring(1) : route;
    final slashIdx = path.indexOf('/');
    String mainPath = slashIdx == -1 ? path : path.substring(0, slashIdx);
    String subPath = slashIdx == -1 ? '' : path.substring(slashIdx);

    // camelCase to spaces
    mainPath = mainPath.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    // underscores/hyphens to spaces
    mainPath = mainPath.replaceAll(RegExp(r'[_-]'), ' ');

    // capitalize words
    mainPath = mainPath.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    if (subPath.isNotEmpty) {
      return '$mainPath ($subPath)';
    }
    return mainPath;
  }

  // ── Expose API log state ──────────────────────────────────────────────

  List<ApiLogItem> get apiLogs => _apiLog.apiLogs;
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

  ({int openCount, int openMs, int visitCount, int actionCount, int actionMs, int actionCycles}) screenStats(
          String screen) =>
      _apiLog.statsForScreen(screen);

  bool get isCurrentScreenInRefresh =>
      _apiLog.isInRefresh(MonitorNavigatorObserver.currentRoute);

  int get currentPhaseApiCount =>
      isCurrentScreenInRefresh ? refreshApiCount : initApiCount;

  // ── Expose FPS state ──────────────────────────────────────────────────

  double get currentFps => _fps.currentFps;
  double get currentBuildMs => _fps.currentBuildMs;
  double get currentGpuMs => _fps.currentGpuMs;
  int get jankFrameCount => _fps.jankFrameCount;
  Map<String, List<double>> get fpsHistoryMap => _fps.fpsHistoryMap;
  List<double> get overlayFpsHistory => _fps.overlayFpsHistory;
  List<double> get overlayGpuHistory => _fps.overlayGpuHistory;
  List<double> get overlayBuildHistory => _fps.overlayBuildHistory;

  // ── Visited screens (never cleared on pop) ───────────────────────────

  Set<String> get visitedScreens => Set.unmodifiable(_visitedScreens);

  // ── Expose error log state ────────────────────────────────────────────

  List<ErrorLogItem> get errorLogs => _errorLog.errors;
  int get flutterErrorCount => _errorLog.count;

  // ── Expose route log state ────────────────────────────────────────────

  List<RouteLogItem> get routeLogs => _routeLog.logs;
  int get routeLogCount => _routeLog.count;

  void logRoutePush(String route, String? from) {
    _routeLog.logPush(route, from);
    notifyListeners();
  }

  void logRoutePop(String route, String? to) {
    _routeLog.logPop(route, to);
    notifyListeners();
  }

  void logRouteReplace(String oldRoute, String newRoute) {
    _routeLog.logReplace(oldRoute, newRoute);
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
    _startHardwareMonitoring();
    _startPingMonitoring();
    _hookFlutterErrors();
    MonitorColors.load(); // fire-and-forget: restores persisted theme
  }

  void _hookFlutterErrors() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _alertsDismissed = false;
      _errorLog.addError(
        details.exceptionAsString(),
        details.stack?.toString() ?? '',
        ErrorLogItem.typeFlutter,
        MonitorNavigatorObserver.currentRoute.isEmpty
            ? '/unknown'
            : MonitorNavigatorObserver.currentRoute,
      );
      notifyListeners();
      originalOnError?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _alertsDismissed = false;
      _errorLog.addError(
        error.toString(),
        stack.toString(),
        ErrorLogItem.typeDart,
        MonitorNavigatorObserver.currentRoute.isEmpty
            ? '/unknown'
            : MonitorNavigatorObserver.currentRoute,
      );
      notifyListeners();
      return false;
    };
  }

  @override
  void dispose() {
    _hardwareTimer?.cancel();
    _pingTimer?.cancel();
    super.dispose();
  }

  // ── Session management ────────────────────────────────────────────────

  void startSession(String screenName) {
    if (screenName.isNotEmpty &&
        screenName != MonitorConstants.dashboardRoute &&
        screenName != MonitorConstants.unknownRoute) {
      _visitedScreens.add(screenName);
    }
    _apiLog.startSession(screenName);
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

    if (_apiLog.isPopupRoute(screen)) {
      screen = MonitorNavigatorObserver.currentContentRoute;
      popupSuffix = ' -> ${_apiLog.activePopup ?? "Popup"}';
    } else {
      MonitorNavigatorObserver.currentContentRoute = screen;
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

  void clearOverlayHistory() => _fps.clearOverlayHistory();

  // ── FPS ───────────────────────────────────────────────────────────────

  void addOverlaySamples(double fps, double gpuMs, double buildMs) {
    _fps.addOverlaySamples(fps, gpuMs, buildMs);
  }

  void recordJankFrame() => _fps.recordJankFrame();

  void addFpsSample(String screenName, double fps) {
    if (screenName.isEmpty || screenName == MonitorConstants.unknownRoute) return;
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

  void _startHardwareMonitoring() {
    _fetchHardware();
    _hardwareTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _fetchHardware(),
    );
  }

  void _startPingMonitoring() {
    _fetchPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchPing());
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
