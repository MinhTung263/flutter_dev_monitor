part of 'monitor_dashboard_page.dart';

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
