import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'flow_map_html_builder.dart';

import '../../controller/monitor_controller.dart';
import '../../../core/monitor_constants.dart';
import '../../../core/monitor_strings.dart';
import '../../../core/monitor_filter_keys.dart';
import '../../navigation/monitor_navigator_observer.dart';
import '../theme/monitor_theme.dart';
import '../widgets/api_log_tile.dart';
import '../../../domain/api_log_item.dart';
import '../../../domain/error_log_item.dart';
import '../../../domain/route_log_item.dart';
import '../../controller/route_log_controller.dart';
import '../widgets/fps_chart.dart';
import '../widgets/hardware_grid.dart';
import '../widgets/metrics_bar.dart';
import '../widgets/monitor_text.dart';
import '../widgets/ram_chart.dart';
import '../widgets/responsive_dialog_wrapper.dart';

part 'dashboard_header.dart';
part 'log_tab_section.dart';
part 'api_log_section.dart';
part 'error_log_section.dart';
part 'route_log_section.dart';
part 'flow_map_section.dart';

class MonitorDashboardPage extends StatefulWidget {
  /// The route name of the initial screen to view in the dashboard.
  final String initialScreen;

  /// Creates a [MonitorDashboardPage] to display performance stats and logs.
  const MonitorDashboardPage({super.key, required this.initialScreen});

  @override
  State<MonitorDashboardPage> createState() => _MonitorDashboardPageState();
}

class _MonitorDashboardPageState extends State<MonitorDashboardPage> {
  late String _selectedScreen;
  bool _chartExpanded = false;
  bool _ramChartExpanded = false;
  String _filterMode = MonitorFilterKeys.all;
  bool _showHeaders = true;
  String _searchQuery = '';
  bool _apiOldestFirst = false;

  MonitorController get _ctrl => MonitorController.instance;

  @override
  void initState() {
    super.initState();
    _selectedScreen = widget.initialScreen;
    MonitorColors.isDark = false; // Luôn khởi tạo giao diện sáng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ctrl.isDashboardOpen = true;
        _ctrl.updateDashboardView(_selectedScreen);
        _ctrl.dismissAlerts();
      }
    });
    MonitorController.instance.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.isDashboardOpen = false;
    });
    MonitorController.instance.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _onScreenChanged(String screen) {
    setState(() {
      _selectedScreen = screen;
      _filterMode = MonitorFilterKeys.all;
      _searchQuery = '';
    });
    _ctrl.updateDashboardView(screen);
  }

  List<ApiLogItem> _applyFilter(List<ApiLogItem> logs) {
    List<ApiLogItem> filtered;
    if (_filterMode == MonitorFilterKeys.slow) {
      filtered = logs.where((l) => l.isSlow).toList();
    } else if (_filterMode == MonitorFilterKeys.error) {
      filtered = logs.where((l) => !l.isSuccess).toList();
    } else if (_filterMode == MonitorFilterKeys.get) {
      filtered = logs.where((l) => l.method == MonitorFilterKeys.get).toList();
    } else if (_filterMode == MonitorFilterKeys.post) {
      filtered = logs.where((l) => l.method == MonitorFilterKeys.post).toList();
    } else {
      filtered = logs.toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((l) {
        final urlMatch = l.url.toLowerCase().contains(q);
        final methodMatch = l.method.toLowerCase().contains(q);
        final statusMatch = l.statusCode.toString().contains(q);
        return urlMatch || methodMatch || statusMatch;
      }).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MonitorColors.isDarkNotifier,
      builder: (context, _, __) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    final allLogs = _ctrl.apiLogs;
    final filteredLogs = _applyFilter(allLogs);
    final flutterErrors = _selectedScreen == MonitorConstants.allScreensKey
        ? _ctrl.errorLogs
        : _ctrl.errorLogs.where((e) => e.screen == _selectedScreen).toList();
    final List<RouteLogItem> routeLogs;
    if (_selectedScreen == MonitorConstants.allScreensKey) {
      routeLogs = _ctrl.routeLogs;
    } else {
      final baseRoute = _selectedScreen.contains('/')
          ? (_selectedScreen.split('/').length > 3
              ? _selectedScreen
                  .split('/')
                  .sublist(0, _selectedScreen.split('/').length - 1)
                  .join('/')
              : _selectedScreen)
          : _selectedScreen;

      final nodes = _buildGitNodes(_ctrl.routeLogs);
      routeLogs = nodes
          .where((n) => n.activeStack.contains(baseRoute))
          .map((n) => n.item as RouteLogItem)
          .toList();
    }

    final errorCount = flutterErrors.length;
    final flowCount = allLogs.length + routeLogs.length;

    final Widget dashboardContent = NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
          child: _DashboardHeader(
            screen: _selectedScreen,
            chartData: _selectedScreen == MonitorConstants.allScreensKey
                ? List<double>.from(_ctrl.overlayFpsHistory)
                : List<double>.from(_ctrl.fpsHistoryMap[_selectedScreen] ?? []),
            chartExpanded: _chartExpanded,
            onChartToggle: () =>
                setState(() => _chartExpanded = !_chartExpanded),
            ramChartData: _selectedScreen == MonitorConstants.allScreensKey
                ? List<double>.from(_ctrl.globalRamHistory)
                : List<double>.from(_ctrl.ramHistoryMap[_selectedScreen] ?? []),
            ramChartExpanded: _ramChartExpanded,
            onRamChartToggle: () =>
                setState(() => _ramChartExpanded = !_ramChartExpanded),
            totalRam: _ctrl.totalRam,
          ),
        ),
      ],
      body: Column(
        children: [
          MonitorMetricsBar(screen: _selectedScreen),
          _FilterBar(
            allLogs: allLogs,
            activeFilter: _filterMode,
            onChanged: (v) => setState(() => _filterMode = v),
            showHeaders: _showHeaders,
            onHeaderToggle: (v) => setState(() => _showHeaders = v),
            oldestFirst: _apiOldestFirst,
            onSortToggle: () =>
                setState(() => _apiOldestFirst = !_apiOldestFirst),
            showHeaderToggle: false,
          ),
          _SearchBar(
            query: _searchQuery,
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          Expanded(
            child: filteredLogs.isEmpty
                ? const _EmptyState()
                : _GroupedLogList(
                    logs: filteredLogs,
                    showHeaders: _showHeaders,
                    selectedScreen: _selectedScreen,
                    oldestFirst: _apiOldestFirst,
                    query: _searchQuery,
                  ),
          ),
        ],
      ),
    );

    return MonitorResponsiveDialogWrapper(
      appBar: _buildAppBar(context, errorCount, flowCount),
      child: dashboardContent,
    );
  }

  void _openScreenPicker(BuildContext context) {
    // visitedScreens is already newest-first (most recently visited screen at top).
    final screens = <String>[
      MonitorConstants.allScreensKey,
      ..._ctrl.visitedScreens,
    ];
    if (!screens.contains(_selectedScreen) &&
        _selectedScreen.isNotEmpty &&
        _selectedScreen != MonitorConstants.unknownRoute) {
      screens.add(_selectedScreen);
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 640;

    if (isLargeScreen) {
      showDialog(
        context: context,
        routeSettings: const RouteSettings(name: '/MonitorFilterDialog'),
        barrierColor: Colors.black.withValues(alpha: 0.4),
        builder: (_) => Center(
          child: Container(
            width: 480, // Constrain width of filter dialog on tablet
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Material(
                color: Colors.transparent,
                child: _ScreenPickerSheet(
                  screens: screens,
                  selected: _selectedScreen,
                  onSelected: (s) {
                    _onScreenChanged(s);
                    Navigator.of(context).pop();
                  },
                  isDialog: true,
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      routeSettings: const RouteSettings(name: '/MonitorScreenPicker'),
      builder: (_) => _ScreenPickerSheet(
        screens: screens,
        selected: _selectedScreen,
        onSelected: (s) {
          _onScreenChanged(s);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final hasCount = count > 0;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (hasCount) _PulseGlowRing(color: color),
        IconButton(
          icon: Icon(
            icon,
            color: hasCount ? color : MonitorColors.secondaryText,
            size: 20,
          ),
          onPressed: onPressed,
        ),
        if (hasCount)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 3,
                    spreadRadius: 1,
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Center(
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  AppBar _buildAppBar(BuildContext context, int errorCount, int flowCount) {
    final isAll = _selectedScreen == MonitorConstants.allScreensKey;
    final accent = MonitorColors.metricTotal;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 640;

    return AppBar(
      automaticallyImplyLeading: false,
      leading: isLargeScreen
          ? null
          : IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: MonitorColors.primaryText,
                size: 18,
              ),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Quay lại',
            ),
      title: InkWell(
        onTap: () => _openScreenPicker(context),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: MonitorColors.dropdownBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isAll ? accent.withValues(alpha: 0.4) : MonitorColors.border,
              width: 0.8,
            ),
            boxShadow: [
              if (isAll)
                BoxShadow(
                  color: accent.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAll ? Icons.all_inclusive_rounded : Icons.layers_outlined,
                size: 13,
                color: isAll ? accent : MonitorColors.secondaryText,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: MonoText(
                  MonitorController.formatRouteName(_selectedScreen),
                  11,
                  color: MonitorColors.primaryText,
                  weight: FontWeight.bold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: MonitorColors.secondaryText,
                size: 15,
              ),
            ],
          ),
        ),
      ),
      centerTitle: true,
      backgroundColor: MonitorColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: MonitorColors.secondaryText),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: MonitorColors.divider),
      ),
      actions: [
        _buildActionIcon(
          icon: Icons.alt_route_rounded,
          count: errorCount + flowCount,
          color: errorCount > 0
              ? MonitorColors.statusError
              : const Color(0xFF57D888),
          onPressed: () => Navigator.of(context).push(
            MonitorResponsiveRoute(
              builder: (_) => const MonitorLogsPage(),
              settings: const RouteSettings(name: '/MonitorLogsPage'),
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            MonitorColors.isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            color: MonitorColors.secondaryText,
            size: 20,
          ),
          onPressed: () => MonitorColors.isDark = !MonitorColors.isDark,
        ),
        IconButton(
          icon: Icon(Icons.restart_alt,
              color: MonitorColors.statusError, size: 22),
          onPressed: () {
            _ctrl.clearAll();
            _ctrl.clearOverlayHistory();
            setState(() => _selectedScreen = MonitorConstants.allScreensKey);
          },
        ),
      ],
    );
  }
}

class MonitorLogsPage extends StatefulWidget {
  final int initialTab;

  const MonitorLogsPage({super.key, this.initialTab = 0});

  @override
  State<MonitorLogsPage> createState() => _MonitorLogsPageState();
}

class _MonitorLogsPageState extends State<MonitorLogsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  MonitorController get _ctrl => MonitorController.instance;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _ctrl.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onUpdate);
    _tabController.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Widget _buildBadge(int count, Color activeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: MonoText(
        '$count',
        7.5,
        color: activeColor,
        weight: FontWeight.bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flutterErrors = _ctrl.errorLogs;
    final allLogs = _ctrl.apiLogs;
    final routeLogs = _ctrl.routeLogs;

    final errorCount = flutterErrors.length;
    final flowCount = allLogs.length + routeLogs.length;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 640;

    return MonitorResponsiveDialogWrapper(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: isLargeScreen
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: MonitorColors.primaryText, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: MonoText('LOG DETAILS', 13,
            color: MonitorColors.primaryText, weight: FontWeight.bold),
        centerTitle: true,
        backgroundColor: MonitorColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: MonitorColors.secondaryText),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: MonitorColors.pageBackground,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: MonitorColors.divider, width: 0.8),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: MonitorColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: MonitorColors.divider,
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: MonitorColors.isDark ? 0.25 : 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: MonitorColors.primaryText,
              unselectedLabelColor: MonitorColors.secondaryText,
              labelStyle: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3),
              tabs: [
                Tab(
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_outlined, size: 12.5),
                      const SizedBox(width: 5),
                      const Text('MAP'),
                      if (flowCount > 0) ...[
                        const SizedBox(width: 5),
                        _buildBadge(flowCount, const Color(0xFF57D888)),
                      ],
                    ],
                  ),
                ),
                Tab(
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.alt_route_rounded, size: 12.5),
                      const SizedBox(width: 5),
                      const Text('FLOW'),
                      if (flowCount > 0) ...[
                        const SizedBox(width: 5),
                        _buildBadge(flowCount, const Color(0xFF57D888)),
                      ],
                    ],
                  ),
                ),
                Tab(
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bug_report_outlined, size: 12.5),
                      const SizedBox(width: 5),
                      const Text('ERRORS'),
                      if (errorCount > 0) ...[
                        const SizedBox(width: 5),
                        _buildBadge(errorCount, MonitorColors.statusError),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.restart_alt,
                color: MonitorColors.statusError, size: 22),
            onPressed: () {
              if (_tabController.index == 0 || _tabController.index == 1) {
                _ctrl.clearFlow();
              } else {
                _ctrl.clearErrors();
              }
            },
          ),
        ],
      ),
      child: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          (_ctrl.globalApiLogs.isEmpty && _ctrl.routeLogs.isEmpty)
              ? const _EmptyState()
              : const _FlowMapList(),
          (_ctrl.globalApiLogs.isEmpty && _ctrl.routeLogs.isEmpty)
              ? const _EmptyState()
              : const _FlowLogList(),
          flutterErrors.isEmpty
              ? const _EmptyErrorState()
              : const _ErrorFlowLogList(),
        ],
      ),
    );
  }
}

class _PulseGlowRing extends StatefulWidget {
  final Color color;
  const _PulseGlowRing({required this.color});

  @override
  State<_PulseGlowRing> createState() => _PulseGlowRingState();
}

class _PulseGlowRingState extends State<_PulseGlowRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.25),
            border: Border.all(
              color: widget.color,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
