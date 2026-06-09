import 'dart:io' show Platform;
import 'dart:ui' show FramePhase;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/monitor_constants.dart';
import '../../controller/monitor_controller.dart';
import '../../navigation/monitor_navigator_observer.dart';
import '../pages/monitor_dashboard_page.dart';
import '../theme/monitor_theme.dart';

class FpsOverlay extends StatefulWidget {
  final Widget child;
  final bool isShowing;
  final bool expandedByDefault;
  final VoidCallback? onHide;

  const FpsOverlay({
    super.key,
    required this.child,
    this.isShowing = true,
    this.expandedByDefault = false,
    this.onHide,
  });

  @override
  State<FpsOverlay> createState() => _FpsOverlayState();
}

class _FpsOverlayState extends State<FpsOverlay>
    with SingleTickerProviderStateMixin {
  // ── Frame timing ──────────────────────────────────────────────────────
  final List<Duration> _vsyncHistory = [];
  double _buildAccumMs = 0.0;
  double _gpuAccumMs = 0.0;
  int _timingBatchCount = 0;
  bool _isListening = false;

  double _pendingFps = 0.0;
  double _pendingBuild = 0.0;
  double _pendingGpu = 0.0;

  Ticker? _ticker;
  Duration _lastPublish = Duration.zero;

  // ── Overlay position & state ─────────────────────────────────────────
  double? _top;
  double? _left;
  bool _positionInit = false;
  late bool _isExpanded;

  MonitorController get _ctrl => MonitorController.instance;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.expandedByDefault;
    _manageListening();
  }

  @override
  void didUpdateWidget(FpsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isShowing != widget.isShowing) _manageListening();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    if (_isListening) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    super.dispose();
  }

  void _manageListening() {
    if (widget.isShowing && !_isListening) {
      _isListening = true;
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      if (_ticker == null) {
        _ticker = createTicker(_onTick)..start();
      } else {
        _ticker!.start();
      }
    } else if (!widget.isShowing && _isListening) {
      _isListening = false;
      _isExpanded = false;
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _ticker?.stop();
      _vsyncHistory.clear();
      _buildAccumMs = 0.0;
      _gpuAccumMs = 0.0;
      _timingBatchCount = 0;
      _pendingFps = 0.0;
      _pendingBuild = 0.0;
      _pendingGpu = 0.0;
      _lastPublish = Duration.zero;
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted || _pendingFps <= 0) return;
    if ((elapsed - _lastPublish).inMilliseconds < 100) return;
    _lastPublish = elapsed;

    final route = MonitorNavigatorObserver.currentRoute;
    _ctrl.addFpsSample(route.isEmpty ? '/init' : route, _pendingFps);
    _ctrl.notifyFpsUpdate(_pendingFps, _pendingBuild, _pendingGpu);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted) return;

    for (final t in timings) {
      _vsyncHistory.add(Duration(
          microseconds: t.timestampInMicroseconds(FramePhase.buildStart)));
      final buildUs = t.buildDuration.inMicroseconds;
      final rasterUs = t.rasterDuration.inMicroseconds;
      // Count frames that exceed 16.67ms budget (60fps threshold)
      if (buildUs + rasterUs > 16667) {
        _ctrl.recordJankFrame();
      }
      final buildMs = buildUs / 1000.0;
      if (buildMs >= 0.5) {
        _buildAccumMs += buildMs;
        _gpuAccumMs += rasterUs / 1000.0;
        _timingBatchCount++;
      }
    }

    if (_vsyncHistory.length > 90) {
      _vsyncHistory.removeRange(0, _vsyncHistory.length - 90);
    }

    if (_vsyncHistory.length < 3) return;

    final spanUs =
        (_vsyncHistory.last - _vsyncHistory.first).inMicroseconds.toDouble();
    if (spanUs < 120000) return;

    final fps = ((_vsyncHistory.length - 1) * 1e6 / spanUs).clamp(0.0, 120.0);
    final avgBuild =
        _timingBatchCount > 0 ? _buildAccumMs / _timingBatchCount : 0.0;
    final avgGpu =
        _timingBatchCount > 0 ? _gpuAccumMs / _timingBatchCount : 0.0;

    if (fps >= 1.0) {
      _pendingFps = fps;
      _pendingBuild = avgBuild;
      _pendingGpu = avgGpu;
      _ctrl.addOverlaySamples(fps, avgGpu, avgBuild);
    }

    _buildAccumMs = 0.0;
    _gpuAccumMs = 0.0;
    _timingBatchCount = 0;
  }

  void _onExpandPanel() => setState(() => _isExpanded = true);

  void _onCollapse() {
    final sw = MediaQuery.of(context).size.width;
    setState(() {
      _isExpanded = false;
      _left = sw - OverlayLayout.pillW - OverlayLayout.edgeMargin;
    });
  }

  void _onOpenDashboard() {
    final nav = MonitorNavigatorObserver.navigatorState;
    if (nav == null) return;
    if (MonitorNavigatorObserver.currentRoute ==
        MonitorConstants.dashboardRoute) return;
    final route = MonitorNavigatorObserver.currentRoute;
    nav.push(MaterialPageRoute(
      builder: (_) => MonitorDashboardPage(
          initialScreen: route.isEmpty ? '/unknown' : route),
      settings: const RouteSettings(name: '/MonitorDashboardPage'),
    ));
    if (mounted) {
      setState(() {
        _isExpanded = false;
        _top = MediaQuery.of(context).padding.top + 60;
      });
    }
  }

  void _onClearData() {
    _ctrl.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isShowing) return widget.child;

    if (!_positionInit) {
      final size = MediaQuery.of(context).size;
      final padding = MediaQuery.of(context).padding;
      _top = padding.top + OverlayLayout.edgeMargin;
      _left = size.width - OverlayLayout.pillW - OverlayLayout.edgeMargin;
      _positionInit = true;
    }

    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final sh = mq.size.height;
    final pad = mq.padding;
    final w = _isExpanded ? OverlayLayout.expandedW : OverlayLayout.pillW;
    final h = _isExpanded ? OverlayLayout.expandedH : OverlayLayout.pillH;
    final minLeft = OverlayLayout.edgeMargin;
    final maxLeft = sw - w - OverlayLayout.edgeMargin;
    final minTop = pad.top + OverlayLayout.edgeMargin;
    final maxTop = sh - pad.bottom - h - OverlayLayout.edgeMargin;

    _left = (_left ?? minLeft).clamp(minLeft, maxLeft.clamp(minLeft, sw - w));
    _top = (_top ?? minTop).clamp(minTop, maxTop.clamp(minTop, sh));

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: _top,
          left: _left,
          child: GestureDetector(
            onPanUpdate: (d) {
              final mq = MediaQuery.of(context);
              final sw = mq.size.width;
              final sh = mq.size.height;
              final pad = mq.padding;
              final w =
                  _isExpanded ? OverlayLayout.expandedW : OverlayLayout.pillW;
              final h =
                  _isExpanded ? OverlayLayout.expandedH : OverlayLayout.pillH;
              setState(() {
                _top = ((_top ?? 0) + d.delta.dy).clamp(
                  pad.top + OverlayLayout.edgeMargin,
                  sh - pad.bottom - h - OverlayLayout.edgeMargin,
                );
                _left = ((_left ?? 0) + d.delta.dx).clamp(
                  OverlayLayout.edgeMargin,
                  sw - w - OverlayLayout.edgeMargin,
                );
              });
            },
            onTap: _isExpanded
                ? _onCollapse
                : MonitorNavigatorObserver.currentRoute ==
                        MonitorConstants.dashboardRoute
                    ? null
                    : _onOpenDashboard,
            onLongPress: _isExpanded ? null : _onExpandPanel,
            child: _isExpanded
                ? _DetailsPanel(
                    onCollapse: _onCollapse,
                    onHide: widget.onHide,
                    onOpenDashboard: _onOpenDashboard,
                    onClear: _onClearData,
                  )
                : const _PillBadge(),
          ),
        ),
      ],
    );
  }
}

// ─── Collapsed pill badge ─────────────────────────────────────────────────────

class _PillBadge extends StatefulWidget {
  const _PillBadge();

  @override
  State<_PillBadge> createState() => _PillBadgeState();
}

class _PillBadgeState extends State<_PillBadge>
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

          const TextStyle _lbl = TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            height: 1.2,
          );
          const TextStyle _val = TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            height: 1.2,
          );

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: MonitorColors.overlayBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: fpsColor.withValues(alpha: 0.45), width: 0.8),
              boxShadow: [
                BoxShadow(
                    color: fpsColor.withValues(alpha: 0.15), blurRadius: 6),
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
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 1),
                      decoration: BoxDecoration(
                          color: fpsColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(fps.toStringAsFixed(1),
                        style: TextStyle(
                            color: fpsColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            height: 1.1)),
                    const SizedBox(width: 2),
                    Text('fps',
                        style: TextStyle(
                            color: fpsColor.withValues(alpha: 0.6),
                            fontSize: 8,
                            fontFamily: 'monospace',
                            height: 1.1)),
                    if (jankCount > 0) ...[
                      const SizedBox(width: 5),
                      Text('⚡$jankCount',
                          style: const TextStyle(
                              color: MonitorColors.overlayGpu,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              height: 1.1)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                // ── API + MEM ────────────────────────────────────
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('API ',
                        style: _lbl.copyWith(color: MonitorColors.overlayApi)),
                    Text('$apiCount',
                        style: _val.copyWith(color: MonitorColors.overlayApi)),
                    const SizedBox(width: 6),
                    Text('MEM ',
                        style: _lbl.copyWith(color: MonitorColors.overlayMem)),
                    Text('${memMb.toStringAsFixed(0)}M',
                        style: _val.copyWith(color: MonitorColors.overlayMem)),
                  ],
                ),
                const SizedBox(height: 2),
                // ── NET ──────────────────────────────────────────
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('NET ', style: _lbl.copyWith(color: pingColor)),
                    Text(pingMs == null ? '--' : '${pingMs}ms',
                        style: _val.copyWith(color: pingColor)),
                  ],
                ),
                SizeTransition(
                  sizeFactor: _hintAnim,
                  axisAlignment: 1,
                  child: FadeTransition(
                    opacity: _hintAnim,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.touch_app_outlined,
                              size: 9, color: Colors.white54),
                          SizedBox(width: 4),
                          Text('hold to open',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 7,
                                fontFamily: 'monospace',
                                height: 1.2,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Expanded details panel ───────────────────────────────────────────────────

class _DetailsPanel extends StatelessWidget {
  final VoidCallback onCollapse;
  final VoidCallback? onHide;
  final VoidCallback onOpenDashboard;
  final VoidCallback onClear;

  const _DetailsPanel({
    required this.onCollapse,
    this.onHide,
    required this.onOpenDashboard,
    required this.onClear,
  });

  static const _cFps = MonitorColors.overlayFps;
  static const _cJank = MonitorColors.overlayAlert;
  static const _cGpu = MonitorColors.overlayGpu;
  static const _cBuild = MonitorColors.overlayBuild;
  static const _cMem = MonitorColors.overlayMem;
  static const _cApi = MonitorColors.overlayApi;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final dpr = mq.devicePixelRatio;
    final physW = (mq.size.width * dpr).round();
    final physH = (mq.size.height * dpr).round();
    final ctrl = MonitorController.instance;
    final rawModel = ctrl.deviceModel.isNotEmpty
        ? ctrl.deviceModel
        : (Platform.isIOS ? 'iPhone' : 'Android');
    final parts = rawModel.split(' • ');
    final deviceName = parts.first;
    final osVersion = parts.length > 1 ? parts.last : '';

    double hz = 60.0;
    try {
      hz = View.of(context).display.refreshRate;
    } catch (_) {}

    return Material(
      color: Colors.transparent,
      child: ListenableBuilder(
        listenable: Listenable.merge([ctrl, MonitorColors.isDarkNotifier]),
        builder: (context, _) {
          final fps = ctrl.currentFps;
          final buildMs = ctrl.currentBuildMs;
          final gpuMs = ctrl.currentGpuMs;
          final memMb = ctrl.currentRam;
          final apiCount = ctrl.currentPhaseApiCount;
          final pingMs = ctrl.currentPingMs;

          final fpsHist = List<double>.from(ctrl.overlayFpsHistory);
          final gpuHist = List<double>.from(ctrl.overlayGpuHistory);
          final buildHist = List<double>.from(ctrl.overlayBuildHistory);

          final jank = fps < 50 && fps > 0;

          // Theme-aware colors
          final dark = MonitorColors.isDark;

          // Panel structure
          final panelBg =
              dark ? const Color(0xFF0D0D0D) : const Color(0xFFF1F5F9);
          final panelBorderColor = dark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFCBD5E1);
          final panelBorderW = dark ? 0.5 : 1.0;
          final panelShadow = dark
              ? <BoxShadow>[]
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ];

          // Text
          final infoTxt = dark
              ? Colors.white.withValues(alpha: 0.70)
              : const Color(0xFF334155);
          final subtleTxt = dark
              ? Colors.white.withValues(alpha: 0.35)
              : const Color(0xFF94A3B8);
          final divColor = dark
              ? Colors.white.withValues(alpha: 0.20)
              : const Color(0xFFE2E8F0);
          final btnIconColor = dark
              ? Colors.white.withValues(alpha: 0.80)
              : const Color(0xFF475569);

          // Metric accent colors — darker variants in light mode for readability
          final mFps = dark ? _cFps : const Color(0xFF16A34A);
          final mJank = dark ? _cJank : const Color(0xFFDC2626);
          final mGpu = dark ? _cGpu : const Color(0xFFEA580C);
          final mBuild = dark ? _cBuild : const Color(0xFFD97706);
          final mMem = dark ? _cMem : const Color(0xFFDB2777);
          final mApi = dark ? _cApi : const Color(0xFF2563EB);
          final mFpsActive = jank ? mJank : mFps;

          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 210,
                decoration: BoxDecoration(
                  color: panelBg,
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: panelBorderColor, width: panelBorderW),
                  boxShadow: panelShadow,
                ),
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: device name + resolution
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            deviceName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: infoTxt,
                                fontSize: 9,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                height: 1.2),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '[${physW}×${physH}]',
                          style: TextStyle(
                              color: subtleTxt,
                              fontSize: 8,
                              fontFamily: 'monospace',
                              height: 1.2),
                        ),
                      ],
                    ),
                    // Row 2: OS version + DPR / Hz
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (osVersion.isNotEmpty)
                          Flexible(
                            child: Text(
                              osVersion,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: subtleTxt,
                                  fontSize: 8,
                                  fontFamily: 'monospace',
                                  height: 1.2),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          '${dpr.toStringAsFixed(1)}x  ${hz.round()}Hz',
                          style: TextStyle(
                              color: subtleTxt,
                              fontSize: 8,
                              fontFamily: 'monospace',
                              height: 1.2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Container(height: 0.5, color: divColor),
                    const SizedBox(height: 4),
                    _metricRow('Pre', '${buildMs.toStringAsFixed(2)}ms', mBuild,
                        buildHist, 2),
                    _metricRow('GPU', '${gpuMs.toStringAsFixed(2)}ms', mGpu,
                        gpuHist, 2),
                    _metricRow(
                        'Mem', '${memMb.toStringAsFixed(1)}MB', mMem, [], 1),
                    _metricRow('API', '$apiCount calls', mApi, [], 0),
                    _metricRow(
                        'NET',
                        pingMs == null ? '--' : '${pingMs}ms',
                        pingMs == null
                            ? subtleTxt
                            : pingMs < 50
                                ? mFps
                                : pingMs < 150
                                    ? mBuild
                                    : mJank,
                        [],
                        0),
                    _metricRow(
                        'FPS', fps.toStringAsFixed(2), mFpsActive, fpsHist, 2),
                    const SizedBox(height: 4),
                    Container(height: 0.5, color: divColor),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 28,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _SparklinePainter(
                          fpsHistory: fpsHist,
                          gpuHistory: gpuHist,
                          maxFps: hz,
                          isDark: dark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                      onTap: onCollapse,
                      icon: Icons.close_fullscreen,
                      iconColor: btnIconColor),
                  const SizedBox(height: 10),
                  if (onHide != null) ...[
                    _ActionButton(
                        onTap: onHide!,
                        icon: Icons.close,
                        iconColor:
                            const Color(0xFFFF5555).withValues(alpha: 0.80),
                        borderColor:
                            const Color(0xFFFF5555).withValues(alpha: 0.30)),
                    const SizedBox(height: 10),
                  ],
                  if (MonitorNavigatorObserver.currentRoute !=
                      MonitorConstants.dashboardRoute) ...[
                    _ActionButton(
                        onTap: onOpenDashboard,
                        icon: Icons.fullscreen_exit_rounded,
                        iconColor: btnIconColor),
                    const SizedBox(height: 10),
                  ],
                  _ActionButton(
                      onTap: onClear,
                      icon: Icons.restart_alt,
                      iconColor: MonitorColors.statusError,
                      borderColor:
                          MonitorColors.statusError.withValues(alpha: 0.30)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _metricRow(String label, String value, Color color,
      List<double> history, int decimals) {
    final range = _rangeStr(history, decimals);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        children: [
          Text('$label: ',
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  height: 1.2)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  height: 1.2)),
          if (range.isNotEmpty) ...[
            const Spacer(),
            Text(range,
                style: TextStyle(
                    color: color.withValues(alpha: 0.65),
                    fontSize: 9,
                    fontFamily: 'monospace',
                    height: 1.2)),
          ],
        ],
      ),
    );
  }

  static String _rangeStr(List<double> h, int decimals) {
    if (h.length < 2) return '';
    final mn = h.reduce((a, b) => a < b ? a : b).toStringAsFixed(decimals);
    final mx = h.reduce((a, b) => a > b ? a : b).toStringAsFixed(decimals);
    return '[$mn $mx]';
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final Color? borderColor;

  const _ActionButton(
      {required this.onTap,
      required this.icon,
      required this.iconColor,
      this.borderColor});

  @override
  Widget build(BuildContext context) {
    final dark = MonitorColors.isDark;
    final bg = dark ? const Color(0xFF1A1A1A) : MonitorColors.surface;
    final defaultBorder =
        dark ? Colors.white.withValues(alpha: 0.15) : MonitorColors.border;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: borderColor ?? defaultBorder,
            width: 0.5,
          ),
        ),
        child: Icon(icon, size: 17, color: iconColor),
      ),
    );
  }
}

// ─── Sparkline ────────────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<double> fpsHistory;
  final List<double> gpuHistory;
  final double maxFps;
  final bool isDark;

  const _SparklinePainter({
    required this.fpsHistory,
    required this.gpuHistory,
    required this.maxFps,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final refY = (1 - (60.0 / maxFps).clamp(0.0, 1.0)) * size.height;
    canvas.drawLine(
      Offset(0, refY),
      Offset(size.width, refY),
      Paint()
        ..color =
            isDark ? Colors.white.withValues(alpha: 0.06) : MonitorColors.border
        ..strokeWidth = 0.5,
    );
    _drawFilled(canvas, size, fpsHistory, maxFps, const Color(0xFF4ADE80),
        highIsGood: true);
    _drawLine(canvas, size, gpuHistory, 33.3, const Color(0xFFFB923C),
        highIsGood: true);
  }

  void _drawFilled(
      Canvas canvas, Size size, List<double> data, double maxVal, Color color,
      {required bool highIsGood}) {
    if (data.length < 2) return;
    final n = data.length;
    final stepX = size.width / (n - 1);
    final stroke = Path();
    for (int i = 0; i < n; i++) {
      final x = i * stepX;
      final ratio = (data[i] / maxVal).clamp(0.0, 1.0);
      final y = highIsGood ? (1 - ratio) * size.height : ratio * size.height;
      i == 0 ? stroke.moveTo(x, y) : stroke.lineTo(x, y);
    }
    final fill = Path.from(stroke);
    fill.lineTo((n - 1) * stepX, size.height);
    fill.lineTo(0, size.height);
    fill.close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.28),
              color.withValues(alpha: 0.0)
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.drawPath(
        stroke,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  void _drawLine(
      Canvas canvas, Size size, List<double> data, double maxVal, Color color,
      {required bool highIsGood}) {
    if (data.length < 2) return;
    final n = data.length;
    final stepX = size.width / (n - 1);
    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = i * stepX;
      final ratio = (data[i] / maxVal).clamp(0.0, 1.0);
      final y = highIsGood ? (1 - ratio) * size.height : ratio * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.isDark != isDark ||
      old.fpsHistory.length != fpsHistory.length ||
      (fpsHistory.isNotEmpty &&
          old.fpsHistory.isNotEmpty &&
          old.fpsHistory.last != fpsHistory.last);
}
