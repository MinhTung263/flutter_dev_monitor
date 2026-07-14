import 'package:flutter/material.dart';

import '../../controller/monitor_controller.dart';
import '../../../core/monitor_strings.dart';
import '../theme/monitor_theme.dart';
import 'monitor_text.dart';

class MonitorMetricsBar extends StatelessWidget {
  final String screen;
  const MonitorMetricsBar({super.key, required this.screen});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MonitorController.instance,
      builder: (context, _) {
        final ctrl = MonitorController.instance;
        final stats = ctrl.screenStats(screen);
        // Both pills show the LATEST occurrence only.
        // Sub-label shows which visit/action number so context is clear.
        final openLabel = stats.visitCount > 1
            ? '${LocaleKeys.initLabel.tr}  #${stats.visitCount}'
            : LocaleKeys.initLabel.tr;
        final actionLabel = stats.actionCycles > 0
            ? '${LocaleKeys.actionLabel.tr}  #${stats.actionCycles}'
            : LocaleKeys.actionLabel.tr;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              _PhasePill(
                label: openLabel,
                count: stats.openCount,
                duration: stats.openMs,
                color: MonitorColors.metricInit,
              ),
              const SizedBox(width: 8),
              _PhasePill(
                label: actionLabel,
                count: stats.actionCount,
                duration: stats.actionMs,
                color: MonitorColors.metricRefresh,
                emptyLabel: '--',
              ),
              const SizedBox(width: 8),
              _JankBadge(count: ctrl.jankFrameCount),
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
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  LabelText(label, color.withValues(alpha: 0.7)),
                  const SizedBox(height: 3),
                  MonoText(durationStr, 12,
                      color: color, weight: FontWeight.bold),
                ],
              ),
            ),
            if (!isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: MonoText('$count API', 9,
                    color: color, weight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}

class _JankBadge extends StatelessWidget {
  final int count;
  const _JankBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final hasJank = count > 0;
    final color =
        hasJank ? MonitorColors.statusSlow : MonitorColors.secondaryText;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          LabelText('JANK', color.withValues(alpha: 0.7)),
          const SizedBox(height: 3),
          MonoText('$count', 12, color: color, weight: FontWeight.bold),
        ],
      ),
    );
  }
}
