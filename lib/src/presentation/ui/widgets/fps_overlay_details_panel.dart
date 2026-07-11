import 'dart:io' show Platform;
import 'package:flutter/material.dart';

import '../../../core/monitor_constants.dart';
import '../../../domain/overlay_state_entity.dart';
import '../../controller/monitor_controller.dart';
import '../../navigation/monitor_navigator_observer.dart';
import '../theme/monitor_theme.dart';

class FpsOverlayDetailsPanel extends StatelessWidget {
  final VoidCallback onCollapse;
  final VoidCallback? onHide;
  final VoidCallback onOpenDashboard;
  final VoidCallback onClear;
  final GridMode gridMode;
  final VoidCallback onToggleGrid;

  const FpsOverlayDetailsPanel({
    super.key,
    required this.onCollapse,
    this.onHide,
    required this.onOpenDashboard,
    required this.onClear,
    required this.gridMode,
    required this.onToggleGrid,
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

    double hz = 60.0;
    try {
      hz = View.of(context).display.refreshRate;
    } catch (_) {}

    return Material(
      color: Colors.transparent,
      child: ListenableBuilder(
        listenable: Listenable.merge([ctrl, MonitorColors.isDarkNotifier]),
        builder: (context, _) {
          final rawModel = ctrl.deviceModel.isNotEmpty
              ? ctrl.deviceModel
              : (Platform.isIOS ? 'iPhone' : 'Android');
          final parts = rawModel.split(' • ');
          final deviceName = parts.first;
          final osVersion = parts.length > 1 ? parts.last : '';

          final fps = ctrl.currentFps;
          final buildMs = ctrl.currentBuildMs;
          final gpuMs = ctrl.currentGpuMs;
          final memMb = ctrl.currentRam;
          final apiCount = ctrl.currentPhaseApiCount;
          final pingMs = ctrl.currentPingMs;

          final apiErr = ctrl.globalApiErrorCount;
          final flutterErr = ctrl.flutterErrorCount;
          final slowApi = ctrl.globalSlowApiCount;

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

          final IconData gridIcon = switch (gridMode) {
            GridMode.off => Icons.grid_off_outlined,
            GridMode.grid8 => Icons.grid_on_outlined,
            GridMode.grid16 => Icons.grid_4x4_outlined,
            GridMode.crosshair => Icons.center_focus_strong,
            GridMode.margins => Icons.filter_frames_outlined,
          };
          final Color gridIconColor = gridMode == GridMode.off
              ? btnIconColor
              : (dark ? const Color(0xFF22D3EE) : const Color(0xFF0891B2));
          final Color? gridBorderColor = gridMode == GridMode.off
              ? null
              : (dark
                  ? const Color(0xFF22D3EE).withValues(alpha: 0.40)
                  : const Color(0xFF0891B2).withValues(alpha: 0.40));

          // Metric accent colors — darker variants in light mode for readability
          final mFps = dark ? _cFps : const Color(0xFF16A34A);
          final mJank = dark ? _cJank : const Color(0xFFDC2626);
          final mGpu = dark ? _cGpu : const Color(0xFFEA580C);
          final mBuild = dark ? _cBuild : const Color(0xFFD97706);
          final mMem = dark ? _cMem : const Color(0xFFDB2777);
          final mApi = dark ? _cApi : const Color(0xFF2563EB);
          final mFpsActive = jank ? mJank : mFps;

          return GestureDetector(
            onTap: onOpenDashboard,
            onLongPress: onCollapse,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 210,
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: panelBorderColor, width: panelBorderW),
                boxShadow: panelShadow,
              ),
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
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
                        '[$physW×$physH]',
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
                  (() {
                    final List<String> alerts = [];
                    if (apiErr > 0) alerts.add('${apiErr}e');
                    if (slowApi > 0) alerts.add('${slowApi}s');
                    final alertText =
                        alerts.isNotEmpty ? ' (⚠️ ${alerts.join('·')})' : '';
                    return _metricRow(
                        'API', '$apiCount calls$alertText', mApi, [], 0);
                  })(),
                  if (flutterErr > 0)
                    _metricRow('ERR', '$flutterErr errors', mJank, [], 0),
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
                  const SizedBox(height: 6),
                  Container(height: 0.5, color: divColor),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PanelActionChip(
                        onTap: onCollapse,
                        icon: Icons.unfold_less_rounded,
                        label: 'Thu nhỏ',
                        color: btnIconColor,
                      ),
                      _PanelActionChip(
                        onTap: onToggleGrid,
                        icon: gridIcon,
                        label: 'Lưới',
                        color: gridIconColor,
                        borderColor: gridBorderColor,
                      ),
                      if (MonitorNavigatorObserver.currentRoute !=
                          MonitorConstants.dashboardRoute)
                        _PanelActionChip(
                          onTap: onOpenDashboard,
                          icon: Icons.dashboard_rounded,
                          label: 'Dash',
                          color: btnIconColor,
                        )
                      else
                        const SizedBox(width: 36),
                      _PanelActionChip(
                        onTap: onClear,
                        icon: Icons.restart_alt,
                        label: 'Reset',
                        color: MonitorColors.statusError,
                        borderColor:
                            MonitorColors.statusError.withValues(alpha: 0.3),
                      ),
                      _PanelActionChip(
                        onTap: onHide ?? () {},
                        icon: Icons.close,
                        label: 'Ẩn',
                        color: onHide == null
                            ? btnIconColor.withValues(alpha: 0.25)
                            : const Color(0xFFFF5555),
                        borderColor: onHide == null
                            ? Colors.transparent
                            : const Color(0xFFFF5555).withValues(alpha: 0.25),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

class _PanelActionChip extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color color;
  final Color? borderColor;

  const _PanelActionChip({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = MonitorColors.isDark;
    final textCol = dark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF475569);
    final bg = dark ? const Color(0xFF191C22) : const Color(0xFFE2E8F0);
    final borderCol = borderColor ??
        (dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 36,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: borderCol, width: 0.5),
              ),
              child: Icon(icon, size: 12, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: textCol,
                fontSize: 6.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
