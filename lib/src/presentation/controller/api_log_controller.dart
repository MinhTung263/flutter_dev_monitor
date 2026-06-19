import '../../core/monitor_constants.dart';
import '../../domain/api_log_item.dart';

class ApiLogController {
  static const int _maxTrackedScreens = 50;

  final Map<String, List<ApiLogItem>> initLogsMap = {};
  final Map<String, List<ApiLogItem>> refreshLogsMap = {};
  final Map<String, int> _orderCounters = {};
  final Map<String, DateTime> _lastApiTime = {};
  final Map<String, bool> _screenInRefreshMode = {};
  final Map<String, int> _refreshCycleCounters = {};
  final Map<String, int> _initCycleCounters = {};
  final Map<String, DateTime> _sessionStartTime = {};
  final List<String> _screenOrder = [];

  String? activePopup;

  List<ApiLogItem> apiLogs = [];
  int initApiCount = 0;
  int refreshApiCount = 0;
  int initTotalDuration = 0;
  int refreshTotalDuration = 0;
  int totalRefreshApiCount = 0;
  int totalRefreshDuration = 0;

  int get errorCount => apiLogs.where((l) => l.statusCode != 200).length;

  bool isInRefresh(String screen) => _screenInRefreshMode[screen] == true;

  void startSession(String screenName) {
    if (!initLogsMap.containsKey(screenName)) {
      _screenOrder.add(screenName);
      if (_screenOrder.length > _maxTrackedScreens) {
        _evict(_screenOrder.removeAt(0));
      }
    }
    // Reset timing on every entry; each visit gets its own init cycle so
    // new init APIs are added as fresh entries rather than merged with prior visits.
    _lastApiTime.remove(screenName);
    _sessionStartTime[screenName] = DateTime.now();
    _screenInRefreshMode[screenName] = false;
    _orderCounters[screenName] = 0;
    _initCycleCounters[screenName] = (_initCycleCounters[screenName] ?? 0) + 1;
    _refreshCycleCounters.putIfAbsent(screenName, () => 0);
    initLogsMap.putIfAbsent(screenName, () => []);
    refreshLogsMap.putIfAbsent(screenName, () => []);
    updateView(screenName);
  }

  void _evict(String screenName) {
    initLogsMap.remove(screenName);
    refreshLogsMap.remove(screenName);
    _orderCounters.remove(screenName);
    _lastApiTime.remove(screenName);
    _screenInRefreshMode.remove(screenName);
    _refreshCycleCounters.remove(screenName);
    _initCycleCounters.remove(screenName);
    _sessionStartTime.remove(screenName);
  }

  void addLog(ApiLogItem item, String screen, String popupSuffix) {
    final reqStart = item.timestamp.subtract(Duration(milliseconds: item.duration));
    final lastStart = _lastApiTime[screen];
    final gapExceeded = lastStart != null &&
        reqStart.difference(lastStart).inMilliseconds > MonitorConstants.refreshGapMs;

    if (gapExceeded) {
      _orderCounters[screen] = 0;
      _refreshCycleCounters[screen] = (_refreshCycleCounters[screen] ?? 0) + 1;
      _screenInRefreshMode[screen] = true;
    } else if (lastStart == null) {
      // First API after screen entry. If user waited longer than the gap before
      // triggering it (e.g. pressed a button after reading the screen), treat
      // it as ACTION rather than OPEN.
      final sessionStart = _sessionStartTime[screen];
      final delayedAction = sessionStart != null &&
          reqStart.difference(sessionStart).inMilliseconds >
              MonitorConstants.refreshGapMs;
      if (delayedAction) {
        _orderCounters[screen] = 0;
        _refreshCycleCounters[screen] =
            (_refreshCycleCounters[screen] ?? 0) + 1;
        _screenInRefreshMode[screen] = true;
      } else {
        _screenInRefreshMode[screen] = false;
      }
    }

    _lastApiTime[screen] = reqStart;
    final order = (_orderCounters[screen] ?? 0) + 1;
    _orderCounters[screen] = order;

    final inRefresh = _screenInRefreshMode[screen] == true;
    final newPhase = inRefresh ? ApiLogItem.phaseRefresh : ApiLogItem.phaseInit;
    final cycle = _refreshCycleCounters[screen] ?? 0;
    final screenLabel = '$screen$popupSuffix';

    if (inRefresh) {
      final refreshLogs = refreshLogsMap[screen] ??= [];
      final idx = refreshLogs.indexWhere((l) =>
          l.url == item.url &&
          l.method == item.method &&
          l.refreshCycle == cycle);

      if (idx >= 0) {
        final existing = refreshLogs[idx];
        refreshLogs[idx] = existing.copyWith(
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
          screen: screenLabel,
          callerName: item.callerName,
          phase: newPhase,
          refreshCycle: cycle,
          responseBytes: item.responseBytes,
          queryParams: item.queryParams,
          requestHeaders: item.requestHeaders,
          requestBody: item.requestBody,
          responseHeaders: item.responseHeaders,
          responseBody: item.responseBody,
        ));
      }
    } else {
      final initLogs = initLogsMap[screen] ??= [];
      final initCycle = _initCycleCounters[screen] ?? 1;
      // Dedup within the same visit only (same URL+method+initCycle).
      final idx = initLogs.indexWhere((l) =>
          l.url == item.url &&
          l.method == item.method &&
          l.refreshCycle == initCycle);

      if (idx >= 0) {
        final existing = initLogs[idx];
        initLogs[idx] = existing.copyWith(
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
          screen: screenLabel,
          callerName: item.callerName,
          phase: newPhase,
          refreshCycle: initCycle,
          responseBytes: item.responseBytes,
          queryParams: item.queryParams,
          requestHeaders: item.requestHeaders,
          requestBody: item.requestBody,
          responseHeaders: item.responseHeaders,
          responseBody: item.responseBody,
        ));
      }
    }

    updateView(screen);
  }

  void updateView(String screen) {
    final initLogs = initLogsMap[screen] ?? [];
    final refreshLogs = refreshLogsMap[screen] ?? [];
    final currentCycle = _refreshCycleCounters[screen] ?? 0;
    final currentInitCycle = _initCycleCounters[screen] ?? 1;

    // MetricsBar and overlay show current visit's init stats only.
    final currentInitLogs =
        initLogs.where((l) => l.refreshCycle == currentInitCycle).toList();
    initApiCount = currentInitLogs.fold(0, (s, l) => s + l.callCount);
    initTotalDuration = currentInitLogs.fold(0, (s, l) => s + l.duration);

    if (currentCycle > 0) {
      final cycleLogs =
          refreshLogs.where((l) => l.refreshCycle == currentCycle).toList();
      refreshApiCount = cycleLogs.fold(0, (s, l) => s + l.callCount);
      refreshTotalDuration = cycleLogs.fold(0, (s, l) => s + l.duration);
      totalRefreshApiCount = refreshLogs.fold(0, (s, l) => s + l.callCount);
      totalRefreshDuration = refreshLogs.fold(0, (s, l) => s + l.duration);
    } else {
      refreshApiCount = 0;
      refreshTotalDuration = 0;
      totalRefreshApiCount = 0;
      totalRefreshDuration = 0;
    }

    // Newest call on top, oldest at bottom — pure chronological order.
    apiLogs = [...refreshLogs, ...initLogs]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  void clearScreen(String screenName) {
    _screenOrder.remove(screenName);
    _evict(screenName);
    apiLogs = [];
    initApiCount = 0;
    refreshApiCount = 0;
    initTotalDuration = 0;
    refreshTotalDuration = 0;
    totalRefreshApiCount = 0;
    totalRefreshDuration = 0;
  }

  void clearAll() {
    initLogsMap.clear();
    refreshLogsMap.clear();
    apiLogs = [];
    _orderCounters.clear();
    _lastApiTime.clear();
    _screenInRefreshMode.clear();
    _refreshCycleCounters.clear();
    _initCycleCounters.clear();
    _sessionStartTime.clear();
    _screenOrder.clear();
    activePopup = null;
    initApiCount = 0;
    refreshApiCount = 0;
    initTotalDuration = 0;
    refreshTotalDuration = 0;
    totalRefreshApiCount = 0;
    totalRefreshDuration = 0;
  }

  /// Returns live stats for a given screen without mutating shared state.
  /// Used by the dashboard MetricsBar so it always reflects the selected screen.
  ({
    int openCount,
    int openMs,
    int visitCount,
    int actionCount,
    int actionMs,
    int actionCycles,
  }) statsForScreen(String screen) {
    final initLogs = initLogsMap[screen] ?? [];
    final refreshLogs = refreshLogsMap[screen] ?? [];
    final currentInitCycle = _initCycleCounters[screen] ?? 1;
    final actionCycles = _refreshCycleCounters[screen] ?? 0;

    // OPEN: latest visit only
    final currentInitLogs =
        initLogs.where((l) => l.refreshCycle == currentInitCycle).toList();
    final openCount = currentInitLogs.fold(0, (s, l) => s + l.callCount);
    final openMs = currentInitLogs.fold(0, (s, l) => s + l.duration);

    // ACTION: latest cycle only (consistent with OPEN showing latest visit)
    final latestActionLogs = actionCycles > 0
        ? refreshLogs.where((l) => l.refreshCycle == actionCycles).toList()
        : <ApiLogItem>[];
    final actionCount = latestActionLogs.fold(0, (s, l) => s + l.callCount);
    final actionMs = latestActionLogs.fold(0, (s, l) => s + l.duration);

    return (
      openCount: openCount,
      openMs: openMs,
      visitCount: currentInitCycle,
      actionCount: actionCount,
      actionMs: actionMs,
      actionCycles: actionCycles,
    );
  }

  bool isPopupRoute(String route) =>
      route.contains('dialog') ||
      route.contains('bottomSheet') ||
      activePopup != null;
}
