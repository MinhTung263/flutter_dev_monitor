import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../model/monitor_model.dart';
import '../navigation/monitor_navigator_observer.dart';

class MonitorController extends ChangeNotifier {
  MonitorController._() {
    _loadDeviceModel();
    _startHardwareMonitoring();
  }

  static MonitorController? _instance;

  /// Lazy singleton — created on first access, lives for the app lifetime.
  /// Works with any DI system: just pass [MonitorController.instance] to
  /// Provider, Riverpod, GetX Get.put(), etc.
  static MonitorController get instance => _instance ??= MonitorController._();

  static const _hardwareChannel =
      MethodChannel('flutter_dev_monitor/system_monitor');
  static const int _refreshGapMs = 1500;

  Timer? _hardwareTimer;
  String? _currentActivePopup;

  // ── API log maps (keyed by screen route) ──────────────────────────────
  final Map<String, List<ApiLogItem>> initLogsMap = {};
  final Map<String, List<ApiLogItem>> refreshLogsMap = {};
  final Map<String, int> _orderCounters = {};
  final Map<String, DateTime> _lastApiTime = {};
  final Map<String, bool> _screenInRefreshMode = {};
  final Map<String, int> _refreshCycleCounters = {};

  // ── Observable state (plain fields — notifyListeners() drives UI) ─────
  List<ApiLogItem> apiLogs = [];
  Map<String, List<double>> fpsHistoryMap = {};
  Map<String, List<double>> ramHistoryMap = {};
  double currentFps = 0.0;
  double currentBuildMs = 0.0;
  double currentGpuMs = 0.0;

  // Overlay mini-histories (read on fps change)
  final List<double> overlayFpsHistory = [];
  final List<double> overlayGpuHistory = [];
  final List<double> overlayBuildHistory = [];

  double currentRam = 0.0;
  double totalRam = 4096.0;
  double appDiskUsed = 0.0;
  double totalDisk = 0.0;
  int initApiCount = 0;
  int refreshApiCount = 0;
  int initTotalDuration = 0;
  int refreshTotalDuration = 0;
  int totalRefreshApiCount = 0;
  int totalRefreshDuration = 0;

  int get errorCount => apiLogs.where((l) => l.statusCode != 200).length;

  bool get isCurrentScreenInRefresh {
    final screen = MonitorNavigatorObserver.currentRoute;
    return (_refreshCycleCounters[screen] ?? 0) > 0;
  }

  int get currentPhaseApiCount =>
      isCurrentScreenInRefresh ? refreshApiCount : initApiCount;

  String deviceModel = '';

  // ── Lifecycle ─────────────────────────────────────────────────────────

  @override
  void dispose() {
    _hardwareTimer?.cancel();
    super.dispose();
  }

  // ── Session management ────────────────────────────────────────────────

  void startSession(String screenName) {
    _orderCounters[screenName] = 0;
    _lastApiTime.remove(screenName);
    _screenInRefreshMode[screenName] = false;
    _refreshCycleCounters[screenName] = 0;
    initLogsMap[screenName] = [];
    refreshLogsMap[screenName] = [];
    updateDashboardView(screenName);
  }

  void setActivePopup(String popupName) => _currentActivePopup = popupName;

  void clearActivePopup(String popupName) {
    if (_currentActivePopup == popupName) _currentActivePopup = null;
  }

  // ── Log management ────────────────────────────────────────────────────

  void addLog(ApiLogItem item) {
    String screen = item.screen;
    String popupSuffix = '';

    if (_isPopupRoute(screen)) {
      screen = MonitorNavigatorObserver.currentContentRoute;
      popupSuffix = ' -> ${_currentActivePopup ?? "Popup"}';
    } else {
      MonitorNavigatorObserver.currentContentRoute = screen;
    }

    final now = DateTime.now();
    final lastTime = _lastApiTime[screen];
    final gapExceeded = lastTime != null &&
        now.difference(lastTime).inMilliseconds > _refreshGapMs;

    if (gapExceeded) {
      _orderCounters[screen] = 0;
      _refreshCycleCounters[screen] = (_refreshCycleCounters[screen] ?? 0) + 1;
      _screenInRefreshMode[screen] = true;
    } else if (lastTime == null) {
      _screenInRefreshMode[screen] = false;
      _refreshCycleCounters[screen] = 0;
    }

    _lastApiTime[screen] = now;
    final order = (_orderCounters[screen] ?? 0) + 1;
    _orderCounters[screen] = order;

    final inRefresh = _screenInRefreshMode[screen] == true;
    final newPhase =
        inRefresh ? ApiLogItem.phaseRefresh : ApiLogItem.phaseInit;
    final cycle = _refreshCycleCounters[screen] ?? 0;

    if (inRefresh) {
      final refreshLogs = refreshLogsMap[screen] ??= [];
      final refreshIdx = refreshLogs.indexWhere((l) =>
          l.url == item.url &&
          l.method == item.method &&
          l.refreshCycle == cycle);

      if (refreshIdx >= 0) {
        final existing = refreshLogs[refreshIdx];
        refreshLogs[refreshIdx] = existing.copyWith(
          callCount: existing.callCount + 1,
          duration: item.duration,
          statusCode: item.statusCode,
          orderNumber: order,
        );
      } else {
        refreshLogs.add(ApiLogItem(
          url: item.url,
          method: item.method,
          duration: item.duration,
          statusCode: item.statusCode,
          orderNumber: order,
          timestamp: item.timestamp,
          screen: '$screen$popupSuffix',
          callerName: item.callerName,
          phase: newPhase,
          refreshCycle: cycle,
        ));
      }
    } else {
      final initLogs = initLogsMap[screen] ??= [];
      final initIdx = initLogs
          .indexWhere((l) => l.url == item.url && l.method == item.method);

      if (initIdx >= 0) {
        final existing = initLogs[initIdx];
        initLogs[initIdx] = existing.copyWith(
          callCount: existing.callCount + 1,
          duration: item.duration,
          statusCode: item.statusCode,
          orderNumber: order,
        );
      } else {
        initLogs.add(ApiLogItem(
          url: item.url,
          method: item.method,
          duration: item.duration,
          statusCode: item.statusCode,
          orderNumber: order,
          timestamp: item.timestamp,
          screen: '$screen$popupSuffix',
          callerName: item.callerName,
          phase: newPhase,
          refreshCycle: 0,
        ));
      }
    }

    updateDashboardView(screen);
  }

  void updateDashboardView(String screen) {
    final initLogs = initLogsMap[screen] ?? [];
    final refreshLogs = refreshLogsMap[screen] ?? [];
    final currentCycle = _refreshCycleCounters[screen] ?? 0;

    initApiCount = initLogs.fold(0, (s, l) => s + l.callCount);
    initTotalDuration = initLogs.fold(0, (s, l) => s + l.duration);

    if (currentCycle > 0) {
      final currentCycleLogs =
          refreshLogs.where((l) => l.refreshCycle == currentCycle).toList();
      refreshApiCount = currentCycleLogs.fold(0, (s, l) => s + l.callCount);
      refreshTotalDuration = currentCycleLogs.fold(0, (s, l) => s + l.duration);
      totalRefreshApiCount = refreshLogs.fold(0, (s, l) => s + l.callCount);
      totalRefreshDuration = refreshLogs.fold(0, (s, l) => s + l.duration);
    } else {
      refreshApiCount = 0;
      refreshTotalDuration = 0;
      totalRefreshApiCount = 0;
      totalRefreshDuration = 0;
    }

    // ACTION on top (newest cycle first, easy to observe), INIT at bottom
    final allLogs = [...refreshLogs, ...initLogs]
      ..sort((a, b) {
        if (a.phase != b.phase) {
          return a.phase == ApiLogItem.phaseRefresh ? -1 : 1;
        }
        if (a.refreshCycle != b.refreshCycle) {
          return b.refreshCycle.compareTo(a.refreshCycle);
        }
        return b.orderNumber.compareTo(a.orderNumber);
      });
    apiLogs = allLogs;

    notifyListeners();
  }

  void clearScreenData(String screenName) {
    initLogsMap.remove(screenName);
    refreshLogsMap.remove(screenName);
    _orderCounters.remove(screenName);
    _lastApiTime.remove(screenName);
    _screenInRefreshMode.remove(screenName);
    _refreshCycleCounters.remove(screenName);
    apiLogs = [];
    initApiCount = 0;
    refreshApiCount = 0;
    initTotalDuration = 0;
    refreshTotalDuration = 0;
    totalRefreshApiCount = 0;
    totalRefreshDuration = 0;
    notifyListeners();
  }

  void clearAll() {
    initLogsMap.clear();
    refreshLogsMap.clear();
    apiLogs = [];
    fpsHistoryMap = {};
    ramHistoryMap = {};
    _orderCounters.clear();
    _screenInRefreshMode.clear();
    _refreshCycleCounters.clear();
    _currentActivePopup = null;
    initApiCount = 0;
    refreshApiCount = 0;
    initTotalDuration = 0;
    refreshTotalDuration = 0;
    totalRefreshApiCount = 0;
    totalRefreshDuration = 0;
    notifyListeners();
  }

  void clearOverlayHistory() {
    overlayFpsHistory.clear();
    overlayGpuHistory.clear();
    overlayBuildHistory.clear();
  }

  void clearSessionByAnchor(String anchorName) {
    final screens = MonitorNavigatorObserver.pageToSessionMap.entries
        .where((e) => e.value == anchorName)
        .map((e) => e.key)
        .toList();
    if (!screens.contains(anchorName)) screens.add(anchorName);

    for (final screen in screens) {
      clearScreenData(screen);
      fpsHistoryMap.remove(screen);
      ramHistoryMap.remove(screen);
    }
    notifyListeners();
  }

  // ── FPS ───────────────────────────────────────────────────────────────

  void addOverlaySamples(double fps, double gpuMs, double buildMs) {
    const maxSamples = 60;
    if (fps > 0) {
      overlayFpsHistory.add(fps);
      if (overlayFpsHistory.length > maxSamples) overlayFpsHistory.removeAt(0);
    }
    if (gpuMs > 0) {
      overlayGpuHistory.add(gpuMs);
      if (overlayGpuHistory.length > maxSamples) overlayGpuHistory.removeAt(0);
    }
    if (buildMs > 0) {
      overlayBuildHistory.add(buildMs);
      if (overlayBuildHistory.length > maxSamples) overlayBuildHistory.removeAt(0);
    }
  }

  void addFpsSample(String screenName, double fps) {
    if (screenName.isEmpty || screenName == '/unknown') return;
    if (screenName != '/MonitorDashboardPage') {
      MonitorNavigatorObserver.currentContentRoute = screenName;
    }

    fpsHistoryMap[screenName] ??= [];
    fpsHistoryMap[screenName]!.add(fps);
    if (fpsHistoryMap[screenName]!.length > 150) {
      fpsHistoryMap[screenName]!.removeAt(0);
    }
    // notifyListeners() is intentionally NOT called here — fps ticks at 10Hz
    // and the overlay manages its own refresh via ticker
  }

  void notifyFpsUpdate(double fps, double buildMs, double gpuMs) {
    currentFps = fps;
    currentBuildMs = buildMs;
    currentGpuMs = gpuMs;
    notifyListeners();
  }

  // ── Hardware ──────────────────────────────────────────────────────────

  Future<void> _loadDeviceModel() async {
    deviceModel = await _getDeviceModel();
    notifyListeners();
  }

  static Future<String> _getDeviceModel() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return '${ios.name} • iOS ${ios.systemVersion}';
      } else if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return '${android.brand} ${android.model} • Android ${android.version.release}';
      }
    } catch (_) {}
    return Platform.isIOS ? 'iPhone' : 'Android';
  }

  void _startHardwareMonitoring() {
    _fetchHardwareFromNative();
    _hardwareTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchHardwareFromNative();
    });
  }

  Future<void> _fetchHardwareFromNative() async {
    try {
      final data = await _hardwareChannel
          .invokeMethod<Map<dynamic, dynamic>>('getSystemHardware');
      if (data == null) return;

      currentRam = (data['ramUsed'] as num).toDouble();
      totalRam = (data['ramTotal'] as num).toDouble();
      appDiskUsed = (data['appDiskUsed'] as num).toDouble();
      totalDisk = (data['diskTotal'] as num).toDouble();

      final screen = MonitorNavigatorObserver.currentRoute;
      if (screen == '/MonitorDashboardPage' || screen == '/unknown') {
        notifyListeners();
        return;
      }

      ramHistoryMap[screen] ??= [];
      ramHistoryMap[screen]!.add(currentRam);
      if (ramHistoryMap[screen]!.length > 40) ramHistoryMap[screen]!.removeAt(0);

      notifyListeners();
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  bool _isPopupRoute(String route) =>
      route.contains('dialog') ||
      route.contains('bottomSheet') ||
      _currentActivePopup != null;
}
