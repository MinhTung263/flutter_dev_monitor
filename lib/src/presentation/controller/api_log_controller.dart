import '../../core/monitor_constants.dart';
import '../../domain/api_log_item.dart';

class ApiLogController {
  static const int _maxTrackedScreens = 20;
  static const int _maxLogsPerScreen = 40;

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
  String currentViewedScreen = 'ALL';
  bool isDashboardOpen = false;

  List<ApiLogItem> apiLogs = [];
  int initApiCount = 0;
  int refreshApiCount = 0;
  int initTotalDuration = 0;
  int refreshTotalDuration = 0;
  int totalRefreshApiCount = 0;
  int totalRefreshDuration = 0;

  int get errorCount => apiLogs.where((l) => l.statusCode != 200).length;

  int get globalApiErrorCount {
    int count = 0;
    for (final logs in initLogsMap.values) {
      count += logs.where((l) => !l.isSuccess).length;
    }
    for (final logs in refreshLogsMap.values) {
      count += logs.where((l) => !l.isSuccess).length;
    }
    return count;
  }

  int get globalSlowApiCount {
    int count = 0;
    for (final logs in initLogsMap.values) {
      count += logs.where((l) => l.isSlow).length;
    }
    for (final logs in refreshLogsMap.values) {
      count += logs.where((l) => l.isSlow).length;
    }
    return count;
  }

  bool isInRefresh(String screen) => _screenInRefreshMode[screen] == true;

  DateTime? sessionStartTime(String screen) => _sessionStartTime[screen];

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
        if (refreshLogs.length > _maxLogsPerScreen) {
          refreshLogs.removeAt(0);
        }
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
        if (initLogs.length > _maxLogsPerScreen) {
          initLogs.removeAt(0);
        }
      }
    }

    updateView(currentViewedScreen);
  }

  List<ApiLogItem> _groupDuplicateApis(List<ApiLogItem> rawLogs) {
    final Map<String, ApiLogItem> grouped = {};
    for (final log in rawLogs) {
      final key = '${log.method}_${log.url}';
      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = log;
      } else {
        final isLatest = log.timestamp.isAfter(existing.timestamp);
        grouped[key] = existing.copyWith(
          callCount: existing.callCount + log.callCount,
          duration: isLatest ? log.duration : existing.duration,
          statusCode: isLatest ? log.statusCode : existing.statusCode,
          timestamp: isLatest ? log.timestamp : existing.timestamp,
        );
      }
    }
    return grouped.values.toList();
  }

  void updateView(String screen) {
    currentViewedScreen = screen;
    if (screen == 'ALL') {
      final List<ApiLogItem> allInit = [];
      for (final logs in initLogsMap.values) {
        allInit.addAll(logs);
      }
      final List<ApiLogItem> allRefresh = [];
      for (final logs in refreshLogsMap.values) {
        allRefresh.addAll(logs);
      }

      int totalInitCount = 0;
      int totalInitDuration = 0;
      int totalRefreshCount = 0;
      int totalRefreshDurationMs = 0;
      int totalAllRefreshCount = 0;
      int totalAllRefreshDuration = 0;

      for (final screenName in initLogsMap.keys) {
        final initLogs = initLogsMap[screenName] ?? [];
        final currentInitCycle = _initCycleCounters[screenName] ?? 1;
        final currentInitLogs =
            initLogs.where((l) => l.refreshCycle == currentInitCycle);
        totalInitCount +=
            currentInitLogs.map((l) => '${l.method}_${l.url}').toSet().length;
        totalInitDuration += currentInitLogs.fold(0, (s, l) => s + l.duration);
      }

      for (final screenName in refreshLogsMap.keys) {
        final refreshLogs = refreshLogsMap[screenName] ?? [];
        final currentCycle = _refreshCycleCounters[screenName] ?? 0;
        if (currentCycle > 0) {
          final cycleLogs =
              refreshLogs.where((l) => l.refreshCycle == currentCycle);
          totalRefreshCount +=
              cycleLogs.map((l) => '${l.method}_${l.url}').toSet().length;
          totalRefreshDurationMs += cycleLogs.fold(0, (s, l) => s + l.duration);
        }
        totalAllRefreshCount +=
            refreshLogs.map((l) => '${l.method}_${l.url}').toSet().length;
        totalAllRefreshDuration +=
            refreshLogs.fold(0, (s, l) => s + l.duration);
      }

      initApiCount = totalInitCount;
      initTotalDuration = totalInitDuration;
      refreshApiCount = totalRefreshCount;
      refreshTotalDuration = totalRefreshDurationMs;
      totalRefreshApiCount = totalAllRefreshCount;
      totalRefreshDuration = totalAllRefreshDuration;

      if (!isDashboardOpen) {
        apiLogs = const [];
        return;
      }

      apiLogs = _groupDuplicateApis([...allRefresh, ...allInit])
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return;
    }

    final initLogs = initLogsMap[screen] ?? [];
    final refreshLogs = refreshLogsMap[screen] ?? [];
    final currentCycle = _refreshCycleCounters[screen] ?? 0;
    final currentInitCycle = _initCycleCounters[screen] ?? 1;

    // MetricsBar and overlay show current visit's init stats only.
    final currentInitLogs =
        initLogs.where((l) => l.refreshCycle == currentInitCycle).toList();
    initApiCount =
        currentInitLogs.map((l) => '${l.method}_${l.url}').toSet().length;
    initTotalDuration = currentInitLogs.fold(0, (s, l) => s + l.duration);

    if (currentCycle > 0) {
      final cycleLogs =
          refreshLogs.where((l) => l.refreshCycle == currentCycle).toList();
      refreshApiCount =
          cycleLogs.map((l) => '${l.method}_${l.url}').toSet().length;
      refreshTotalDuration = cycleLogs.fold(0, (s, l) => s + l.duration);
      totalRefreshApiCount =
          refreshLogs.map((l) => '${l.method}_${l.url}').toSet().length;
      totalRefreshDuration = refreshLogs.fold(0, (s, l) => s + l.duration);
    } else {
      refreshApiCount = 0;
      refreshTotalDuration = 0;
      totalRefreshApiCount = 0;
      totalRefreshDuration = 0;
    }

    if (!isDashboardOpen) {
      apiLogs = const [];
      return;
    }

    // Newest call on top, oldest at bottom — pure chronological order.
    apiLogs = _groupDuplicateApis([...refreshLogs, ...initLogs])
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
    currentViewedScreen = 'ALL';
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
    if (screen == 'ALL') {
      int openCount = 0;
      int openMs = 0;
      int actionCount = 0;
      int actionMs = 0;

      for (final screenName in initLogsMap.keys) {
        final initLogs = initLogsMap[screenName] ?? [];
        final currentInitCycle = _initCycleCounters[screenName] ?? 1;
        final currentInitLogs =
            initLogs.where((l) => l.refreshCycle == currentInitCycle).toList();
        openCount += currentInitLogs.fold(0, (s, l) => s + l.callCount);
        openMs += currentInitLogs.fold(0, (s, l) => s + l.duration);
      }

      for (final screenName in refreshLogsMap.keys) {
        final refreshLogs = refreshLogsMap[screenName] ?? [];
        final actionCycles = _refreshCycleCounters[screenName] ?? 0;
        final latestActionLogs = actionCycles > 0
            ? refreshLogs.where((l) => l.refreshCycle == actionCycles).toList()
            : <ApiLogItem>[];
        actionCount += latestActionLogs.fold(0, (s, l) => s + l.callCount);
        actionMs += latestActionLogs.fold(0, (s, l) => s + l.duration);
      }

      return (
        openCount: openCount,
        openMs: openMs,
        visitCount: 0,
        actionCount: actionCount,
        actionMs: actionMs,
        actionCycles: 0,
      );
    }

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

  List<ApiLogItem> get globalApiLogs {
    final List<ApiLogItem> allInit = [];
    for (final logs in initLogsMap.values) {
      allInit.addAll(logs);
    }
    final List<ApiLogItem> allRefresh = [];
    for (final logs in refreshLogsMap.values) {
      allRefresh.addAll(logs);
    }
    return [...allRefresh, ...allInit]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
}
