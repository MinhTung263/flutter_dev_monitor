import '../../core/monitor_constants.dart';
import '../../domain/api_log_item.dart';

class ApiLogController {
  final Map<String, List<ApiLogItem>> initLogsMap = {};
  final Map<String, List<ApiLogItem>> refreshLogsMap = {};
  final Map<String, int> _orderCounters = {};
  final Map<String, DateTime> _lastApiTime = {};
  final Map<String, bool> _screenInRefreshMode = {};
  final Map<String, int> _refreshCycleCounters = {};

  String? activePopup;

  List<ApiLogItem> apiLogs = [];
  int initApiCount = 0;
  int refreshApiCount = 0;
  int initTotalDuration = 0;
  int refreshTotalDuration = 0;
  int totalRefreshApiCount = 0;
  int totalRefreshDuration = 0;

  int get errorCount => apiLogs.where((l) => l.statusCode != 200).length;

  bool isInRefresh(String screen) => (_refreshCycleCounters[screen] ?? 0) > 0;

  void startSession(String screenName) {
    _orderCounters[screenName] = 0;
    _lastApiTime.remove(screenName);
    _screenInRefreshMode[screenName] = false;
    _refreshCycleCounters[screenName] = 0;
    initLogsMap[screenName] = [];
    refreshLogsMap[screenName] = [];
    updateView(screenName);
  }

  void addLog(ApiLogItem item, String screen, String popupSuffix) {
    final now = DateTime.now();
    final lastTime = _lastApiTime[screen];
    final gapExceeded = lastTime != null &&
        now.difference(lastTime).inMilliseconds > MonitorConstants.refreshGapMs;

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
    final newPhase = inRefresh ? ApiLogItem.phaseRefresh : ApiLogItem.phaseInit;
    final cycle = _refreshCycleCounters[screen] ?? 0;
    final screenLabel = '$screen$popupSuffix';

    if (inRefresh) {
      final refreshLogs = refreshLogsMap[screen] ??= [];
      final idx = refreshLogs.indexWhere((l) =>
          l.url == item.url && l.method == item.method && l.refreshCycle == cycle);

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
        ));
      }
    } else {
      final initLogs = initLogsMap[screen] ??= [];
      final idx = initLogs
          .indexWhere((l) => l.url == item.url && l.method == item.method);

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
          refreshCycle: 0,
        ));
      }
    }

    updateView(screen);
  }

  void updateView(String screen) {
    final initLogs = initLogsMap[screen] ?? [];
    final refreshLogs = refreshLogsMap[screen] ?? [];
    final currentCycle = _refreshCycleCounters[screen] ?? 0;

    initApiCount = initLogs.fold(0, (s, l) => s + l.callCount);
    initTotalDuration = initLogs.fold(0, (s, l) => s + l.duration);

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

    // ACTION on top (newest cycle first), INIT at bottom
    apiLogs = [...refreshLogs, ...initLogs]
      ..sort((a, b) {
        if (a.phase != b.phase) {
          return a.phase == ApiLogItem.phaseRefresh ? -1 : 1;
        }
        if (a.refreshCycle != b.refreshCycle) {
          return b.refreshCycle.compareTo(a.refreshCycle);
        }
        return b.orderNumber.compareTo(a.orderNumber);
      });
  }

  void clearScreen(String screenName) {
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
  }

  void clearAll() {
    initLogsMap.clear();
    refreshLogsMap.clear();
    apiLogs = [];
    _orderCounters.clear();
    _screenInRefreshMode.clear();
    _refreshCycleCounters.clear();
    activePopup = null;
    initApiCount = 0;
    refreshApiCount = 0;
    initTotalDuration = 0;
    refreshTotalDuration = 0;
    totalRefreshApiCount = 0;
    totalRefreshDuration = 0;
  }

  bool isPopupRoute(String route) =>
      route.contains('dialog') ||
      route.contains('bottomSheet') ||
      activePopup != null;
}
