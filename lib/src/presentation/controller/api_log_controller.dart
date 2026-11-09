import '../../core/monitor_constants.dart';
import '../../domain/api_log_item.dart';

class ApiLogController {
  /// Chế độ gọn (DevMonitor đang ẩn — bản prod/staging): giữ ít màn/log hơn
  /// cho nhẹ RAM. Đặt bởi MonitorController theo `isMonitoringActive`.
  bool compact = false;

  int get _maxTrackedScreens => compact ? 20 : 100;
  int get _maxLogsPerScreen => compact ? 30 : 100;

  final Map<String, List<ApiLogItem>> initLogsMap = {};
  final Map<String, List<ApiLogItem>> refreshLogsMap = {};

  final Map<String, DateTime> _lastApiTime = {};
  final Map<String, DateTime> _lastLoadActivityTime = {};
  final Map<String, DateTime> _lastRefreshActivityTime = {};
  final Map<String, int> _inFlightLoadCount = {};
  final Map<String, int> _inFlightRefreshCount = {};
  final Map<String, bool> _userInteractedAfterLoad = {};
  final Map<String, bool> _userInteractedSinceLastApi = {};
  final Map<String, bool> _screenInRefreshMode = {};
  final Map<String, int> _refreshCycleCounters = {};
  final Map<String, int> _initCycleCounters = {};
  final Map<String, DateTime> _sessionStartTime = {};
  final List<String> _screenOrder = [];
  String? _activeScreen;

  String? activePopup;
  String currentViewedScreen = MonitorConstants.allScreensKey;
  bool isDashboardOpen = false;

  List<ApiLogItem> apiLogs = [];
  int initApiCount = 0;
  int refreshApiCount = 0;
  int initTotalDuration = 0;
  int refreshTotalDuration = 0;
  int totalRefreshApiCount = 0;
  int totalRefreshDuration = 0;

  int get errorCount => apiLogs.where((l) => !l.isSuccess).length;

  int? _cachedGlobalApiErrorCount;
  int? _cachedGlobalSlowApiCount;

  void _invalidateGlobalCounts() {
    _cachedGlobalApiErrorCount = null;
    _cachedGlobalSlowApiCount = null;
  }

  int get globalApiErrorCount {
    if (_cachedGlobalApiErrorCount != null) return _cachedGlobalApiErrorCount!;
    int count = 0;
    for (final logs in initLogsMap.values) {
      for (final l in logs) {
        if (!l.isSuccess) count++;
      }
    }
    for (final logs in refreshLogsMap.values) {
      for (final l in logs) {
        if (!l.isSuccess) count++;
      }
    }
    return _cachedGlobalApiErrorCount = count;
  }

  int get globalSlowApiCount {
    if (_cachedGlobalSlowApiCount != null) return _cachedGlobalSlowApiCount!;
    int count = 0;
    for (final logs in initLogsMap.values) {
      for (final l in logs) {
        if (l.isSlow) count++;
      }
    }
    for (final logs in refreshLogsMap.values) {
      for (final l in logs) {
        if (l.isSlow) count++;
      }
    }
    return _cachedGlobalSlowApiCount = count;
  }

  bool isInRefresh(String screen) {
    if (_screenInRefreshMode[screen] == true) return true;
    final String cleanScreen = _baseRoute(screen);
    for (final entry in _screenInRefreshMode.entries) {
      if (_baseRoute(entry.key) == cleanScreen && entry.value == true) {
        return true;
      }
    }
    return false;
  }

  static String _baseRoute(String screen) =>
      screen.contains('#') ? screen.split('#').first : screen;

  DateTime? sessionStartTime(String screen) =>
      _sessionStartTime[_resolveCanonicalScreen(screen)];

  /// Records a user pointer-down interaction on [rawScreen].
  /// Ignored during the first 300ms of a screen session so the navigation tap
  /// that opened the screen is never treated as a post-load interaction.
  void onUserPointerDown(String rawScreen) {
    if (isDashboardOpen) return;
    final screen = _resolveCanonicalScreen(rawScreen);
    if (screen.isEmpty ||
        screen == MonitorConstants.allScreensKey ||
        screen == MonitorConstants.unknownRoute) {
      return;
    }
    final now = DateTime.now();
    final sessionStart = _sessionStartTime[screen];
    if (sessionStart != null &&
        now.difference(sessionStart).inMilliseconds <= 300) {
      return;
    }
    _userInteractedAfterLoad[screen] = true;
    _userInteractedSinceLastApi[screen] = true;
  }

  /// Classifies an outgoing API request at the moment it starts (`onRequest`),
  /// returning the canonical `(phase, cycle, screen)` for accurate LOAD vs
  /// INTERACTION attribution even when multiple async batches are chained.
  ({String phase, int cycle, String screen}) onRequestStart(
    String rawScreen, {
    bool isPopupActive = false,
  }) {
    final screen = _resolveCanonicalScreen(rawScreen);
    final now = DateTime.now();

    final bool shouldBeRefresh = _evaluateShouldBeRefresh(
      screen,
      now,
      isPopupActive: isPopupActive,
    );

    if (shouldBeRefresh) {
      final bool wasInRefresh = _screenInRefreshMode[screen] == true;
      final lastStart = _lastApiTime[screen];
      final lastRefreshEnd = _lastRefreshActivityTime[screen] ?? lastStart;
      final int inFlightRefresh = _inFlightRefreshCount[screen] ?? 0;
      final bool gapExceeded = lastRefreshEnd != null &&
          now.difference(lastRefreshEnd).inMilliseconds >
              MonitorConstants.refreshGapMs;
      final bool userTapped = _userInteractedSinceLastApi[screen] == true &&
          inFlightRefresh == 0 &&
          (lastRefreshEnd == null ||
              now.difference(lastRefreshEnd).inMilliseconds > 250);

      if (!wasInRefresh ||
          (inFlightRefresh == 0 && gapExceeded) ||
          userTapped ||
          (_refreshCycleCounters[screen] ?? 0) == 0) {
        _refreshCycleCounters[screen] =
            (_refreshCycleCounters[screen] ?? 0) + 1;
      }
      _screenInRefreshMode[screen] = true;
      _userInteractedSinceLastApi[screen] = false;
      _inFlightRefreshCount[screen] = inFlightRefresh + 1;
      _lastRefreshActivityTime[screen] = now;
      _lastApiTime[screen] = now;
      return (
        phase: ApiLogItem.phaseRefresh,
        cycle: _refreshCycleCounters[screen] ?? 1,
        screen: screen,
      );
    } else {
      _screenInRefreshMode[screen] = false;
      final int initCycle = _initCycleCounters[screen] ??= 1;
      _inFlightLoadCount[screen] = (_inFlightLoadCount[screen] ?? 0) + 1;
      _lastLoadActivityTime[screen] = now;
      _lastApiTime[screen] = now;
      return (
        phase: ApiLogItem.phaseInit,
        cycle: initCycle,
        screen: screen,
      );
    }
  }

  bool _evaluateShouldBeRefresh(
    String screen,
    DateTime reqStart, {
    bool isPopupActive = false,
  }) {
    if (isPopupActive) return true;
    if (_screenInRefreshMode[screen] == true) return true;
    if (_userInteractedAfterLoad[screen] == true) return true;

    final int inFlightLoad = _inFlightLoadCount[screen] ?? 0;
    if (inFlightLoad > 0) {
      // Initial load requests are still in-flight and the user has not
      // interacted with the screen — this request is part of initial LOAD.
      return false;
    }

    final DateTime? lastLoadActivity =
        _lastLoadActivityTime[screen] ?? _sessionStartTime[screen];
    if (lastLoadActivity != null) {
      final int idleMs = reqStart.difference(lastLoadActivity).inMilliseconds;
      if (idleMs > MonitorConstants.refreshGapMs) {
        return true;
      }
    }
    return false;
  }

  void startSession(String screenName) {
    final String base = _baseRoute(screenName);
    // Unify any existing session that has the exact same base route
    // (e.g. '/page_builder/order_view#Đơn hàng' vs '/page_builder/order_view#Lịch sử đơn hàng')
    // so logs for the same screen are never split across two keys!
    if (base.isNotEmpty &&
        screenName != MonitorConstants.allScreensKey &&
        screenName != MonitorConstants.unknownRoute) {
      final existingKeys = _screenOrder
          .where((k) => k != screenName && _baseRoute(k) == base)
          .toList();
      for (final oldKey in existingKeys) {
        renameSession(oldKey, screenName);
      }
    }

    if (!initLogsMap.containsKey(screenName)) {
      _screenOrder.add(screenName);
      if (_screenOrder.length > _maxTrackedScreens) {
        _evict(_screenOrder.removeAt(0));
      }
    }

    final now = DateTime.now();
    final prevStart = _sessionStartTime[screenName];
    final bool isSameActiveVisit = _activeScreen != null &&
        _baseRoute(_activeScreen!) == base &&
        prevStart != null &&
        now.difference(prevStart).inMilliseconds < 250;

    _activeScreen = screenName;

    if (isSameActiveVisit) {
      initLogsMap.putIfAbsent(screenName, () => []);
      refreshLogsMap.putIfAbsent(screenName, () => []);
      _refreshCycleCounters.putIfAbsent(screenName, () => 0);
      updateView(screenName);
      return;
    }

    final int newInitCycle = (_initCycleCounters[screenName] ?? 0) + 1;
    _initCycleCounters[screenName] = newInitCycle;

    // Preserve any API logs that fired synchronously (< 250ms ago) during the
    // tab/route transition into this screen, while clearing logs from older visits
    // so LOAD and INTERACTION measure this visit accurately.
    final List<ApiLogItem> carryOverInitLogs = [];
    final existingInit = initLogsMap[screenName];
    if (existingInit != null) {
      for (final l in existingInit) {
        if (now.difference(l.timestamp).inMilliseconds.abs() <= 250) {
          carryOverInitLogs.add(l.copyWith(
            screen: screenName,
            phase: ApiLogItem.phaseInit,
            refreshCycle: newInitCycle,
          ));
        }
      }
    }
    final existingRefresh = refreshLogsMap[screenName];
    if (existingRefresh != null) {
      for (final l in existingRefresh) {
        if (now.difference(l.timestamp).inMilliseconds.abs() <= 250) {
          carryOverInitLogs.add(l.copyWith(
            screen: screenName,
            phase: ApiLogItem.phaseInit,
            refreshCycle: newInitCycle,
          ));
        }
      }
    }

    initLogsMap[screenName] = carryOverInitLogs;
    refreshLogsMap[screenName] = [];
    _refreshCycleCounters[screenName] = 0;
    _lastApiTime.remove(screenName);
    _lastRefreshActivityTime.remove(screenName);
    _inFlightRefreshCount[screenName] = 0;
    _sessionStartTime[screenName] = now;
    _lastLoadActivityTime[screenName] = now;
    _screenInRefreshMode[screenName] = false;
    _userInteractedAfterLoad[screenName] = false;
    _userInteractedSinceLastApi[screenName] = false;
    _inFlightLoadCount.putIfAbsent(screenName, () => 0);

    _invalidateGlobalCounts();
    updateView(screenName);
  }

  void _evict(String screenName) {
    initLogsMap.remove(screenName);
    refreshLogsMap.remove(screenName);
    _lastApiTime.remove(screenName);
    _lastLoadActivityTime.remove(screenName);
    _lastRefreshActivityTime.remove(screenName);
    _inFlightLoadCount.remove(screenName);
    _inFlightRefreshCount.remove(screenName);
    _userInteractedAfterLoad.remove(screenName);
    _userInteractedSinceLastApi.remove(screenName);
    _screenInRefreshMode.remove(screenName);
    _refreshCycleCounters.remove(screenName);
    _initCycleCounters.remove(screenName);
    _sessionStartTime.remove(screenName);
    _invalidateGlobalCounts();
  }

  void renameSession(String oldScreen, String newScreen) {
    if (oldScreen == newScreen) return;

    final String oldBase = _baseRoute(oldScreen);
    final String newBase = _baseRoute(newScreen);

    // Collect all source keys to migrate into newScreen.
    final Set<String> sources = {oldScreen};
    if (oldBase.isNotEmpty && oldBase == newBase) {
      for (final k in _screenOrder) {
        if (k != newScreen && _baseRoute(k) == newBase) sources.add(k);
      }
      for (final k in initLogsMap.keys) {
        if (k != newScreen && _baseRoute(k) == newBase) sources.add(k);
      }
      for (final k in refreshLogsMap.keys) {
        if (k != newScreen && _baseRoute(k) == newBase) sources.add(k);
      }
    }

    for (final src in sources) {
      if (src == newScreen) continue;
      _migrateSingleSession(src, newScreen);
    }

    _invalidateGlobalCounts();
    updateView(currentViewedScreen);
  }

  void _migrateSingleSession(String oldScreen, String newScreen) {
    final int existingInitCycle = _initCycleCounters[newScreen] ?? 0;
    final int oldInitCycle = _initCycleCounters.remove(oldScreen) ?? 1;
    final int targetInitCycle =
        existingInitCycle > 0 ? existingInitCycle : oldInitCycle;
    _initCycleCounters[newScreen] = targetInitCycle;

    final int existingRefreshCycle = _refreshCycleCounters[newScreen] ?? 0;
    final int oldRefreshCycle = _refreshCycleCounters.remove(oldScreen) ?? 0;
    final int targetRefreshCycle = existingRefreshCycle > oldRefreshCycle
        ? existingRefreshCycle
        : oldRefreshCycle;
    _refreshCycleCounters[newScreen] = targetRefreshCycle;

    if (initLogsMap.containsKey(oldScreen)) {
      final logs = initLogsMap.remove(oldScreen) ?? [];
      final updatedLogs = logs
          .map((l) => l.copyWith(
                screen: newScreen,
                refreshCycle: targetInitCycle,
              ))
          .toList();
      final existing = initLogsMap[newScreen];
      if (existing != null && existing.isNotEmpty) {
        existing.addAll(updatedLogs);
        if (existing.length > _maxLogsPerScreen) {
          existing.removeRange(0, existing.length - _maxLogsPerScreen);
        }
      } else {
        initLogsMap[newScreen] = updatedLogs;
      }
    }
    if (refreshLogsMap.containsKey(oldScreen)) {
      final logs = refreshLogsMap.remove(oldScreen) ?? [];
      final updatedLogs =
          logs.map((l) => l.copyWith(screen: newScreen)).toList();
      final existing = refreshLogsMap[newScreen];
      if (existing != null && existing.isNotEmpty) {
        existing.addAll(updatedLogs);
        if (existing.length > _maxLogsPerScreen) {
          existing.removeRange(0, existing.length - _maxLogsPerScreen);
        }
      } else {
        refreshLogsMap[newScreen] = updatedLogs;
      }
    }
    if (_lastApiTime.containsKey(oldScreen)) {
      _lastApiTime[newScreen] = _lastApiTime.remove(oldScreen)!;
    }
    if (_lastLoadActivityTime.containsKey(oldScreen)) {
      _lastLoadActivityTime[newScreen] =
          _lastLoadActivityTime.remove(oldScreen)!;
    }
    if (_lastRefreshActivityTime.containsKey(oldScreen)) {
      _lastRefreshActivityTime[newScreen] =
          _lastRefreshActivityTime.remove(oldScreen)!;
    }
    if (_inFlightLoadCount.containsKey(oldScreen)) {
      _inFlightLoadCount[newScreen] = (_inFlightLoadCount[newScreen] ?? 0) +
          (_inFlightLoadCount.remove(oldScreen) ?? 0);
    }
    if (_inFlightRefreshCount.containsKey(oldScreen)) {
      _inFlightRefreshCount[newScreen] =
          (_inFlightRefreshCount[newScreen] ?? 0) +
              (_inFlightRefreshCount.remove(oldScreen) ?? 0);
    }
    if (_userInteractedAfterLoad.containsKey(oldScreen)) {
      _userInteractedAfterLoad[newScreen] =
          (_userInteractedAfterLoad[newScreen] ?? false) ||
              (_userInteractedAfterLoad.remove(oldScreen) ?? false);
    }
    if (_userInteractedSinceLastApi.containsKey(oldScreen)) {
      _userInteractedSinceLastApi[newScreen] =
          (_userInteractedSinceLastApi[newScreen] ?? false) ||
              (_userInteractedSinceLastApi.remove(oldScreen) ?? false);
    }
    if (_screenInRefreshMode.containsKey(oldScreen)) {
      _screenInRefreshMode[newScreen] =
          (_screenInRefreshMode[newScreen] ?? false) ||
              (_screenInRefreshMode.remove(oldScreen) ?? false);
    }
    if (_sessionStartTime.containsKey(oldScreen)) {
      _sessionStartTime[newScreen] = _sessionStartTime.remove(oldScreen)!;
    }
    if (_activeScreen == oldScreen) {
      _activeScreen = newScreen;
    }

    final idx = _screenOrder.indexOf(oldScreen);
    if (idx >= 0) {
      if (_screenOrder.contains(newScreen)) {
        _screenOrder.removeAt(idx);
      } else {
        _screenOrder[idx] = newScreen;
      }
    } else if (!_screenOrder.contains(newScreen)) {
      _screenOrder.add(newScreen);
    }

    if (currentViewedScreen == oldScreen) {
      currentViewedScreen = newScreen;
    }
  }

  /// Returns the canonical session key for [screen] by matching base routes
  /// if the `#Title` suffix was updated after the request started.
  String _resolveCanonicalScreen(String screen) {
    if (screen == MonitorConstants.allScreensKey ||
        initLogsMap.containsKey(screen) ||
        refreshLogsMap.containsKey(screen)) {
      return screen;
    }
    final String base = _baseRoute(screen);
    if (base.isEmpty) return screen;
    for (int i = _screenOrder.length - 1; i >= 0; i--) {
      final candidate = _screenOrder[i];
      if (_baseRoute(candidate) == base) {
        return candidate;
      }
    }
    for (final k in initLogsMap.keys) {
      if (_baseRoute(k) == base) return k;
    }
    return screen;
  }

  void addLog(
    ApiLogItem item,
    String screen,
    String popupSuffix, {
    String? preassignedPhase,
    int? preassignedCycle,
  }) {
    screen = _resolveCanonicalScreen(screen);
    // item.timestamp is already the request start time!
    final reqStart = item.timestamp;
    final reqEnd = reqStart.add(Duration(milliseconds: item.duration));

    String newPhase;
    int cycle;

    if (preassignedPhase != null) {
      newPhase = preassignedPhase;
      if (newPhase == ApiLogItem.phaseInit) {
        final currentInFlight = _inFlightLoadCount[screen] ?? 0;
        _inFlightLoadCount[screen] =
            currentInFlight > 0 ? currentInFlight - 1 : 0;
        _lastLoadActivityTime[screen] = reqEnd;
        cycle = preassignedCycle ?? (_initCycleCounters[screen] ?? 1);
      } else {
        final currentInFlightRefresh = _inFlightRefreshCount[screen] ?? 0;
        _inFlightRefreshCount[screen] =
            currentInFlightRefresh > 0 ? currentInFlightRefresh - 1 : 0;
        _lastRefreshActivityTime[screen] = reqEnd;
        _screenInRefreshMode[screen] = true;
        cycle = preassignedCycle ?? (_refreshCycleCounters[screen] ?? 1);
        if ((_refreshCycleCounters[screen] ?? 0) < cycle) {
          _refreshCycleCounters[screen] = cycle;
        }
      }
      _lastApiTime[screen] = reqStart;
    } else {
      final bool shouldBeRefresh = _evaluateShouldBeRefresh(
        screen,
        reqStart,
        isPopupActive: popupSuffix.isNotEmpty,
      );

      if (shouldBeRefresh) {
        final bool wasInRefresh = _screenInRefreshMode[screen] == true;
        final lastStart = _lastApiTime[screen];
        final bool gapExceeded = lastStart != null &&
            reqStart.difference(lastStart).inMilliseconds >
                MonitorConstants.refreshGapMs;
        final bool userTapped = _userInteractedSinceLastApi[screen] == true;

        if (!wasInRefresh ||
            gapExceeded ||
            userTapped ||
            (_refreshCycleCounters[screen] ?? 0) == 0) {
          _refreshCycleCounters[screen] =
              (_refreshCycleCounters[screen] ?? 0) + 1;
        }
        _screenInRefreshMode[screen] = true;
        _userInteractedSinceLastApi[screen] = false;
        newPhase = ApiLogItem.phaseRefresh;
        cycle = _refreshCycleCounters[screen] ?? 1;
      } else {
        _screenInRefreshMode[screen] = false;
        newPhase = ApiLogItem.phaseInit;
        cycle = _initCycleCounters[screen] ??= 1;
        _lastLoadActivityTime[screen] = reqEnd;
      }
      _lastApiTime[screen] = reqStart;
    }

    final bool inRefresh = newPhase == ApiLogItem.phaseRefresh;
    final screenLabel = '$screen$popupSuffix';

    if (inRefresh) {
      final refreshLogs = refreshLogsMap[screen] ??= [];
      refreshLogs.add(item.copyWith(
        screen: screenLabel,
        phase: newPhase,
        refreshCycle: cycle,
      ));
      if (refreshLogs.length > _maxLogsPerScreen) {
        refreshLogs.removeAt(0);
      }
    } else {
      final initLogs = initLogsMap[screen] ??= [];
      final initCycle = _initCycleCounters[screen] ?? 1;
      initLogs.add(item.copyWith(
        screen: screenLabel,
        phase: newPhase,
        refreshCycle: initCycle,
      ));
      if (initLogs.length > _maxLogsPerScreen) {
        initLogs.removeAt(0);
      }
    }

    _invalidateGlobalCounts();
    updateView(screen);
  }

  /// Calculates the active network wall-clock time (in ms) by merging overlapping
  /// `[requestStart, requestEnd]` intervals so parallel APIs do not get summed
  /// sequentially.
  static int _calculateMergedDurationMs(Iterable<ApiLogItem> logs) {
    final List<(int, int)> intervals = [];
    for (final l in logs) {
      if (l.duration <= 0) continue;
      final start = l.timestamp.millisecondsSinceEpoch;
      final end = start + l.duration;
      intervals.add((start, end));
    }
    if (intervals.isEmpty) return 0;
    intervals.sort((a, b) => a.$1.compareTo(b.$1));

    int totalMs = 0;
    int curStart = intervals.first.$1;
    int curEnd = intervals.first.$2;

    for (int i = 1; i < intervals.length; i++) {
      final nextStart = intervals[i].$1;
      final nextEnd = intervals[i].$2;
      if (nextStart <= curEnd) {
        if (nextEnd > curEnd) curEnd = nextEnd;
      } else {
        totalMs += (curEnd - curStart);
        curStart = nextStart;
        curEnd = nextEnd;
      }
    }
    totalMs += (curEnd - curStart);
    return totalMs;
  }

  void updateView(String screen) {
    currentViewedScreen = screen;
    if (screen == MonitorConstants.allScreensKey) {
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

      for (final screenName in initLogsMap.keys) {
        final initLogs = initLogsMap[screenName] ?? [];
        final currentInitCycle = _initCycleCounters[screenName] ?? 1;
        final currentInitLogs =
            initLogs.where((l) => l.refreshCycle == currentInitCycle).toList();
        totalInitCount += currentInitLogs.fold(0, (s, l) => s + l.callCount);
        totalInitDuration += _calculateMergedDurationMs(currentInitLogs);
      }

      for (final screenName in refreshLogsMap.keys) {
        final refreshLogs = refreshLogsMap[screenName] ?? [];
        final currentCycle = _refreshCycleCounters[screenName] ?? 0;
        if (currentCycle > 0) {
          final cycleLogs = refreshLogs
              .where((l) => l.refreshCycle == currentCycle)
              .toList();
          totalRefreshCount += cycleLogs.fold(0, (s, l) => s + l.callCount);
          totalRefreshDurationMs += _calculateMergedDurationMs(cycleLogs);
        }
      }

      initApiCount = totalInitCount;
      initTotalDuration = totalInitDuration;
      refreshApiCount = totalRefreshCount;
      refreshTotalDuration = totalRefreshDurationMs;
      totalRefreshApiCount =
          allRefresh.fold(0, (s, l) => s + l.callCount);
      totalRefreshDuration = _calculateMergedDurationMs(allRefresh);

      if (!isDashboardOpen) {
        apiLogs = const [];
        return;
      }

      apiLogs = [...allRefresh, ...allInit]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return;
    }

    final canonical = _resolveCanonicalScreen(screen);
    final initLogs = initLogsMap[canonical] ?? [];
    final refreshLogs = refreshLogsMap[canonical] ?? [];
    final currentCycle = _refreshCycleCounters[canonical] ?? 0;
    final currentInitCycle = _initCycleCounters[canonical] ?? 1;

    final currentInitLogs =
        initLogs.where((l) => l.refreshCycle == currentInitCycle).toList();
    initApiCount = currentInitLogs.fold(0, (s, l) => s + l.callCount);
    initTotalDuration = _calculateMergedDurationMs(currentInitLogs);

    if (currentCycle > 0 && refreshLogs.isNotEmpty) {
      final cycleLogs =
          refreshLogs.where((l) => l.refreshCycle == currentCycle).toList();
      refreshApiCount = cycleLogs.fold(0, (s, l) => s + l.callCount);
      refreshTotalDuration = _calculateMergedDurationMs(cycleLogs);
      totalRefreshApiCount = refreshLogs.fold(0, (s, l) => s + l.callCount);
      totalRefreshDuration = _calculateMergedDurationMs(refreshLogs);
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
    apiLogs = [...refreshLogs, ...curInitOrAll(initLogs, currentInitCycle)]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<ApiLogItem> curInitOrAll(List<ApiLogItem> initLogs, int currentInitCycle) {
    final current =
        initLogs.where((l) => l.refreshCycle == currentInitCycle).toList();
    return current.isNotEmpty ? current : initLogs;
  }

  void clearScreen(String screenName) {
    final canonical = _resolveCanonicalScreen(screenName);
    _screenOrder.remove(canonical);
    if (_activeScreen == canonical) _activeScreen = null;
    _evict(canonical);
    apiLogs = [];
    _invalidateGlobalCounts();
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
    _lastApiTime.clear();
    _lastLoadActivityTime.clear();
    _lastRefreshActivityTime.clear();
    _inFlightLoadCount.clear();
    _inFlightRefreshCount.clear();
    _userInteractedAfterLoad.clear();
    _userInteractedSinceLastApi.clear();
    _screenInRefreshMode.clear();
    _refreshCycleCounters.clear();
    _initCycleCounters.clear();
    _sessionStartTime.clear();
    _screenOrder.clear();
    _activeScreen = null;
    activePopup = null;
    currentViewedScreen = MonitorConstants.allScreensKey;
    _invalidateGlobalCounts();
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
    if (screen == MonitorConstants.allScreensKey) {
      int openCount = 0;
      int openMs = 0;
      int actionCount = 0;
      int actionMs = 0;
      int totalActionCycles = 0;

      for (final screenName in initLogsMap.keys) {
        final initLogs = initLogsMap[screenName] ?? [];
        final currentInitCycle = _initCycleCounters[screenName] ?? 1;
        final currentInitLogs =
            initLogs.where((l) => l.refreshCycle == currentInitCycle).toList();
        openCount += currentInitLogs.fold(0, (s, l) => s + l.callCount);
        openMs += _calculateMergedDurationMs(currentInitLogs);
      }

      for (final screenName in refreshLogsMap.keys) {
        final refreshLogs = refreshLogsMap[screenName] ?? [];
        final cycles = _refreshCycleCounters[screenName] ?? 0;
        totalActionCycles += cycles;
        final latestActionLogs = cycles > 0
            ? refreshLogs.where((l) => l.refreshCycle == cycles).toList()
            : <ApiLogItem>[];
        actionCount += latestActionLogs.fold(0, (s, l) => s + l.callCount);
        actionMs += _calculateMergedDurationMs(latestActionLogs);
      }

      return (
        openCount: openCount,
        openMs: openMs,
        visitCount: 0,
        actionCount: actionCount,
        actionMs: actionMs,
        actionCycles: totalActionCycles,
      );
    }

    final canonical = _resolveCanonicalScreen(screen);
    final initLogs = initLogsMap[canonical] ?? [];
    final refreshLogs = refreshLogsMap[canonical] ?? [];
    final currentInitCycle = _initCycleCounters[canonical] ?? 1;
    final actionCycles = _refreshCycleCounters[canonical] ?? 0;

    // OPEN: current visit's initial load APIs
    final currentInitLogs =
        initLogs.where((l) => l.refreshCycle == currentInitCycle).toList();
    final openCount = currentInitLogs.fold(0, (s, l) => s + l.callCount);
    final openMs = _calculateMergedDurationMs(currentInitLogs);

    // ACTION: latest interaction cycle's APIs (so pulling refresh 5 times
    // shows 1 API for the latest refresh rather than accumulating 5 APIs)
    final latestActionLogs = actionCycles > 0
        ? refreshLogs.where((l) => l.refreshCycle == actionCycles).toList()
        : <ApiLogItem>[];
    final actionCount = latestActionLogs.fold(0, (s, l) => s + l.callCount);
    final actionMs = _calculateMergedDurationMs(latestActionLogs);

    return (
      openCount: openCount,
      openMs: openMs,
      visitCount: currentInitCycle,
      actionCount: actionCount,
      actionMs: actionMs,
      actionCycles: actionCycles,
    );
  }

  bool isPopupRoute(String route) {
    final lower = route.toLowerCase();
    return lower.contains('dialog') ||
        lower.contains('bottomsheet') ||
        lower.contains('popup');
  }

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
