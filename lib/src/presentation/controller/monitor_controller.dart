import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/monitor_constants.dart';
import '../ui/theme/monitor_theme.dart';
import '../../data/hardware_datasource.dart';
import '../../domain/api_log_item.dart';
import '../../domain/error_log_item.dart';
import '../navigation/monitor_navigator_observer.dart';
import 'api_log_controller.dart';
import 'error_log_controller.dart';
import 'fps_controller.dart';
import 'hardware_controller.dart';

class MonitorController extends ChangeNotifier {
  MonitorController._() {
    _init();
  }

  static MonitorController? _instance;

  /// Lazy singleton. Works with any DI: pass [MonitorController.instance] to
  /// Provider, Riverpod, GetX Get.put(), etc.
  static MonitorController get instance => _instance ??= MonitorController._();

  final _apiLog = ApiLogController();
  final _fps = FpsController();
  final _hardware = HardwareController();
  final _errorLog = ErrorLogController();
  final _datasource = HardwareDatasource();

  Timer? _hardwareTimer;

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

  // ── Expose error log state ────────────────────────────────────────────

  List<ErrorLogItem> get errorLogs => _errorLog.errors;
  int get flutterErrorCount => _errorLog.count;

  // ── Expose hardware state ─────────────────────────────────────────────

  double get currentRam => _hardware.currentRam;
  double get totalRam => _hardware.totalRam;
  double get appDiskUsed => _hardware.appDiskUsed;
  double get totalDisk => _hardware.totalDisk;
  Map<String, List<double>> get ramHistoryMap => _hardware.ramHistoryMap;
  String get deviceModel => _hardware.deviceModel;

  // ── Lifecycle ─────────────────────────────────────────────────────────

  void _init() {
    _loadDeviceModel();
    _startHardwareMonitoring();
    _hookFlutterErrors();
    MonitorColors.load(); // fire-and-forget: restores persisted theme
  }

  void _hookFlutterErrors() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _errorLog.addError(
        details.exceptionAsString(),
        details.stack?.toString() ?? '',
        ErrorLogItem.typeFlutter,
      );
      notifyListeners();
      originalOnError?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _errorLog.addError(
        error.toString(),
        stack.toString(),
        ErrorLogItem.typeDart,
      );
      notifyListeners();
      return false;
    };
  }

  @override
  void dispose() {
    _hardwareTimer?.cancel();
    super.dispose();
  }

  // ── Session management ────────────────────────────────────────────────

  void startSession(String screenName) {
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
    notifyListeners();
  }

  void clearOverlayHistory() => _fps.clearOverlayHistory();

  void clearSessionByAnchor(String anchorName) {
    final screens = MonitorNavigatorObserver.pageToSessionMap.entries
        .where((e) => e.value == anchorName)
        .map((e) => e.key)
        .toList();
    if (!screens.contains(anchorName)) screens.add(anchorName);

    for (final screen in screens) {
      _apiLog.clearScreen(screen);
      _fps.clearScreen(screen);
      _hardware.clearScreen(screen);
    }
    notifyListeners();
  }

  // ── FPS ───────────────────────────────────────────────────────────────

  void addOverlaySamples(double fps, double gpuMs, double buildMs) {
    _fps.addOverlaySamples(fps, gpuMs, buildMs);
  }

  void recordJankFrame() => _fps.recordJankFrame();

  void addFpsSample(String screenName, double fps) {
    if (screenName.isEmpty || screenName == MonitorConstants.unknownRoute)
      return;
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

  Future<void> _fetchHardware() async {
    final snapshot = await _datasource.fetch();
    if (snapshot == null) return;
    _hardware.update(snapshot, MonitorNavigatorObserver.currentRoute);
    notifyListeners();
  }
}
