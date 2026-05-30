import 'package:flutter/material.dart';

import '../../../domain/api_log_item.dart';
import '../theme/monitor_theme.dart';

class ApiLogTile extends StatefulWidget {
  final ApiLogItem log;
  const ApiLogTile({super.key, required this.log});

  @override
  State<ApiLogTile> createState() => _ApiLogTileState();
}

class _ApiLogTileState extends State<ApiLogTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final statusColor = _statusColor(log);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: MonitorColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: log.isSlow
              ? MonitorColors.statusSlow.withValues(alpha: 0.4)
              : (log.isSuccess
                  ? MonitorColors.border
                  : MonitorColors.statusError.withValues(alpha: 0.35)),
        ),
      ),
      child: Column(
        children: [
          _CollapsedRow(
              log: log,
              statusColor: statusColor,
              expanded: _expanded,
              onTap: () => setState(() => _expanded = !_expanded)),
          if (_expanded) _ExpandedDetail(log: log),
        ],
      ),
    );
  }

  static Color _statusColor(ApiLogItem log) {
    if (!log.isSuccess) return MonitorColors.statusError;
    if (log.isSlow) return MonitorColors.statusSlow;
    return MonitorColors.statusSuccess;
  }
}

class _CollapsedRow extends StatelessWidget {
  final ApiLogItem log;
  final Color statusColor;
  final bool expanded;
  final VoidCallback onTap;

  const _CollapsedRow(
      {required this.log,
      required this.statusColor,
      required this.expanded,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _OrderBadge(order: log.orderNumber),
                const SizedBox(width: 6),
                _PhaseBadge(phase: log.phase),
                const SizedBox(width: 6),
                if (log.hasMultipleCalls) ...[
                  _CallCountBadge(count: log.callCount),
                  const SizedBox(width: 6),
                ],
                _MethodBadge(method: log.method),
                const Spacer(),
                _DurationLabel(duration: log.duration, isSlow: log.isSlow, color: statusColor),
                const SizedBox(width: 8),
                Icon(expanded ? Icons.expand_less : Icons.expand_more,
                    color: MonitorColors.secondaryText, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            SelectionArea(
              child: Text(log.url,
                  style: const TextStyle(
                      color: MonitorColors.primaryText,
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                      height: 1.3)),
            ),
            if (log.hasCallerName) ...[
              const SizedBox(height: 4),
              _CallerRow(callerName: log.callerName, color: MonitorColors.secondaryText),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpandedDetail extends StatelessWidget {
  final ApiLogItem log;
  const _ExpandedDetail({required this.log});

  @override
  Widget build(BuildContext context) {
    final ts = log.timestamp;
    final timeStr = '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}:'
        '${ts.second.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Container(color: MonitorColors.border, height: 1),
        Container(
          padding: const EdgeInsets.all(12),
          color: MonitorColors.expandedDetailBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (log.isSlow) _SlowBanner(duration: log.duration),
              const Text('EXECUTION TIMELINE',
                  style: TextStyle(
                      color: MonitorColors.secondaryText,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
              const SizedBox(height: 12),
              _TimelineStep(
                title: 'Request Sent',
                subtitle: 'Request packet started leaving the device.',
                timeStr: timeStr,
                isFirst: true,
                color: MonitorColors.methodGet,
              ),
              _TimelineStep(
                title: 'Server Processing',
                subtitle: 'Network transfer time and backend server processing.',
                timeStr: '+${log.duration}ms',
                color: log.isSlow ? MonitorColors.statusSlow : MonitorColors.methodGet,
              ),
              _TimelineStep(
                title: 'Payload Response',
                subtitle: 'HTTP ${log.statusCode} — Data synchronized.',
                timeStr: 'Done',
                isLast: true,
                color: log.isSuccess ? MonitorColors.statusSuccess : MonitorColors.statusError,
              ),
              const SizedBox(height: 8),
              Container(color: MonitorColors.border, height: 1),
              const SizedBox(height: 6),
              _LogFooter(log: log),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderBadge extends StatelessWidget {
  final int order;
  const _OrderBadge({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
          color: MonitorColors.orderBadgeBg, borderRadius: BorderRadius.circular(4)),
      child: Text('#$order',
          style: const TextStyle(
              color: MonitorColors.orderBadgeText,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace')),
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  final String phase;
  const _PhaseBadge({required this.phase});

  @override
  Widget build(BuildContext context) {
    final isRefresh = phase == ApiLogItem.phaseRefresh;
    final color = isRefresh ? MonitorColors.refreshPhase : MonitorColors.initPhase;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
      child: Text(phase,
          style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.bold)),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  final String method;
  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final isGet = method == 'GET';
    final color = isGet ? MonitorColors.methodGet : MonitorColors.methodPost;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(method, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

class _DurationLabel extends StatelessWidget {
  final int duration;
  final bool isSlow;
  final Color color;
  const _DurationLabel({required this.duration, required this.isSlow, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${duration}ms',
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
        if (isSlow)
          const Text('⚠ SLOW',
              style: TextStyle(
                  color: MonitorColors.statusSlow, fontSize: 7, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _CallerRow extends StatelessWidget {
  final String callerName;
  final Color color;
  const _CallerRow({required this.callerName, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.call_made, size: 10, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(callerName,
              style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _CallCountBadge extends StatelessWidget {
  final int count;
  const _CallCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Text(
        '×$count',
        style: const TextStyle(
          color: Color(0xFFB45309),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _SlowBanner extends StatelessWidget {
  final int duration;
  const _SlowBanner({required this.duration});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: MonitorColors.slowBannerBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: MonitorColors.slowBannerBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: MonitorColors.statusSlow, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Warning: Operation took ${(duration / 1000).toStringAsFixed(2)}s — risk of UI jank.',
              style: const TextStyle(
                  color: MonitorColors.statusSlow, fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timeStr;
  final Color color;
  final bool isFirst;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.timeStr,
    required this.color,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: MonitorColors.expandedDetailBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2)),
            ),
            if (!isLast) Container(width: 2, height: 32, color: MonitorColors.border),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: MonitorColors.primaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(color: MonitorColors.secondaryText, fontSize: 10)),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Text(timeStr,
            style: const TextStyle(
                color: MonitorColors.secondaryText,
                fontSize: 10.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _LogFooter extends StatelessWidget {
  final ApiLogItem log;
  const _LogFooter({required this.log});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${log.screen}  ·  ${log.phase}',
            style: const TextStyle(
                color: MonitorColors.secondaryText,
                fontSize: 10,
                fontFamily: 'monospace'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        if (log.hasCallerName) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.call_made, size: 10, color: MonitorColors.callerName),
              const SizedBox(width: 4),
              Expanded(
                child: SelectionArea(
                  child: Text(log.callerName,
                      style: const TextStyle(
                          color: MonitorColors.callerName,
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
