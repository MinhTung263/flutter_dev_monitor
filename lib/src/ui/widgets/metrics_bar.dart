import 'package:flutter/material.dart';

import '../../controller/monitor_controller.dart';
import '../theme/monitor_theme.dart';

class MonitorMetricsBar extends StatelessWidget {
  final int screenErrorCount;

  const MonitorMetricsBar({super.key, required this.screenErrorCount});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MonitorController.instance,
      builder: (context, _) {
        final ctrl = MonitorController.instance;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _PhasePill(
                label: 'INIT',
                count: ctrl.initApiCount,
                duration: ctrl.initTotalDuration,
                color: MonitorColors.metricInit,
              ),
              const SizedBox(width: 8),
              _PhasePill(
                label: 'ACTION',
                count: ctrl.totalRefreshApiCount,
                duration: ctrl.totalRefreshDuration,
                color: MonitorColors.metricRefresh,
                emptyLabel: '--',
              ),
              const SizedBox(width: 8),
              _ErrorPill(count: screenErrorCount),
            ],
          ),
        );
      },
    );
  }
}

class _PhasePill extends StatelessWidget {
  final String label;
  final int count;
  final int duration;
  final Color color;
  final String? emptyLabel;

  const _PhasePill({
    required this.label,
    required this.count,
    required this.duration,
    required this.color,
    this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = count == 0;
    final durationStr = isEmpty ? (emptyLabel ?? '--') : fmtDuration(duration);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: color.withValues(alpha: 0.7),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 3),
                  Text(durationStr,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
            if (!isEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count API',
                    style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPill extends StatelessWidget {
  final int count;
  const _ErrorPill({required this.count});

  @override
  Widget build(BuildContext context) {
    final hasError = count > 0;
    final color =
        hasError ? MonitorColors.statusError : MonitorColors.secondaryText;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ERRORS',
              style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4)),
          const SizedBox(height: 3),
          Text('$count',
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
