part of 'monitor_dashboard_page.dart';

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
