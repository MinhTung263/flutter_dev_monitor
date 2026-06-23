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

  static (String title, String? sub) _parseRoute(String route) {
    if (route == 'ALL') return ('All Screens', null);
    if (route == '/unknown') return ('Unknown Screen', null);

    if (MonitorController.customRouteNames.containsKey(route)) {
      return (MonitorController.customRouteNames[route]!, null);
    }

    final clean = route.startsWith('/') ? route.substring(1) : route;
    final idx = clean.indexOf('/');
    final mainPath =
        idx == -1 ? (clean.isEmpty ? route : clean) : clean.substring(0, idx);
    final sub = idx == -1 ? null : clean.substring(idx);

    // camelCase to spaces
    var formattedTitle = mainPath.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    // underscores/hyphens to spaces
    formattedTitle = formattedTitle.replaceAll(RegExp(r'[_-]'), ' ');

    // capitalize words
    formattedTitle = formattedTitle.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    return (formattedTitle, sub != null ? '($sub)' : null);
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
                            child: s == 'ALL'
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
