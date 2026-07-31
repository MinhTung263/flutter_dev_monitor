import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/monitor_strings.dart';
import '../../controller/monitor_controller.dart';
import '../theme/monitor_theme.dart';

class FpsOverlayPillBadge extends StatelessWidget {
  const FpsOverlayPillBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
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
          final osVersion = parts.length > 1 ? parts.last : '';

          final fps = ctrl.currentFps;
          final memMb = ctrl.currentRam;
          final apiCount = ctrl.currentPhaseApiCount;
          final jankCount = ctrl.jankFrameCount;
          final pingMs = ctrl.currentPingMs;
          final jank = fps < 50 && fps > 0;
          final fpsColor =
              jank ? MonitorColors.overlayAlert : MonitorColors.overlayFps;
          final pingColor = pingMs == null
              ? Colors.white24
              : pingMs < 50
                  ? MonitorColors.overlayFps
                  : pingMs < 150
                      ? MonitorColors.overlayBuild
                      : MonitorColors.overlayAlert;

          final apiErr = ctrl.globalApiErrorCount;
          final flutterErr = ctrl.flutterErrorCount;
          final totalErr = apiErr + flutterErr;
          final slowApi = ctrl.globalSlowApiCount;

          final hasError = totalErr > 0;
          final hasSlow = slowApi > 0;
          final showAlert = (hasError || hasSlow) && !ctrl.alertsDismissed;
          final alertColor = hasError
              ? MonitorColors.overlayAlert
              : MonitorColors.overlayBuild;

          const TextStyle lblStyle = TextStyle(
            fontSize: 6.5,
            fontWeight: FontWeight.bold,
            fontFamily: MonitorTextStyle.monoFontFamily,
            height: 1.1,
          );
          const TextStyle valStyle = TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            fontFamily: MonitorTextStyle.monoFontFamily,
            height: 1.1,
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: OverlayLayout.pillW,
                height: OverlayLayout.pillH,
                alignment: Alignment.centerLeft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: MonitorColors.overlayBg,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: showAlert
                          ? alertColor.withValues(alpha: 0.65)
                          : fpsColor.withValues(alpha: 0.45),
                      width: 0.8),
                  boxShadow: [
                    BoxShadow(
                        color: showAlert
                            ? alertColor.withValues(alpha: 0.25)
                            : fpsColor.withValues(alpha: 0.15),
                        blurRadius: 5),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── ROW 1: DEVICE NAME & OS VERSION ──────────────
                    Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 2.0),
                              child: Icon(
                                Icons.smartphone_rounded,
                                size: 8.0,
                                color: Colors.white.withValues(alpha: 0.50),
                              ),
                            ),
                          ),
                          TextSpan(
                            text: deviceName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 7.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: MonitorTextStyle.monoFontFamily,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (osVersion.isNotEmpty) ...[
                      const SizedBox(height: 0.5),
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: Text(
                          osVersion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 6.2,
                            fontWeight: FontWeight.w600,
                            fontFamily: MonitorTextStyle.monoFontFamily,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 1.0),
                    // ── ROW 2: FPS + JANK ────────────────────────────
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 1.5),
                          decoration: BoxDecoration(
                              color: fpsColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 3.5),
                        Text(
                          fps.toStringAsFixed(1),
                          style: TextStyle(
                            color: fpsColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            fontFamily: MonitorTextStyle.monoFontFamily,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 1.5),
                        Text(
                          LocaleKeys.overlayFpsLabel.tr,
                          style: TextStyle(
                            color: fpsColor.withValues(alpha: 0.6),
                            fontSize: 7,
                            fontFamily: MonitorTextStyle.monoFontFamily,
                            height: 1.0,
                          ),
                        ),
                        if (jankCount > 0) ...[
                          const SizedBox(width: 3.5),
                          Text(
                            '⚡$jankCount',
                            style: const TextStyle(
                              color: MonitorColors.overlayGpu,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: MonitorTextStyle.monoFontFamily,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1.0),
                    // ── ROW 3: API + MEM (Grouped together) ─────────
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(LocaleKeys.overlayApiLabel.tr,
                            style: lblStyle.copyWith(
                                color: MonitorColors.overlayApi)),
                        Text('$apiCount',
                            style: valStyle.copyWith(
                                color: MonitorColors.overlayApi)),
                        const SizedBox(width: 5),
                        Text(LocaleKeys.overlayMemLabel.tr,
                            style: lblStyle.copyWith(
                                color: MonitorColors.overlayMem)),
                        Text('${memMb.toStringAsFixed(0)}M',
                            style: valStyle.copyWith(
                                color: MonitorColors.overlayMem)),
                      ],
                    ),
                    const SizedBox(height: 1.0),
                    // ── ROW 4: NET PING ──────────────────────────────
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(LocaleKeys.overlayNetLabel.tr,
                            style: lblStyle.copyWith(color: pingColor)),
                        Text(pingMs == null ? '--' : '${pingMs}ms',
                            style: valStyle.copyWith(color: pingColor)),
                      ],
                    ),
                  ],
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
    );
  }
}
