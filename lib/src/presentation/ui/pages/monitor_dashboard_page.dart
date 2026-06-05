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

// ─── Dashboard header ─────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final String screen;
  final List<double> chartData;
  final bool chartExpanded;
  final VoidCallback onChartToggle;
  final List<double> ramChartData;
  final bool ramChartExpanded;
  final VoidCallback onRamChartToggle;
  final double totalRam;

  const _DashboardHeader({
    required this.screen,
    required this.chartData,
    required this.chartExpanded,
    required this.onChartToggle,
    required this.ramChartData,
    required this.ramChartExpanded,
    required this.onRamChartToggle,
    required this.totalRam,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MonitorColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MonitorHardwareGrid(currentScreen: screen),
          _HBorder(),
          _ChartHeader(
            label: 'FPS HISTORY',
            iconColor: MonitorColors.fpsLine,
            sampleCount: chartData.length,
            expanded: chartExpanded,
            onToggle: onChartToggle,
          ),
          if (chartExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: FpsChartWidget(history: chartData),
            ),
          _HBorder(),
          _ChartHeader(
            label: 'RAM HISTORY',
            iconColor: const Color(0xFFF472B6),
            sampleCount: ramChartData.length,
            expanded: ramChartExpanded,
            onToggle: onRamChartToggle,
          ),
          if (ramChartExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: RamChartWidget(history: ramChartData, totalRam: totalRam),
            ),
          _HBorder(),
        ],
      ),
    );
  }
}

class _ChartHeader extends StatelessWidget {
  final String label;
  final Color iconColor;
  final int sampleCount;
  final bool expanded;
  final VoidCallback onToggle;

  const _ChartHeader({
    required this.label,
    required this.iconColor,
    required this.sampleCount,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            LabelText(
              label,
              iconColor,
              size: 10,
              spacing: 0.5,
            ),
            const Spacer(),
            MonoText(
              '$sampleCount samples',
              9,
            ),
            SizedBox(width: 6),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: MonitorColors.secondaryText,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _HBorder extends StatelessWidget {
  _HBorder();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: MonitorColors.divider);
}

class _ScreenPickerSheet extends StatelessWidget {
  final List<String> screens;
  final String selected;
  final ValueChanged<String> onSelected;

  const _ScreenPickerSheet({
    required this.screens,
    required this.selected,
    required this.onSelected,
  });

  // "/PostDetail/123" → ("PostDetail", "/123")
  static (String title, String? sub) _parseRoute(String route) {
    final clean = route.startsWith('/') ? route.substring(1) : route;
    final idx = clean.indexOf('/');
    if (idx == -1) return (clean.isEmpty ? route : clean, null);
    return (clean.substring(0, idx), clean.substring(idx));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MonitorColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            decoration: BoxDecoration(
              color: MonitorColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                BodyText('Screens', 14, weight: FontWeight.bold),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MonitorColors.metricTotal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: MonitorColors.metricTotal.withValues(alpha: 0.3),
                        width: 0.5),
                  ),
                  child: MonoText('${screens.length}', 10,
                      color: MonitorColors.metricTotal,
                      weight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(height: 1, color: MonitorColors.divider),
          // List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.48,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              itemCount: screens.length,
              itemBuilder: (_, i) {
                final s = screens[i];
                final isSelected = s == selected;
                final (title, sub) = _parseRoute(s);
                final accent = MonitorColors.metricTotal;

                return GestureDetector(
                  onTap: () => onSelected(s),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent.withValues(alpha: 0.08)
                          : MonitorColors.pageBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(
                          color: isSelected ? accent : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          // Index badge (1 = newest)
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent.withValues(alpha: 0.15)
                                  : MonitorColors.border.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: MonoText('${i + 1}', 9,
                                color: isSelected
                                    ? accent
                                    : MonitorColors.secondaryText,
                                weight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          // Screen name + sub-path
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BodyText(
                                  title,
                                  12,
                                  color: isSelected
                                      ? MonitorColors.primaryText
                                      : MonitorColors.secondaryText,
                                  weight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (sub != null)
                                  MonoText(sub, 9,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Indicator
                          if (isSelected)
                            Icon(Icons.check_circle_rounded,
                                size: 17, color: accent)
                          else
                            Icon(Icons.chevron_right_rounded,
                                size: 16, color: MonitorColors.border),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

// ─── Log tab header (API / ERRORS toggle) ─────────────────────────────────────

class _LogTabHeader extends StatelessWidget {
  final String screen;
  final int apiCount;
  final int routeCount;
  final int errorCount;
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  const _LogTabHeader({
    required this.screen,
    required this.apiCount,
    required this.routeCount,
    required this.errorCount,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MonitorColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _TabButton(
                  label: 'API',
                  count: apiCount,
                  icon: Icons.api_outlined,
                  active: activeTab == 0,
                  activeColor: MonitorColors.metricTotal,
                  onTap: () => onTabChanged(0),
                ),
                _TabButton(
                  label: 'ROUTES',
                  count: routeCount,
                  icon: Icons.route_outlined,
                  active: activeTab == 1,
                  activeColor: const Color(0xFFA78BFA),
                  onTap: () => onTabChanged(1),
                ),
                _TabButton(
                  label: 'ERRORS',
                  count: errorCount,
                  icon: Icons.bug_report_outlined,
                  active: activeTab == 2,
                  activeColor: MonitorColors.statusError,
                  onTap: () => onTabChanged(2),
                ),
                Flexible(
                  child: MonoText(
                    screen,
                    9,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: MonitorColors.divider),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : MonitorColors.secondaryText;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 11, color: color),
                const SizedBox(width: 5),
                LabelText(
                  label,
                  color,
                  size: 11,
                  spacing: 0.3,
                ),
                if (count > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color:
                          activeColor.withValues(alpha: active ? 0.18 : 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: MonoText(
                      '$count',
                      9,
                      color: active
                          ? activeColor
                          : MonitorColors.secondaryText,
                      weight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            height: 2,
            color: active ? activeColor : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

// ─── Empty states ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: MonitorColors.border.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.api_outlined,
                size: 26, color: MonitorColors.secondaryText),
          ),
          SizedBox(height: 12),
          BodyText('No API calls yet', 13,
              color: MonitorColors.secondaryText,
              weight: FontWeight.w500),
          SizedBox(height: 4),
          BodyText('on this screen', 11, color: MonitorColors.border),
        ],
      ),
    );
  }
}

// ─── Grouped log list ─────────────────────────────────────────────────────────

class _HeaderData {
  final String phase;
  final int refreshCycle;
  final int callCount;
  final int totalDuration;
  final int totalBytes;
  const _HeaderData({
    required this.phase,
    required this.refreshCycle,
    required this.callCount,
    required this.totalDuration,
    required this.totalBytes,
  });
}

class _GroupedLogList extends StatelessWidget {
  final List<ApiLogItem> logs;
  const _GroupedLogList({required this.logs});

  List<Object> _buildItems() {
    final items = <Object>[];
    String? prevKey;

    for (final log in logs) {
      final key = '${log.phase}_${log.refreshCycle}';
      if (key != prevKey) {
        prevKey = key;
        final groupLogs = logs.where(
            (l) => l.phase == log.phase && l.refreshCycle == log.refreshCycle);
        items.add(_HeaderData(
          phase: log.phase,
          refreshCycle: log.refreshCycle,
          callCount: groupLogs.fold(0, (s, l) => s + l.callCount),
          totalDuration: groupLogs.fold(0, (s, l) => s + l.duration),
          totalBytes: groupLogs.fold(0, (s, l) => s + l.responseBytes),
        ));
      }
      items.add(log);
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is _HeaderData) return _SectionHeader(data: item);
        return ApiLogTile(log: item as ApiLogItem);
      },
    );
  }
}

// ─── Filter bar ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final List<ApiLogItem> allLogs;
  final String activeFilter;
  final ValueChanged<String> onChanged;

  const _FilterBar({
    required this.allLogs,
    required this.activeFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final slowCount = allLogs.where((l) => l.isSlow).length;
    final errCount = allLogs.where((l) => !l.isSuccess).length;
    final getCount = allLogs.where((l) => l.method == 'GET').length;
    final postCount = allLogs.where((l) => l.method == 'POST').length;

    return Container(
      color: MonitorColors.pageBackground,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'ALL',
              count: allLogs.length,
              active: activeFilter == 'ALL',
              color: MonitorColors.metricTotal,
              onTap: () => onChanged('ALL'),
            ),
            if (slowCount > 0) ...[
              SizedBox(width: 6),
              _FilterChip(
                label: 'SLOW',
                count: slowCount,
                active: activeFilter == 'SLOW',
                color: MonitorColors.statusSlow,
                onTap: () => onChanged('SLOW'),
              ),
            ],
            if (errCount > 0) ...[
              SizedBox(width: 6),
              _FilterChip(
                label: 'ERR',
                count: errCount,
                active: activeFilter == 'ERR',
                color: MonitorColors.statusError,
                onTap: () => onChanged('ERR'),
              ),
            ],
            if (getCount > 0) ...[
              SizedBox(width: 6),
              _FilterChip(
                label: 'GET',
                count: getCount,
                active: activeFilter == 'GET',
                color: MonitorColors.methodGet,
                onTap: () => onChanged('GET'),
              ),
            ],
            if (postCount > 0) ...[
              SizedBox(width: 6),
              _FilterChip(
                label: 'POST',
                count: postCount,
                active: activeFilter == 'POST',
                color: MonitorColors.methodPost,
                onTap: () => onChanged('POST'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                active ? color.withValues(alpha: 0.55) : MonitorColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LabelText(
              label,
              active ? color : MonitorColors.secondaryText,
              size: 10,
              spacing: 0.3,
            ),
            SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: (active ? color : MonitorColors.secondaryText)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: MonoText(
                '$count',
                9,
                color: active ? color : MonitorColors.secondaryText,
                weight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error list ───────────────────────────────────────────────────────────────

class _EmptyErrorState extends StatelessWidget {
  const _EmptyErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: MonitorColors.border.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bug_report_outlined,
                size: 26, color: MonitorColors.secondaryText),
          ),
          SizedBox(height: 12),
          BodyText('No Flutter errors', 13,
              color: MonitorColors.secondaryText,
              weight: FontWeight.w500),
          SizedBox(height: 4),
          BodyText('caught yet', 11, color: MonitorColors.border),
        ],
      ),
    );
  }
}

class _ErrorList extends StatelessWidget {
  final List<ErrorLogItem> errors;
  const _ErrorList({required this.errors});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: errors.length,
      itemBuilder: (_, i) => _ErrorLogTile(error: errors[i]),
    );
  }
}

class _ErrorLogTile extends StatefulWidget {
  final ErrorLogItem error;
  const _ErrorLogTile({required this.error});

  @override
  State<_ErrorLogTile> createState() => _ErrorLogTileState();
}

class _ErrorLogTileState extends State<_ErrorLogTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.error;
    final ts = e.timestamp;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
    final isFlutter = e.type == ErrorLogItem.typeFlutter;
    final typeColor =
        isFlutter ? MonitorColors.statusSlow : MonitorColors.statusError;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: MonitorColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: MonitorColors.statusError.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: MonitorColors.orderBadgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: MonoText('#${e.id}', 9,
                            color: MonitorColors.orderBadgeText,
                            weight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                              color: typeColor.withValues(alpha: 0.30),
                              width: 0.5),
                        ),
                        child: LabelText(e.type, typeColor,
                            size: 7, spacing: 0.3),
                      ),
                      const Spacer(),
                      MonoText(timeStr, 10),
                      SizedBox(width: 8),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                          color: MonitorColors.secondaryText, size: 16),
                    ],
                  ),
                  SizedBox(height: 8),
                  MonoText(
                    e.message,
                    11,
                    color: MonitorColors.statusError,
                    weight: FontWeight.w500,
                    height: 1.4,
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && e.stackTrace.isNotEmpty) ...[
            Container(height: 1, color: MonitorColors.divider),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MonitorColors.expandedDetailBg,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: SelectionArea(
                child: MonoText(
                  e.stackTrace.split('\n').take(20).join('\n'),
                  9.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Route log list ──────────────────────────────────────────────────────────

class _EmptyRouteState extends StatelessWidget {
  const _EmptyRouteState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: MonitorColors.border.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.route_outlined,
                size: 26, color: MonitorColors.secondaryText),
          ),
          const SizedBox(height: 12),
          BodyText('No route events yet', 13,
              color: MonitorColors.secondaryText,
              weight: FontWeight.w500),
          const SizedBox(height: 4),
          BodyText('Navigate around the app to see the flow', 11,
              color: MonitorColors.border),
        ],
      ),
    );
  }
}

class _RouteLogList extends StatelessWidget {
  final List<RouteLogItem> logs;
  const _RouteLogList({required this.logs});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: logs.length,
      itemBuilder: (_, i) => _RouteLogTile(item: logs[i]),
    );
  }
}

class _RouteLogTile extends StatelessWidget {
  final RouteLogItem item;
  const _RouteLogTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final ts = item.timestamp;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';

    final Color color;
    final IconData icon;
    final String eventLabel;

    switch (item.event) {
      case RouteLogItem.eventPush:
        color = MonitorColors.statusSuccess;
        icon = Icons.arrow_upward_rounded;
        eventLabel = 'PUSH';
        break;
      case RouteLogItem.eventPop:
        color = MonitorColors.secondaryText;
        icon = Icons.arrow_downward_rounded;
        eventLabel = 'POP';
        break;
      default:
        color = MonitorColors.statusSlow;
        icon = Icons.sync_alt_rounded;
        eventLabel = 'REPLACE';
        break;
    }

    final durationStr = item.duration != null
        ? RouteLogController.fmtDuration(item.duration!)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: MonitorColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 1, right: 10),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 13, color: color),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                              color: color.withValues(alpha: 0.35),
                              width: 0.5),
                        ),
                        child: LabelText(eventLabel, color,
                            size: 7, spacing: 0.3),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MonoText(
                          item.route,
                          11,
                          color: MonitorColors.primaryText,
                          weight: FontWeight.w600,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (item.from != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.subdirectory_arrow_right_rounded,
                            size: 11, color: MonitorColors.secondaryText),
                        const SizedBox(width: 4),
                        Expanded(
                          child: MonoText(
                            item.event == RouteLogItem.eventPush
                                ? 'from ${item.from}'
                                : item.event == RouteLogItem.eventPop
                                    ? '→ ${item.from}'
                                    : 'was ${item.from}',
                            10,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Time + duration
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MonoText(timeStr, 10),
                if (durationStr != null) ...[
                  const SizedBox(height: 2),
                  MonoText(durationStr, 9,
                      color: color,
                      weight: FontWeight.w600),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final _HeaderData data;
  const _SectionHeader({required this.data});

  static String _fmtBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  String _sectionSummary(_HeaderData d) {
    final size = _fmtBytes(d.totalBytes);
    final parts = ['${d.callCount} calls'];
    if (size.isNotEmpty) parts.add(size);
    parts.add('${d.totalDuration}ms');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final isRefresh = data.phase == ApiLogItem.phaseRefresh;
    final color =
        isRefresh ? MonitorColors.metricRefresh : MonitorColors.metricInit;
    final label = isRefresh ? 'ACTION #${data.refreshCycle}' : 'INIT';

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          LabelText(
            label,
            color,
            size: 10,
            spacing: 0.8,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: MonoText(
              _sectionSummary(data),
              9,
              color: color.withValues(alpha: 0.70),
              weight: FontWeight.w600,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
