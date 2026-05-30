import 'package:flutter/material.dart';

import '../../controller/monitor_controller.dart';
import '../theme/monitor_theme.dart';
import '../widgets/api_log_tile.dart';
import '../../../domain/api_log_item.dart';
import '../widgets/fps_chart.dart';
import '../widgets/hardware_grid.dart';
import '../widgets/metrics_bar.dart';

class MonitorDashboardPage extends StatefulWidget {
  final String initialScreen;
  const MonitorDashboardPage({super.key, required this.initialScreen});

  @override
  State<MonitorDashboardPage> createState() => _MonitorDashboardPageState();
}

class _MonitorDashboardPageState extends State<MonitorDashboardPage> {
  late String _selectedScreen;
  bool _chartExpanded = true;

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
    setState(() => _selectedScreen = screen);
    _ctrl.updateDashboardView(screen);
  }

  @override
  Widget build(BuildContext context) {
    final logs = _ctrl.apiLogs;
    final errorCount = logs.where((l) => !l.isSuccess).length;
    final screens = List<String>.from(_ctrl.fpsHistoryMap.keys);
    if (!screens.contains(_selectedScreen) && _selectedScreen.isNotEmpty) {
      screens.add(_selectedScreen);
    }

    return Scaffold(
      backgroundColor: MonitorColors.pageBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _DashboardHeader(
            screen: _selectedScreen,
            screens: screens,
            chartData: List<double>.from(
                _ctrl.fpsHistoryMap[_selectedScreen] ?? []),
            chartExpanded: _chartExpanded,
            onChartToggle: () =>
                setState(() => _chartExpanded = !_chartExpanded),
            onScreenChanged: _onScreenChanged,
          ),
          MonitorMetricsBar(screenErrorCount: errorCount),
          _LogSectionHeader(screen: _selectedScreen, count: logs.length),
          Expanded(
            child: logs.isEmpty
                ? const _EmptyState()
                : _GroupedLogList(logs: logs),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monitor_heart_outlined,
              size: 15, color: MonitorColors.fpsLine),
          SizedBox(width: 8),
          Text('IN-APP MONITOR',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.8,
                  color: MonitorColors.primaryText)),
        ],
      ),
      centerTitle: true,
      backgroundColor: MonitorColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: MonitorColors.secondaryText),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: MonitorColors.border, height: 1),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.restart_alt,
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

// ─── Dashboard header ─────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final String screen;
  final List<String> screens;
  final List<double> chartData;
  final bool chartExpanded;
  final VoidCallback onChartToggle;
  final ValueChanged<String> onScreenChanged;

  const _DashboardHeader({
    required this.screen,
    required this.screens,
    required this.chartData,
    required this.chartExpanded,
    required this.onChartToggle,
    required this.onScreenChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MonitorColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ScreenSelectorRow(
              screen: screen,
              screens: screens,
              onScreenChanged: onScreenChanged),
          _HBorder(),
          MonitorHardwareGrid(currentScreen: screen),
          _HBorder(),
          _ChartHeader(
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
        ],
      ),
    );
  }
}

class _ChartHeader extends StatelessWidget {
  final int sampleCount;
  final bool expanded;
  final VoidCallback onToggle;

  const _ChartHeader(
      {required this.sampleCount,
      required this.expanded,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.show_chart, size: 13, color: MonitorColors.fpsLine),
            const SizedBox(width: 6),
            const Text('FPS HISTORY',
                style: TextStyle(
                    color: MonitorColors.secondaryText,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            const Spacer(),
            Text('$sampleCount samples',
                style: const TextStyle(
                    color: MonitorColors.secondaryText,
                    fontSize: 9,
                    fontFamily: 'monospace')),
            const SizedBox(width: 6),
            Icon(expanded ? Icons.expand_less : Icons.expand_more,
                color: MonitorColors.secondaryText, size: 16),
          ],
        ),
      ),
    );
  }
}

class _HBorder extends StatelessWidget {
  const _HBorder();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: MonitorColors.border);
}

// ─── Screen selector row ─────────────────────────────────────────────────

class _ScreenSelectorRow extends StatelessWidget {
  final String screen;
  final List<String> screens;
  final ValueChanged<String> onScreenChanged;

  const _ScreenSelectorRow({
    required this.screen,
    required this.screens,
    required this.onScreenChanged,
  });

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ScreenPickerSheet(
        screens: screens,
        selected: screen,
        onSelected: (s) {
          onScreenChanged(s);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_list_outlined,
                  size: 12, color: MonitorColors.secondaryText),
              SizedBox(width: 5),
              Text('Screen',
                  style: TextStyle(
                      color: MonitorColors.secondaryText,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _openPicker(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: MonitorColors.pageBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MonitorColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(screen,
                        style: const TextStyle(
                            color: MonitorColors.primaryText,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.unfold_more,
                      size: 16, color: MonitorColors.secondaryText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MonitorColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: MonitorColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.smartphone_outlined,
                    size: 16, color: MonitorColors.secondaryText),
                const SizedBox(width: 8),
                const Text('Select screen',
                    style: TextStyle(
                        color: MonitorColors.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${screens.length} screens',
                    style: const TextStyle(
                        color: MonitorColors.secondaryText, fontSize: 11)),
              ],
            ),
          ),
          Container(height: 1, color: MonitorColors.border),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: screens.length,
              separatorBuilder: (_, __) =>
                  Container(height: 1, color: MonitorColors.border),
              itemBuilder: (_, i) {
                final s = screens[i];
                final isSelected = s == selected;
                return InkWell(
                  onTap: () => onSelected(s),
                  child: Container(
                    color: isSelected
                        ? MonitorColors.metricTotal.withValues(alpha: 0.06)
                        : null,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: isSelected
                              ? MonitorColors.metricTotal
                              : MonitorColors.border,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(s,
                              style: TextStyle(
                                  color: isSelected
                                      ? MonitorColors.primaryText
                                      : MonitorColors.secondaryText,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (isSelected)
                          const Icon(Icons.check,
                              size: 16, color: MonitorColors.metricTotal),
                      ],
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

// ─── Log section header ───────────────────────────────────────────────────

class _LogSectionHeader extends StatelessWidget {
  final String screen;
  final int count;
  const _LogSectionHeader({required this.screen, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MonitorColors.pageBackground,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          const Icon(Icons.api_outlined,
              size: 12, color: MonitorColors.secondaryText),
          const SizedBox(width: 6),
          Expanded(
            child: Text('API CALLS  ·  $screen',
                style: const TextStyle(
                    color: MonitorColors.secondaryText,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (count > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: MonitorColors.metricTotal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color: MonitorColors.metricTotal,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
            ),
        ],
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.api_outlined, size: 36, color: MonitorColors.border),
          SizedBox(height: 10),
          Text('No API calls yet',
              style:
                  TextStyle(color: MonitorColors.secondaryText, fontSize: 12)),
          SizedBox(height: 3),
          Text('on this screen',
              style: TextStyle(color: MonitorColors.border, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Grouped log list ────────────────────────────────────────────────────

class _HeaderData {
  final String phase;
  final int refreshCycle;
  final int callCount;
  final int totalDuration;
  const _HeaderData({
    required this.phase,
    required this.refreshCycle,
    required this.callCount,
    required this.totalDuration,
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
        final groupLogs =
            logs.where((l) => l.phase == log.phase && l.refreshCycle == log.refreshCycle);
        items.add(_HeaderData(
          phase: log.phase,
          refreshCycle: log.refreshCycle,
          callCount: groupLogs.fold(0, (s, l) => s + l.callCount),
          totalDuration: groupLogs.fold(0, (s, l) => s + l.duration),
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

class _SectionHeader extends StatelessWidget {
  final _HeaderData data;
  const _SectionHeader({required this.data});

  @override
  Widget build(BuildContext context) {
    final isRefresh = data.phase == ApiLogItem.phaseRefresh;
    final color = isRefresh ? MonitorColors.metricRefresh : MonitorColors.metricInit;
    final label = isRefresh ? 'ACTION #${data.refreshCycle}' : 'INIT';

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          Text(
            '${data.callCount} calls · ${data.totalDuration}ms',
            style: TextStyle(
              color: color.withValues(alpha: 0.75),
              fontSize: 9,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
