import 'package:flutter/material.dart';
import '../theme/monitor_theme.dart';

class FpsOverlayTuckedHandle extends StatelessWidget {
  final bool tuckedLeft;

  const FpsOverlayTuckedHandle({
    super.key,
    required this.tuckedLeft,
  });

  @override
  Widget build(BuildContext context) {
    final dark = MonitorColors.isDark;
    final bg = dark ? const Color(0xDD1E222A) : const Color(0xDDF1F5F9);
    final borderCol = dark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1);
    final iconColor = dark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF475569);

    final radius = tuckedLeft
        ? const BorderRadius.horizontal(right: Radius.circular(8))
        : const BorderRadius.horizontal(left: Radius.circular(8));

    return Container(
      width: 18,
      height: 48,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(color: borderCol, width: 0.8),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                )
              ],
      ),
      child: Center(
        child: Icon(
          tuckedLeft ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
          size: 14,
          color: iconColor,
        ),
      ),
    );
  }
}
