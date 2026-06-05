import 'package:flutter/material.dart';

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
  bool _chartExpanded = true;
  bool _ramChartExpanded = false;
  int _activeTab = 0; // 0=API  1=ROUTES  2=ERRORS
  String _filterMode = 'ALL';

  MonitorController get _ctrl => MonitorController.instance;

  @override
  void initState() {
    super.initState();
    _selectedScreen = widget.initialScreen;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.updateDashboardView(_selectedScreen);
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
    });
    _ctrl.updateDashboardView(screen);
  }

  List<ApiLogItem> _applyFilter(List<ApiLogItem> logs) {
    switch (_filterMode) {
      case 'SLOW':
        return logs.where((l) => l.isSlow).toList();
      case 'ERR':
        return logs.where((l) => !l.isSuccess).toList();
      case 'GET':
        return logs.where((l) => l.method == 'GET').toList();
      case 'POST':
        return logs.where((l) => l.method == 'POST').toList();
      default:
        return logs;
    }
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
    final errorCount = allLogs.where((l) => !l.isSuccess).length;
    final flutterErrors = _ctrl.errorLogs;
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
              chartData:
                  List<double>.from(_ctrl.fpsHistoryMap[_selectedScreen] ?? []),
              chartExpanded: _chartExpanded,
              onChartToggle: () =>
                  setState(() => _chartExpanded = !_chartExpanded),
              ramChartData:
                  List<double>.from(_ctrl.ramHistoryMap[_selectedScreen] ?? []),
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
            MonitorMetricsBar(screenErrorCount: errorCount),
            _LogTabHeader(
              screen: _selectedScreen,
              apiCount: allLogs.length,
              routeCount: routeLogs.length,
              errorCount: flutterErrors.length,
              activeTab: _activeTab,
              onTabChanged: (i) => setState(() {
                _activeTab = i;
                _filterMode = 'ALL';
              }),
            ),
            if (_activeTab == 0)
              _FilterBar(
                allLogs: allLogs,
                activeFilter: _filterMode,
                onChanged: (v) => setState(() => _filterMode = v),
              ),
            Expanded(
              child: switch (_activeTab) {
                1 => routeLogs.isEmpty
                    ? const _EmptyRouteState()
                    : _RouteLogList(logs: routeLogs),
                2 => flutterErrors.isEmpty
                    ? const _EmptyErrorState()
                    : _ErrorList(errors: flutterErrors),
                _ => filteredLogs.isEmpty
                    ? const _EmptyState()
                    : _GroupedLogList(logs: filteredLogs),
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
    final screens = _ctrl.visitedScreens.toList().reversed.toList();
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
    return AppBar(
      title: GestureDetector(
        onTap: () => _openScreenPicker(context),
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: MonoText(
                _selectedScreen,
                13,
                color: MonitorColors.primaryText,
                weight: FontWeight.bold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: MonitorColors.secondaryText),
          ],
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
            setState(() => _selectedScreen = '/unknown');
          },
        ),
      ],
    );
  }
}
