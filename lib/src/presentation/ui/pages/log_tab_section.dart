part of 'monitor_dashboard_page.dart';

// ─── Log tab header (API / ERRORS toggle) ─────────────────────────────────────

class _LogTabHeader extends StatelessWidget {
  final int apiCount;
  final int routeCount;
  final int errorCount;
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  const _LogTabHeader({
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
                  label: 'ERRORS',
                  count: errorCount,
                  icon: Icons.bug_report_outlined,
                  active: activeTab == 1,
                  activeColor: MonitorColors.statusError,
                  onTap: () => onTabChanged(1),
                ),
                _TabButton(
                  label: 'ROUTES',
                  count: routeCount,
                  icon: Icons.route_outlined,
                  active: activeTab == 2,
                  activeColor: const Color(0xFFA78BFA),
                  onTap: () => onTabChanged(2),
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
