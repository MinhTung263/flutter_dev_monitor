import 'package:flutter/material.dart';

import '../../controller/monitor_controller.dart';
import '../theme/monitor_theme.dart';
import 'monitor_text.dart';

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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _PhasePill(
                    label: 'OPEN',
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
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _ErrorPill(count: screenErrorCount)),
                  const SizedBox(width: 8),
                  Expanded(child: _JankPill(count: ctrl.jankFrameCount)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _RamPill(
                          ramMb: ctrl.currentRam, totalMb: ctrl.totalRam)),
                ],
              ),
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
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          LabelText('ERRORS', color.withValues(alpha: 0.7)),
          const SizedBox(height: 3),
          MonoText('$count', 12, color: color, weight: FontWeight.bold),
        ],
      ),
    );
  }
}

class _RamPill extends StatelessWidget {
  final double ramMb;
  final double totalMb;
  const _RamPill({required this.ramMb, required this.totalMb});

  @override
  Widget build(BuildContext context) {
    const kRamColor = Color(0xFFF472B6);
    final isHigh = totalMb > 0 && ramMb > totalMb * 0.8;
    final color = isHigh ? MonitorColors.statusError : kRamColor;
    final label = ramMb < 1 ? '--' : '${ramMb.toStringAsFixed(0)}M';

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
          LabelText('RAM', color.withValues(alpha: 0.7)),
          const SizedBox(height: 3),
          MonoText(label, 12, color: color, weight: FontWeight.bold),
        ],
      ),
    );
  }
}

class _JankPill extends StatelessWidget {
  final int count;
  const _JankPill({required this.count});

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
