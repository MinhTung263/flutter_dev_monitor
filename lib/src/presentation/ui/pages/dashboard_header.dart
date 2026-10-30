part of 'monitor_dashboard_page.dart';

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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: _ChartHeader(
                    label: LocaleKeys.fpsHistory.tr,
                    icon: Icons.show_chart_rounded,
                    iconColor: MonitorColors.fpsLine,
                    sampleCount: chartData.length,
                    expanded: chartExpanded,
                    onToggle: onChartToggle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChartHeader(
                    label: LocaleKeys.ramHistory.tr,
                    icon: Icons.analytics_outlined,
                    iconColor: const Color(0xFFF472B6),
                    sampleCount: ramChartData.length,
                    expanded: ramChartExpanded,
                    onToggle: onRamChartToggle,
                  ),
                ),
              ],
            ),
          ),
          if (chartExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: FpsChartWidget(history: chartData),
            ),
          if (ramChartExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
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
  final IconData icon;
  final Color iconColor;
  final int sampleCount;
  final bool expanded;
  final VoidCallback onToggle;

  const _ChartHeader({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.sampleCount,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: expanded
              ? iconColor.withValues(alpha: 0.10)
              : MonitorColors.pageBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: expanded
                ? iconColor.withValues(alpha: 0.45)
                : MonitorColors.border.withValues(alpha: 0.8),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: LabelText(
                label,
                expanded ? iconColor : MonitorColors.primaryText,
                size: 9.5,
                spacing: 0.4,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: MonoText(
                '$sampleCount',
                8.5,
                color: iconColor,
                weight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: expanded ? iconColor : MonitorColors.secondaryText,
              size: 15,
            ),
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
      Container(height: 1, color: MonitorColors.divider);
}

class _ScreenPickerSheet extends StatefulWidget {
  final List<String> screens;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool isDialog;

  const _ScreenPickerSheet({
    required this.screens,
    required this.selected,
    required this.onSelected,
    this.isDialog = false,
  });

  static (String title, String? sub) _parseRoute(String route) {
    final title = MonitorController.formatRouteName(route);
    if (route == MonitorConstants.allScreensKey) {
      return (title, null);
    }
    final rawPath = route.contains('#') ? route.split('#').first.trim() : route.trim();
    if (rawPath.isNotEmpty && rawPath != title) {
      return (title, rawPath);
    }
    return (title, null);
  }

  @override
  State<_ScreenPickerSheet> createState() => _ScreenPickerSheetState();
}

class _ScreenPickerSheetState extends State<_ScreenPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final ctrl = MonitorController.instance;
    final filteredScreens = _search.trim().isEmpty
        ? widget.screens
        : widget.screens.where((s) {
            if (s == MonitorConstants.allScreensKey) return true;
            final q = _search.toLowerCase();
            final (title, sub) = _ScreenPickerSheet._parseRoute(s);
            return title.toLowerCase().contains(q) ||
                (sub != null && sub.toLowerCase().contains(q)) ||
                s.toLowerCase().contains(q);
          }).toList();

    return MonitorThemeScope(
      child: Container(
        decoration: BoxDecoration(
          color: MonitorColors.surface,
          borderRadius: widget.isDialog
              ? BorderRadius.circular(16)
              : const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.isDialog)
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                decoration: BoxDecoration(
                  color: MonitorColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            else
              const SizedBox(height: 16),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  BodyText(LocaleKeys.screensTitle.tr, 14, weight: FontWeight.bold),
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
                    child: MonoText('${widget.screens.length}', 10,
                        color: MonitorColors.metricTotal,
                        weight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (widget.screens.length >= 5)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: _SearchBar(
                  query: _search,
                  onChanged: (v) => setState(() => _search = v),
                  transparent: true,
                ),
              ),
            Container(height: 1, color: MonitorColors.divider),
            // List
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.52,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                itemCount: filteredScreens.length,
                itemBuilder: (_, i) {
                  final s = filteredScreens[i];
                  final isSelected = s == widget.selected;
                  final isAll = s == MonitorConstants.allScreensKey;

                  final (title, sub) = _ScreenPickerSheet._parseRoute(s);
                  final accent = MonitorColors.metricTotal;

                  // Calculate quick stats for this screen
                  final List<ApiLogItem> screenLogs = isAll
                      ? ctrl.globalApiLogs
                      : [
                          ...(ctrl.initLogsMap[s] ?? const <ApiLogItem>[]),
                          ...(ctrl.refreshLogsMap[s] ?? const <ApiLogItem>[]),
                        ];
                  final int apiTotal = screenLogs.length;
                  final int errCount =
                      screenLogs.where((l) => !l.isSuccess).length;
                  final int slowCount =
                      screenLogs.where((l) => l.isSlow).length;

                  return GestureDetector(
                    onTap: () => widget.onSelected(s),
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
                              child: isAll
                                  ? Icon(
                                      Icons.all_inclusive_rounded,
                                      size: 13,
                                      color: isSelected
                                          ? accent
                                          : MonitorColors.secondaryText,
                                    )
                                  : MonoText('$i', 9,
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
                                        : FontWeight.w600,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (sub != null) ...[
                                    const SizedBox(height: 2),
                                    MonoText(
                                      sub,
                                      9,
                                      color: MonitorColors.secondaryText
                                          .withValues(alpha: 0.75),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Per-screen API / Error / Slow summary pills
                            if (apiTotal > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: MonoText(
                                  '$apiTotal API',
                                  8.5,
                                  color: accent,
                                  weight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (errCount > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: MonitorColors.statusError
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: MonoText(
                                  '$errCount ERR',
                                  8.5,
                                  color: MonitorColors.statusError,
                                  weight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ] else if (slowCount > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: MonitorColors.statusSlow
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: MonoText(
                                  '$slowCount SLOW',
                                  8.5,
                                  color: MonitorColors.statusSlow,
                                  weight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
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
      ),
    );
  }
}
