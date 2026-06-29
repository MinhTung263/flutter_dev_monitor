import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controller/monitor_controller.dart';
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

part 'dashboard_header.dart';
part 'log_tab_section.dart';
part 'api_log_section.dart';
part 'error_log_section.dart';
part 'route_log_section.dart';

class MonitorDashboardPage extends StatefulWidget {
  final String initialScreen;
  const MonitorDashboardPage({super.key, required this.initialScreen});

  @override
  State<MonitorDashboardPage> createState() => _MonitorDashboardPageState();
}

class _MonitorDashboardPageState extends State<MonitorDashboardPage> {
  late String _selectedScreen;
  bool _chartExpanded = false;
  bool _ramChartExpanded = false;
  int _activeTab = 0; // 0=API  1=ERRORS  2=ROUTES
  String _filterMode = 'ALL';
  bool _showHeaders = true;
  String _searchQuery = '';

  MonitorController get _ctrl => MonitorController.instance;

  @override
  void initState() {
    super.initState();
    _selectedScreen = widget.initialScreen;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ctrl.updateDashboardView(_selectedScreen);
        _ctrl.dismissAlerts();
      }
    });
    MonitorController.instance.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    MonitorController.instance.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _onScreenChanged(String screen) {
    setState(() {
      _selectedScreen = screen;
      _filterMode = 'ALL';
      _activeTab = 0;
      _searchQuery = '';
    });
    _ctrl.updateDashboardView(screen);
  }

  List<ApiLogItem> _applyFilter(List<ApiLogItem> logs) {
    List<ApiLogItem> filtered;
    switch (_filterMode) {
      case 'SLOW':
        filtered = logs.where((l) => l.isSlow).toList();
        break;
      case 'ERR':
        filtered = logs.where((l) => !l.isSuccess).toList();
        break;
      case 'GET':
        filtered = logs.where((l) => l.method == 'GET').toList();
        break;
      case 'POST':
        filtered = logs.where((l) => l.method == 'POST').toList();
        break;
      default:
        filtered = logs.toList();
        break;
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
    final flutterErrors = _selectedScreen == 'ALL'
        ? _ctrl.errorLogs
        : _ctrl.errorLogs.where((e) => e.screen == _selectedScreen).toList();
    final routeLogs = _ctrl.routeLogs;

    return Scaffold(
      backgroundColor: MonitorColors.pageBackground,
      appBar: _buildAppBar(context),
      body: NestedScrollView(
        // Header slides away when scrolling down
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: _DashboardHeader(
              screen: _selectedScreen,
              chartData: _selectedScreen == 'ALL'
                  ? List<double>.from(_ctrl.overlayFpsHistory)
                  : List<double>.from(_ctrl.fpsHistoryMap[_selectedScreen] ?? []),
              chartExpanded: _chartExpanded,
              onChartToggle: () =>
                  setState(() => _chartExpanded = !_chartExpanded),
              ramChartData: _selectedScreen == 'ALL'
                  ? List<double>.from(_ctrl.globalRamHistory)
                  : List<double>.from(_ctrl.ramHistoryMap[_selectedScreen] ?? []),
              ramChartExpanded: _ramChartExpanded,
              onRamChartToggle: () =>
                  setState(() => _ramChartExpanded = !_ramChartExpanded),
              totalRam: _ctrl.totalRam,
            ),
          ),
        ],
        // Body stays pinned — MetricsBar + TabHeader + FilterBar always visible
        body: Column(
          children: [
            MonitorMetricsBar(screen: _selectedScreen),
            _LogTabHeader(
              apiCount: allLogs.length,
              routeCount: routeLogs.length,
              errorCount: flutterErrors.length,
              activeTab: _activeTab,
              onTabChanged: (i) => setState(() {
                _activeTab = i;
                _filterMode = 'ALL';
                _searchQuery = '';
              }),
            ),
            if (_activeTab == 0) ...[
              _FilterBar(
                allLogs: allLogs,
                activeFilter: _filterMode,
                onChanged: (v) => setState(() => _filterMode = v),
                showHeaders: _showHeaders,
                onHeaderToggle: (v) => setState(() => _showHeaders = v),
              ),
              _SearchBar(
                query: _searchQuery,
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ],
            Expanded(
              child: switch (_activeTab) {
                1 => flutterErrors.isEmpty
                    ? const _EmptyErrorState()
                    : _ErrorList(errors: flutterErrors),
                2 => routeLogs.isEmpty
                    ? const _EmptyRouteState()
                    : _RouteLogList(logs: routeLogs),
                _ => filteredLogs.isEmpty
                    ? const _EmptyState()
                    : _GroupedLogList(
                        logs: filteredLogs,
                        showHeaders: _showHeaders,
                      ),
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openScreenPicker(BuildContext context) {
    // visitedScreens tracks all screens seen this session regardless of whether
    // their data was cleared on pop — so Login/Splash remain visible even after
    // navigating to Home.
    final screens = <String>[
      'ALL',
      ..._ctrl.visitedScreens.toList().reversed,
    ];
    if (!screens.contains(_selectedScreen) &&
        _selectedScreen.isNotEmpty &&
        _selectedScreen != '/unknown') {
      screens.add(_selectedScreen);
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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

  AppBar _buildAppBar(BuildContext context) {
    final isAll = _selectedScreen == 'ALL';
    final accent = MonitorColors.metricTotal;

    return AppBar(
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
              color: isAll ? accent.withValues(alpha: 0.4) : MonitorColors.border,
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
            setState(() => _selectedScreen = 'ALL');
          },
        ),
      ],
    );
  }
}
