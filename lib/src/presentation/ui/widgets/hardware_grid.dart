import 'package:flutter/material.dart';

import '../../controller/monitor_controller.dart';
import '../theme/monitor_theme.dart';

class MonitorHardwareGrid extends StatelessWidget {
  final String currentScreen;
  const MonitorHardwareGrid({super.key, required this.currentScreen});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MonitorController.instance,
      builder: (context, _) {
        final ctrl = MonitorController.instance;
        final samples = ctrl.ramHistoryMap[currentScreen] ?? [];
        final ramUsed =
            samples.isNotEmpty ? samples.last : ctrl.currentRam;
        final ramTotal = ctrl.totalRam;
        final ramRatio =
            (ramUsed / (ramTotal > 0 ? ramTotal : 1.0)).clamp(0.0, 1.0);

        final appStorage = ctrl.appDiskUsed;
        const storageWarnCeil = 500.0;
        final storageRatio = (appStorage / storageWarnCeil).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _HardwareStat(
                  icon: Icons.memory_outlined,
                  iconColor: const Color(0xFF2DD4BF),
                  label: 'RAM',
                  value:
                      '${ramUsed.toStringAsFixed(0)} / ${ramTotal.toStringAsFixed(0)} MB',
                  ratio: ramRatio,
                  barColor: ramRatio > 0.8
                      ? MonitorColors.statusError
                      : const Color(0xFF2DD4BF),
                ),
              ),
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: MonitorColors.border,
              ),
              Expanded(
                child: _HardwareStat(
                  icon: Icons.storage_outlined,
                  iconColor: const Color(0xFF818CF8),
                  label: 'STORAGE',
                  value: '${appStorage.toStringAsFixed(1)} MB',
                  ratio: storageRatio,
                  barColor: storageRatio > 0.8
                      ? MonitorColors.statusError
                      : const Color(0xFF818CF8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HardwareStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final double ratio;
  final Color barColor;

  const _HardwareStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.ratio,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: iconColor),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: iconColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    color: MonitorColors.primaryText,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 3,
            backgroundColor: MonitorColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
