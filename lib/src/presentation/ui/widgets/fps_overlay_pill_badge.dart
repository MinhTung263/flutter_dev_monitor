import 'package:flutter/material.dart';
import '../../controller/monitor_controller.dart';
import '../theme/monitor_theme.dart';

class FpsOverlayPillBadge extends StatefulWidget {
  const FpsOverlayPillBadge({super.key});

  @override
  State<FpsOverlayPillBadge> createState() => _FpsOverlayPillBadgeState();
}

class _FpsOverlayPillBadgeState extends State<FpsOverlayPillBadge>
    with SingleTickerProviderStateMixin {
  static bool _hintShown = false;

  late final AnimationController _hintCtrl;
  late final Animation<double> _hintAnim;

  @override
  void initState() {
    super.initState();
    _hintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _hintAnim = CurvedAnimation(parent: _hintCtrl, curve: Curves.easeInOut);

    if (!_hintShown) {
      _hintShown = true;
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        _hintCtrl.forward().then((_) {
          Future.delayed(const Duration(milliseconds: 2500), () {
            if (mounted) _hintCtrl.reverse();
          });
        });
      });
    }
  }

  @override
  void dispose() {
    _hintCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListenableBuilder(
        listenable: MonitorController.instance,
        builder: (context, _) {
          final ctrl = MonitorController.instance;
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
            fontFamily: 'monospace',
            height: 1.1,
          );
          const TextStyle valStyle = TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            height: 1.1,
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: OverlayLayout.pillW,
                height: OverlayLayout.pillH,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MonitorColors.overlayBg,
                  borderRadius: BorderRadius.circular(8),
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
                    // ── FPS ──────────────────────────────────────────
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
                        Text(fps.toStringAsFixed(1),
                            style: TextStyle(
                                color: fpsColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                height: 1.1)),
                        const SizedBox(width: 1.5),
                        Text('fps',
                            style: TextStyle(
                                color: fpsColor.withValues(alpha: 0.6),
                                fontSize: 7,
                                fontFamily: 'monospace',
                                height: 1.1)),
                        if (jankCount > 0) ...[
                          const SizedBox(width: 4),
                          Text('⚡$jankCount',
                              style: const TextStyle(
                                  color: MonitorColors.overlayGpu,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                  height: 1.1)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1.5),
                    // ── API + MEM ────────────────────────────────────
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('API ',
                            style: lblStyle.copyWith(color: MonitorColors.overlayApi)),
                        Text('$apiCount',
                            style: valStyle.copyWith(color: MonitorColors.overlayApi)),
                        const SizedBox(width: 5),
                        Text('MEM ',
                            style: lblStyle.copyWith(color: MonitorColors.overlayMem)),
                        Text('${memMb.toStringAsFixed(0)}M',
                            style: valStyle.copyWith(color: MonitorColors.overlayMem)),
                      ],
                    ),
                    const SizedBox(height: 1),
                    // ── NET ──────────────────────────────────────────
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('NET ', style: lblStyle.copyWith(color: pingColor)),
                        Text(pingMs == null ? '--' : '${pingMs}ms',
                            style: valStyle.copyWith(color: pingColor)),
                      ],
                    ),
                    SizeTransition(
                      sizeFactor: _hintAnim,
                      axisAlignment: 1,
                      child: FadeTransition(
                        opacity: _hintAnim,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.touch_app_outlined,
                                  size: 8, color: Colors.white54),
                              SizedBox(width: 3),
                              Text('hold to open',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 6.5,
                                    fontFamily: 'monospace',
                                    height: 1.1,
                                  )),
                            ],
                          ),
                        ),
                      ),
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
                       border: Border.all(color: MonitorColors.overlayBg, width: 1.2),
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
                        fontFamily: 'monospace',
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
