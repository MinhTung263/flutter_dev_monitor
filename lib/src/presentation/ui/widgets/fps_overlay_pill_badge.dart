import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/monitor_strings.dart';
import '../../controller/monitor_controller.dart';
import '../theme/monitor_theme.dart';

class FpsOverlayPillBadge extends StatelessWidget {
  const FpsOverlayPillBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: ListenableBuilder(
          listenable: MonitorController.instance,
          builder: (context, _) {
            final ctrl = MonitorController.instance;
            final rawModel = ctrl.deviceModel.isNotEmpty
                ? ctrl.deviceModel
                : (Platform.isIOS ? 'iPhone' : 'Android');
            final parts = rawModel.split(' • ');
            final deviceName = parts.first;
            final osVersion = parts.length > 1
                ? parts.last
                    .replaceAll('iOS ', '')
                    .replaceAll('Android ', '')
                    .trim()
                : '';

            final fps = ctrl.currentFps;
            final isIdle = ctrl.isIdle;
            final memMb = ctrl.currentRam;
            final totalRamMb = ctrl.totalRam;
            final initCount = ctrl.initApiCount;
            final actionCount = ctrl.refreshApiCount;
            final jankCount = ctrl.jankFrameCount;
            final bigJankCount = ctrl.bigJankFrameCount;
            final pingMs = ctrl.currentPingMs;
            final jank = !isIdle && fps < 50 && fps > 0;
            final fpsColor = isIdle
                ? const Color(0xFF34D399).withValues(alpha: 0.85)
                : (jank ? const Color(0xFFF87171) : const Color(0xFF34D399));
            final pingColor = pingMs == null
                ? Colors.white38
                : pingMs < 50
                    ? const Color(0xFF34D399)
                    : pingMs < 150
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFF87171);

            final apiErr = ctrl.globalApiErrorCount;
            final flutterErr = ctrl.flutterErrorCount;
            final totalErr = apiErr + flutterErr;
            final slowApi = ctrl.globalSlowApiCount;

            final hasError = totalErr > 0;
            final hasSlow = slowApi > 0;
            final showAlert = (hasError || hasSlow) && !ctrl.alertsDismissed;
            final alertColor = hasError
                ? const Color(0xFFF87171)
                : const Color(0xFFFBBF24);

            const TextStyle lblStyle = TextStyle(
              fontSize: 6.2,
              fontWeight: FontWeight.w700,
              fontFamily: MonitorTextStyle.monoFontFamily,
              height: 1.05,
            );
            const TextStyle valStyle = TextStyle(
              fontSize: 7.8,
              fontWeight: FontWeight.w900,
              fontFamily: MonitorTextStyle.monoFontFamily,
              height: 1.05,
            );

            final Color jankBadgeColor = bigJankCount > 0
                ? const Color(0xFFF87171)
                : const Color(0xFFFBBF24);
            final Color borderGlow = showAlert
                ? alertColor
                : const Color(0xFF38BDF8);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: OverlayLayout.pillW,
                  height: OverlayLayout.pillH,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xF50B1120),
                        Color(0xF50F172A),
                        Color(0xF5070B14),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: borderGlow.withValues(alpha: showAlert ? 0.70 : 0.42),
                      width: 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: borderGlow.withValues(alpha: showAlert ? 0.28 : 0.16),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        // Futuristic left neon telemetry rail
                        Container(
                          width: 2.5,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                fpsColor,
                                const Color(0xFF38BDF8),
                                showAlert ? alertColor : const Color(0xFFA855F7),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(5.5, 3, 6, 3),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── ROW 1: CYBER DEVICE HEADER ─────────────
                                Row(
                                  children: [
                                    Icon(
                                      Icons.memory_rounded,
                                      size: 7.5,
                                      color: const Color(0xFF38BDF8)
                                          .withValues(alpha: 0.85),
                                    ),
                                    const SizedBox(width: 2.5),
                                    Expanded(
                                      child: Text(
                                        deviceName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.90),
                                          fontSize: 6.6,
                                          fontWeight: FontWeight.w800,
                                          fontFamily:
                                              MonitorTextStyle.monoFontFamily,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                    if (osVersion.isNotEmpty) ...[
                                      const SizedBox(width: 2),
                                      Text(
                                        osVersion,
                                        style: TextStyle(
                                          color: const Color(0xFF38BDF8)
                                              .withValues(alpha: 0.70),
                                          fontSize: 5.8,
                                          fontWeight: FontWeight.w700,
                                          fontFamily:
                                              MonitorTextStyle.monoFontFamily,
                                          height: 1.0,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                // ── ROW 2: NEON FPS + JANK PILL ────────────
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 4.5,
                                        height: 4.5,
                                        decoration: BoxDecoration(
                                          color: fpsColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: fpsColor.withValues(
                                                  alpha: 0.6),
                                              blurRadius: 3,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        isIdle
                                            ? fps.toStringAsFixed(0)
                                            : fps.toStringAsFixed(1),
                                        style: TextStyle(
                                          color: fpsColor,
                                          fontSize: 9.8,
                                          fontWeight: FontWeight.w900,
                                          fontFamily:
                                              MonitorTextStyle.monoFontFamily,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        isIdle
                                            ? LocaleKeys.overlayIdleLabel.tr
                                            : LocaleKeys.overlayFpsLabel.tr,
                                        style: TextStyle(
                                          color:
                                              fpsColor.withValues(alpha: 0.70),
                                          fontSize: 6.2,
                                          fontWeight: FontWeight.w700,
                                          fontFamily:
                                              MonitorTextStyle.monoFontFamily,
                                          height: 1.0,
                                        ),
                                      ),
                                      if (jankCount > 0) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 3.5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: jankBadgeColor.withValues(
                                                alpha: 0.16),
                                            borderRadius:
                                                BorderRadius.circular(3),
                                            border: Border.all(
                                              color: jankBadgeColor.withValues(
                                                  alpha: 0.50),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Text(
                                            'Jank $jankCount',
                                            style: TextStyle(
                                              color: jankBadgeColor,
                                              fontSize: 6.2,
                                              fontWeight: FontWeight.w800,
                                              fontFamily: MonitorTextStyle
                                                  .monoFontFamily,
                                              height: 1.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // ── ROW 3: API HUD CAPSULES (MỞ vs THAO TÁC)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'API ',
                                        style: lblStyle.copyWith(
                                          color: const Color(0xFF38BDF8),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 3, vertical: 0.8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFB923C)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(2.5),
                                          border: Border.all(
                                            color: const Color(0xFFFB923C)
                                                .withValues(alpha: 0.40),
                                            width: 0.4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Mở:',
                                              style: lblStyle.copyWith(
                                                color: Colors.white
                                                    .withValues(alpha: 0.78),
                                              ),
                                            ),
                                            Text(
                                              '$initCount',
                                              style: valStyle.copyWith(
                                                color: const Color(0xFFFB923C),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 2.5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 3, vertical: 0.8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF34D399)
                                              .withValues(
                                                  alpha: actionCount > 0
                                                      ? 0.16
                                                      : 0.07),
                                          borderRadius:
                                              BorderRadius.circular(2.5),
                                          border: Border.all(
                                            color: const Color(0xFF34D399)
                                                .withValues(
                                                    alpha: actionCount > 0
                                                        ? 0.45
                                                        : 0.22),
                                            width: 0.4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Thao tác:',
                                              style: lblStyle.copyWith(
                                                color: Colors.white
                                                    .withValues(alpha: 0.78),
                                              ),
                                            ),
                                            Text(
                                              '$actionCount',
                                              style: valStyle.copyWith(
                                                color: actionCount > 0
                                                    ? const Color(0xFF34D399)
                                                    : Colors.white.withValues(
                                                        alpha: 0.50),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // ── ROW 4: RAM & NET PING ──────────────────
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'RAM ',
                                        style: lblStyle.copyWith(
                                          color: const Color(0xFFF472B6),
                                        ),
                                      ),
                                      Text(
                                        totalRamMb > 0
                                            ? '${memMb.toStringAsFixed(0)}M/${(totalRamMb / 1024.0).toStringAsFixed(0)}G'
                                            : '${memMb.toStringAsFixed(0)}M',
                                        style: valStyle.copyWith(
                                          color: const Color(0xFFF472B6),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'NET ',
                                        style:
                                            lblStyle.copyWith(color: pingColor),
                                      ),
                                      Text(
                                        pingMs == null ? '--' : '${pingMs}ms',
                                        style:
                                            valStyle.copyWith(color: pingColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (showAlert)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 14,
                      height: 14,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: alertColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: MonitorColors.overlayBg, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: alertColor.withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          fontFamily: MonitorTextStyle.monoFontFamily,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
