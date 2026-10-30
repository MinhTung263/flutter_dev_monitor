import 'package:flutter/material.dart';

import '../../controller/monitor_controller.dart';
import '../../../core/monitor_filter_keys.dart';
import '../../../core/monitor_strings.dart';
import '../theme/monitor_theme.dart';
import 'monitor_text.dart';

class MonitorMetricsBar extends StatelessWidget {
  final String screen;
  final String? activeFilter;
  final ValueChanged<String>? onFilterChanged;

  const MonitorMetricsBar({
    super.key,
    required this.screen,
    this.activeFilter,
    this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MonitorController.instance,
      builder: (context, _) {
        final ctrl = MonitorController.instance;
        final stats = ctrl.screenStats(screen);
        final openLabel = stats.visitCount > 1
            ? '${LocaleKeys.initLabel.tr} #${stats.visitCount}'
            : LocaleKeys.initLabel.tr;
        final actionLabel = stats.actionCycles > 0
            ? '${LocaleKeys.actionLabel.tr} #${stats.actionCycles}'
            : LocaleKeys.actionLabel.tr;
        final isLoadActive = activeFilter == MonitorFilterKeys.load;
        final isActionActive = activeFilter == MonitorFilterKeys.interaction;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              _PhasePill(
                label: openLabel,
                count: stats.openCount,
                duration: stats.openMs,
                color: MonitorColors.metricInit,
                active: isLoadActive,
                onTap: onFilterChanged != null
                    ? () => onFilterChanged!(
                          isLoadActive
                              ? MonitorFilterKeys.all
                              : MonitorFilterKeys.load,
                        )
                    : null,
              ),
              const SizedBox(width: 8),
              _PhasePill(
                label: actionLabel,
                count: stats.actionCount,
                duration: stats.actionMs,
                color: MonitorColors.metricRefresh,
                emptyLabel: '--',
                active: isActionActive,
                onTap: onFilterChanged != null
                    ? () => onFilterChanged!(
                          isActionActive
                              ? MonitorFilterKeys.all
                              : MonitorFilterKeys.interaction,
                        )
                    : null,
              ),
              const SizedBox(width: 8),
              _JankBadge(
                count: ctrl.jankFrameCount,
                bigJank: ctrl.bigJankFrameCount,
                stutter: ctrl.stutterRate,
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
  final bool active;
  final VoidCallback? onTap;

  const _PhasePill({
    required this.label,
    required this.count,
    required this.duration,
    required this.color,
    this.emptyLabel,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = count == 0;
    final durationStr = isEmpty ? (emptyLabel ?? '--') : fmtDuration(duration);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
          decoration: BoxDecoration(
            color:
                active ? color.withValues(alpha: 0.16) : MonitorColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.7)
                  : color.withValues(alpha: 0.28),
              width: active ? 1.2 : 0.8,
            ),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: LabelText(
                      label,
                      color.withValues(alpha: 0.9),
                      size: 8.5,
                      spacing: 0.3,
                    ),
                  ),
                  if (!isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: MonoText(
                        '$count API',
                        8.5,
                        color: color,
                        weight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              MonoText(
                durationStr,
                12.5,
                color: MonitorColors.primaryText,
                weight: FontWeight.bold,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JankBadge extends StatelessWidget {
  final int count;
  final int bigJank;
  final double stutter;

  const _JankBadge({
    required this.count,
    this.bigJank = 0,
    this.stutter = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final hasJank = count > 0;
    final hasBigJank = bigJank > 0;
    final color = hasBigJank
        ? MonitorColors.statusError
        : (hasJank ? MonitorColors.statusSlow : MonitorColors.secondaryText);

    final jankText = hasBigJank ? '$count (!$bigJank)' : '$count';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: BoxDecoration(
        color: MonitorColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              LabelText(
                stutter > 0
                    ? '${LocaleKeys.overlayJankLabel.tr.toUpperCase()} · ${stutter.toStringAsFixed(0)}%'
                    : LocaleKeys.overlayJankLabel.tr.toUpperCase(),
                color.withValues(alpha: 0.9),
                size: 8.5,
                spacing: 0.3,
              ),
            ],
          ),
          const SizedBox(height: 4),
          MonoText(
            jankText,
            12.5,
            color: hasBigJank || hasJank ? color : MonitorColors.primaryText,
            weight: FontWeight.bold,
          ),
        ],
      ),
    );
  }
}
