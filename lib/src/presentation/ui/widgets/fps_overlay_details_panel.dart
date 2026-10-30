import 'dart:io' show Platform;
import 'package:flutter/material.dart';

import '../../../core/monitor_constants.dart';
import '../../../core/monitor_strings.dart';
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
  static const _cRom = Color(0xFF38BDF8);
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
          final initCount = ctrl.initApiCount;
          final actionCount = ctrl.refreshApiCount;
          final pingMs = ctrl.currentPingMs;

          final apiErr = ctrl.globalApiErrorCount;
          final flutterErr = ctrl.flutterErrorCount;
          final slowApi = ctrl.globalSlowApiCount;

          final fpsHist = List<double>.from(ctrl.overlayFpsHistory);
          final gpuHist = List<double>.from(ctrl.overlayGpuHistory);
          final buildHist = List<double>.from(ctrl.overlayBuildHistory);

          final jank = fps < 50 && fps > 0;
          final hasAlert = apiErr > 0 || flutterErr > 0 || jank;

          // Theme-aware palette
          final dark = MonitorColors.isDark;

          final panelGradient = dark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xF50B1120),
                    Color(0xF50F172A),
                    Color(0xF5111827),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFAFFFFFF),
                    Color(0xFAF8FAFC),
                    Color(0xFAF1F5F9),
                  ],
                );

          final sectionBg = dark
              ? const Color(0xFF1E293B).withValues(alpha: 0.55)
              : const Color(0xFFE2E8F0).withValues(alpha: 0.55);
          final sectionBorder = dark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFCBD5E1).withValues(alpha: 0.85);

          final primaryTxt =
              dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
          final secondaryTxt =
              dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
          final subtleTxt =
              dark ? const Color(0xFF64748B) : const Color(0xFF64748B);
          final btnIconColor =
              dark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

          // Metric accent colors — vivid in dark mode, high-contrast in light mode
          final mFps = dark ? _cFps : const Color(0xFF10B981);
          final mJank = dark ? _cJank : const Color(0xFFEF4444);
          final mGpu = dark ? _cGpu : const Color(0xFFF97316);
          final mBuild = dark ? _cBuild : const Color(0xFFD97706);
          final mMem = dark ? _cMem : const Color(0xFFEC4899);
          final mRom = dark ? _cRom : const Color(0xFF0284C7);
          final mApi = dark ? _cApi : const Color(0xFF2563EB);
          final mInit =
              dark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
          final mAction =
              dark ? const Color(0xFF34D399) : const Color(0xFF059669);
          final mFpsActive = jank ? mJank : mFps;

          final accentGlow = hasAlert
              ? mJank
              : (dark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7));

          final panelBorderColor = dark
              ? accentGlow.withValues(alpha: hasAlert ? 0.45 : 0.28)
              : (hasAlert
                  ? mJank.withValues(alpha: 0.40)
                  : const Color(0xFFCBD5E1));

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
                  ? const Color(0xFF22D3EE).withValues(alpha: 0.50)
                  : const Color(0xFF0891B2).withValues(alpha: 0.45));

          return GestureDetector(
            onTap: onOpenDashboard,
            onLongPress: onCollapse,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: OverlayLayout.expandedW,
              decoration: BoxDecoration(
                gradient: panelGradient,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: panelBorderColor, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: dark ? 0.50 : 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                  if (dark)
                    BoxShadow(
                      color: accentGlow.withValues(alpha: 0.10),
                      blurRadius: 12,
                      spreadRadius: 0.5,
                    ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Cyber Telemetry Rail
                  Container(
                    height: 2.5,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: hasAlert
                            ? [
                                mJank,
                                const Color(0xFFF59E0B),
                                mJank.withValues(alpha: 0.2),
                              ]
                            : [
                                mFps,
                                const Color(0xFF38BDF8),
                                const Color(0xFF818CF8).withValues(alpha: 0.3),
                              ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 1. HEADER: Device Info & Display Specs ──────────
                        Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: accentGlow.withValues(
                                    alpha: dark ? 0.16 : 0.10),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: accentGlow.withValues(alpha: 0.30),
                                  width: 0.6,
                                ),
                              ),
                              child: Icon(
                                Platform.isIOS
                                    ? Icons.phone_iphone_rounded
                                    : Icons.smartphone_rounded,
                                size: 11,
                                color: accentGlow,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          deviceName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: primaryTxt,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                            fontFamilyFallback: MonitorTextStyle
                                                .standardFontFallback,
                                            height: 1.1,
                                          ),
                                        ),
                                      ),
                                      if (osVersion.isNotEmpty) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: dark
                                                ? Colors.white
                                                    .withValues(alpha: 0.08)
                                                : const Color(0xFFE2E8F0),
                                            borderRadius:
                                                BorderRadius.circular(3.5),
                                          ),
                                          child: Text(
                                            osVersion,
                                            style: TextStyle(
                                              color: secondaryTxt,
                                              fontSize: 7.2,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: MonitorTextStyle
                                                  .monoFontFamily,
                                              height: 1.1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 1.5),
                                  Text(
                                    '$physW×$physH · ${dpr.toStringAsFixed(1)}x · ${hz.round()}Hz',
                                    style: TextStyle(
                                      color: subtleTxt,
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w600,
                                      fontFamily:
                                          MonitorTextStyle.monoFontFamily,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 5),

                        // ── 2. ACTIVE SCREEN CAPSULE (Vietnamese-safe) ──────
                        (() {
                          final rawScreen =
                              MonitorNavigatorObserver.currentContentRoute;
                          final title =
                              MonitorController.formatRouteName(rawScreen);
                          final rawPath = rawScreen.contains('#')
                              ? rawScreen.split('#').first
                              : rawScreen;
                          final showPath =
                              rawPath.isNotEmpty && rawPath != title;
                          final screenColor = dark
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF0284C7);

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  screenColor.withValues(
                                      alpha: dark ? 0.16 : 0.10),
                                  screenColor.withValues(
                                      alpha: dark ? 0.06 : 0.04),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: screenColor.withValues(alpha: 0.32),
                                width: 0.7,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.layers_rounded,
                                    size: 11, color: screenColor),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: dark
                                          ? const Color(0xFFE0F2FE)
                                          : const Color(0xFF0369A1),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      fontFamilyFallback:
                                          MonitorTextStyle.standardFontFallback,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                                if (showPath) ...[
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      rawPath,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color:
                                            screenColor.withValues(alpha: 0.75),
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w600,
                                        fontFamily:
                                            MonitorTextStyle.monoFontFamily,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        })(),

                        const SizedBox(height: 6),

                        // ── 3. HERO PERFORMANCE & SPARKLINE MODULE ──────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
                          decoration: BoxDecoration(
                            color: sectionBg,
                            borderRadius: BorderRadius.circular(9),
                            border:
                                Border.all(color: sectionBorder, width: 0.7),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Top Row: Hero FPS Gauge + Pre/GPU Timing Pills
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Left: FPS Hero Readout
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              margin: const EdgeInsets.only(
                                                  right: 4, bottom: 2),
                                              decoration: BoxDecoration(
                                                color: mFpsActive,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: mFpsActive
                                                        .withValues(alpha: 0.6),
                                                    blurRadius: 5,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              fps.toStringAsFixed(1),
                                              style: TextStyle(
                                                color: mFpsActive,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                fontFamily: MonitorTextStyle
                                                    .monoFontFamily,
                                                letterSpacing: -0.5,
                                                height: 1.0,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'FPS',
                                              style: TextStyle(
                                                color: mFpsActive.withValues(
                                                    alpha: 0.80),
                                                fontSize: 8,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.4,
                                                height: 1.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _rangeStr(fpsHist, 1).isNotEmpty
                                              ? 'Range ${_rangeStr(fpsHist, 1)}'
                                              : 'Target ${hz.round()}Hz',
                                          style: TextStyle(
                                            color: subtleTxt,
                                            fontSize: 7.2,
                                            fontWeight: FontWeight.w600,
                                            fontFamily:
                                                MonitorTextStyle.monoFontFamily,
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Right: Pre (Build) & GPU Timing Pills
                                  Expanded(
                                    flex: 7,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildTimingMiniRow(
                                          label: 'PRE',
                                          value:
                                              '${buildMs.toStringAsFixed(2)}ms',
                                          range: _rangeStr(buildHist, 1),
                                          color: mBuild,
                                          dark: dark,
                                        ),
                                        const SizedBox(height: 2.5),
                                        _buildTimingMiniRow(
                                          label: 'GPU',
                                          value:
                                              '${gpuMs.toStringAsFixed(2)}ms',
                                          range: _rangeStr(gpuHist, 1),
                                          color: mGpu,
                                          dark: dark,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 5),

                              // Middle Row: Jank & Stutter Status Capsules
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatusMicroChip(
                                      icon: Icons.bolt_rounded,
                                      label: LocaleKeys.overlayJankLabel.tr,
                                      value:
                                          '${ctrl.jankFrameCount} (${LocaleKeys.overlayBigJankLabel.tr}:${ctrl.bigJankFrameCount})',
                                      color: ctrl.bigJankFrameCount > 0
                                          ? mJank
                                          : (ctrl.jankFrameCount > 0
                                              ? mBuild
                                              : secondaryTxt),
                                      isAlert: ctrl.jankFrameCount > 0,
                                      dark: dark,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _buildStatusMicroChip(
                                      icon: Icons.multiline_chart_rounded,
                                      label: LocaleKeys.overlayStutterLabel.tr,
                                      value:
                                          '${ctrl.stutterRate.toStringAsFixed(1)}% (Drop:${ctrl.dropFrameCount})',
                                      color: ctrl.stutterRate > 5.0
                                          ? mJank
                                          : (ctrl.stutterRate > 1.0
                                              ? mBuild
                                              : secondaryTxt),
                                      isAlert: ctrl.stutterRate > 1.0,
                                      dark: dark,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 5),

                              // Bottom of Module: Live Dual-Sparkline Telemetry Graph
                              Container(
                                height: 32,
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 2),
                                decoration: BoxDecoration(
                                  color: dark
                                      ? const Color(0xFF090D16)
                                          .withValues(alpha: 0.65)
                                      : Colors.white.withValues(alpha: 0.70),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: dark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : const Color(0xFFCBD5E1)
                                            .withValues(alpha: 0.6),
                                    width: 0.5,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _SparklinePainter(
                                          fpsHistory: fpsHist,
                                          gpuHistory: gpuHist,
                                          maxFps: hz,
                                          isDark: dark,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 1,
                                      right: 3,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildLegendDot('FPS', mFps),
                                          const SizedBox(width: 5),
                                          _buildLegendDot('GPU', mGpu),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 5),

                        // ── 4. API & NETWORK TELEMETRY STRIP ────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 5),
                          decoration: BoxDecoration(
                            color: sectionBg,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: sectionBorder, width: 0.7),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.hub_rounded,
                                      size: 10, color: mApi),
                                  const SizedBox(width: 3.5),
                                  Text(
                                    'API',
                                    style: TextStyle(
                                      color: mApi,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      fontFamily:
                                          MonitorTextStyle.monoFontFamily,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  // Mở: X capsule
                                  _buildApiPhaseBadge(
                                    label: 'Mở',
                                    count: initCount,
                                    color: mInit,
                                    dark: dark,
                                  ),
                                  const SizedBox(width: 4),
                                  // Thao tác: Y capsule
                                  _buildApiPhaseBadge(
                                    label: 'Thao tác',
                                    count: actionCount,
                                    color: mAction,
                                    dark: dark,
                                  ),
                                  const Spacer(),
                                  // NET Ping badge
                                  (() {
                                    final netColor = pingMs == null
                                        ? subtleTxt
                                        : pingMs < 50
                                            ? mFps
                                            : pingMs < 150
                                                ? mBuild
                                                : mJank;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4.5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: netColor.withValues(
                                            alpha: dark ? 0.14 : 0.10),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color:
                                              netColor.withValues(alpha: 0.30),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: netColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            pingMs == null
                                                ? 'NET --'
                                                : '${pingMs}ms',
                                            style: TextStyle(
                                              color: netColor,
                                              fontSize: 7.5,
                                              fontWeight: FontWeight.w800,
                                              fontFamily: MonitorTextStyle
                                                  .monoFontFamily,
                                              height: 1.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })(),
                                ],
                              ),
                              if (apiErr > 0 ||
                                  slowApi > 0 ||
                                  flutterErr > 0) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 3,
                                  children: [
                                    if (apiErr > 0)
                                      _buildAlertPill(
                                        icon: Icons.warning_amber_rounded,
                                        text:
                                            '$apiErr ${LocaleKeys.overlayApiErr.tr}',
                                        color: mJank,
                                        dark: dark,
                                      ),
                                    if (slowApi > 0)
                                      _buildAlertPill(
                                        icon: Icons.schedule_rounded,
                                        text:
                                            '$slowApi ${LocaleKeys.overlayApiSlow.tr}',
                                        color: mBuild,
                                        dark: dark,
                                      ),
                                    if (flutterErr > 0)
                                      _buildAlertPill(
                                        icon: Icons.bug_report_rounded,
                                        text: '$flutterErr ERR',
                                        color: mJank,
                                        dark: dark,
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 5),

                        // ── 5. HARDWARE & STORAGE TELEMETRY (RAM / IMG / ROM)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 5),
                          decoration: BoxDecoration(
                            color: sectionBg,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: sectionBorder, width: 0.7),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // RAM + IMG Cache Row
                              (() {
                                final totalRamMb = ctrl.totalRam;
                                final String ramStr;
                                double ramRatio = 0.0;
                                if (totalRamMb > 0) {
                                  final totalRamGb = totalRamMb / 1024.0;
                                  ramStr =
                                      '${memMb.toStringAsFixed(0)}M / ${totalRamGb.toStringAsFixed(1)}G';
                                  ramRatio =
                                      (memMb / totalRamMb).clamp(0.03, 1.0);
                                } else {
                                  ramStr = '${memMb.toStringAsFixed(0)}MB';
                                  ramRatio = (memMb / 2048.0).clamp(0.03, 1.0);
                                }
                                final hasImg = ctrl.imageCacheCount > 0 ||
                                    ctrl.liveImageCount > 0;
                                return _buildHardwareBarRow(
                                  label: LocaleKeys.overlayRamLabel.tr,
                                  value: ramStr,
                                  trailing: hasImg
                                      ? 'IMG ${ctrl.imageCacheMb.toStringAsFixed(1)}M (${ctrl.imageCacheCount}c·${ctrl.liveImageCount}l)'
                                      : null,
                                  ratio: ramRatio,
                                  color: mMem,
                                  secondaryTxt: secondaryTxt,
                                  dark: dark,
                                );
                              })(),
                              const SizedBox(height: 4),
                              // ROM Storage Row
                              (() {
                                final appDiskMb = ctrl.appDiskUsed;
                                final totalDiskGb = ctrl.totalDisk;
                                final freeDiskGb = ctrl.freeDisk;
                                final String romStr;
                                String? freeBadge;
                                double romRatio = 0.0;
                                if (totalDiskGb > 0) {
                                  romStr =
                                      'App ${appDiskMb.toStringAsFixed(1)}M / ${totalDiskGb.toStringAsFixed(0)}G';
                                  if (freeDiskGb > 0) {
                                    freeBadge =
                                        '${LocaleKeys.overlayFreeLabel.tr} ${freeDiskGb.toStringAsFixed(0)}G';
                                    romRatio = ((totalDiskGb - freeDiskGb) /
                                            totalDiskGb)
                                        .clamp(0.03, 1.0);
                                  }
                                } else if (appDiskMb > 0) {
                                  romStr = 'App ${appDiskMb.toStringAsFixed(1)}MB';
                                  romRatio = 0.15;
                                } else {
                                  romStr = '--';
                                }
                                return _buildHardwareBarRow(
                                  label: LocaleKeys.overlayRomLabel.tr,
                                  value: romStr,
                                  trailing: freeBadge,
                                  ratio: romRatio,
                                  color: mRom,
                                  secondaryTxt: secondaryTxt,
                                  dark: dark,
                                );
                              })(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        // ── 6. BOTTOM FUTURISTIC CONTROL DOCK ───────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _PanelActionChip(
                              onTap: onCollapse,
                              icon: Icons.unfold_less_rounded,
                              label: LocaleKeys.overlayCollapse.tr,
                              color: btnIconColor,
                            ),
                            _PanelActionChip(
                              onTap: onToggleGrid,
                              icon: gridIcon,
                              label: LocaleKeys.overlayGrid.tr,
                              color: gridIconColor,
                              borderColor: gridBorderColor,
                              isActive: gridMode != GridMode.off,
                            ),
                            if (MonitorNavigatorObserver.currentRoute !=
                                MonitorConstants.dashboardRoute)
                              _PanelActionChip(
                                onTap: onOpenDashboard,
                                icon: Icons.space_dashboard_rounded,
                                label: LocaleKeys.overlayDash.tr,
                                color: dark
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF0284C7),
                                borderColor: (dark
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFF0284C7))
                                    .withValues(alpha: 0.32),
                              )
                            else
                              const SizedBox(width: 40),
                            _PanelActionChip(
                              onTap: onClear,
                              icon: Icons.restart_alt_rounded,
                              label: LocaleKeys.overlayReset.tr,
                              color: MonitorColors.statusError,
                              borderColor: MonitorColors.statusError
                                  .withValues(alpha: 0.35),
                            ),
                            _PanelActionChip(
                              onTap: onHide ?? () {},
                              icon: Icons.power_settings_new_rounded,
                              label: LocaleKeys.overlayHide.tr,
                              color: onHide == null
                                  ? btnIconColor.withValues(alpha: 0.25)
                                  : const Color(0xFFFF5555),
                              borderColor: onHide == null
                                  ? Colors.transparent
                                  : const Color(0xFFFF5555)
                                      .withValues(alpha: 0.30),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _buildTimingMiniRow({
    required String label,
    required String value,
    required String range,
    required Color color,
    required bool dark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(4.5),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              fontFamily: MonitorTextStyle.monoFontFamily,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              fontFamily: MonitorTextStyle.monoFontFamily,
              height: 1.1,
            ),
          ),
          if (range.isNotEmpty) ...[
            const Spacer(),
            Flexible(
              child: Text(
                range,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  color: color.withValues(alpha: 0.65),
                  fontSize: 6.8,
                  fontWeight: FontWeight.w600,
                  fontFamily: MonitorTextStyle.monoFontFamily,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildStatusMicroChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isAlert,
    required bool dark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
      decoration: BoxDecoration(
        color: isAlert
            ? color.withValues(alpha: dark ? 0.14 : 0.10)
            : (dark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.65)),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isAlert
              ? color.withValues(alpha: 0.35)
              : (dark
                  ? Colors.white.withValues(alpha: 0.07)
                  : const Color(0xFFCBD5E1).withValues(alpha: 0.7)),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 2.5),
          Expanded(
            child: Text(
              '$label: $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 7.4,
                fontWeight: FontWeight.w700,
                fontFamily: MonitorTextStyle.monoFontFamily,
                fontFamilyFallback: MonitorTextStyle.standardFontFallback,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4.5,
          height: 4.5,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.85),
            fontSize: 6.5,
            fontWeight: FontWeight.w800,
            fontFamily: MonitorTextStyle.monoFontFamily,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  static Widget _buildApiPhaseBadge({
    required String label,
    required int count,
    required Color color,
    required bool dark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: 0.32),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: color.withValues(alpha: 0.90),
              fontSize: 7.5,
              fontWeight: FontWeight.w600,
              fontFamilyFallback: MonitorTextStyle.standardFontFallback,
              height: 1.1,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              fontFamily: MonitorTextStyle.monoFontFamily,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildAlertPill({
    required IconData icon,
    required String text,
    required Color color,
    required bool dark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: 0.40),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 8.5, color: color),
          const SizedBox(width: 2.5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 7.4,
              fontWeight: FontWeight.w800,
              fontFamily: MonitorTextStyle.monoFontFamily,
              fontFamilyFallback: MonitorTextStyle.standardFontFallback,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildHardwareBarRow({
    required String label,
    required String value,
    String? trailing,
    required double ratio,
    required Color color,
    required Color secondaryTxt,
    required bool dark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              padding: const EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: dark ? 0.16 : 0.10),
                borderRadius: BorderRadius.circular(3),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 7.2,
                  fontWeight: FontWeight.w800,
                  fontFamily: MonitorTextStyle.monoFontFamily,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 8.2,
                  fontWeight: FontWeight.w700,
                  fontFamily: MonitorTextStyle.monoFontFamily,
                  height: 1.1,
                ),
              ),
            ),
            if (trailing != null && trailing.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                trailing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: secondaryTxt,
                  fontSize: 7.2,
                  fontWeight: FontWeight.w600,
                  fontFamily: MonitorTextStyle.monoFontFamily,
                  fontFamilyFallback: MonitorTextStyle.standardFontFallback,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2.5),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 2.5,
            width: double.infinity,
            color: dark
                ? Colors.white.withValues(alpha: 0.07)
                : const Color(0xFFCBD5E1).withValues(alpha: 0.65),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(
                height: 2.5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _rangeStr(List<double> h, int decimals) {
    if (h.length < 2) return '';
    final mn = h.reduce((a, b) => a < b ? a : b).toStringAsFixed(decimals);
    final mx = h.reduce((a, b) => a > b ? a : b).toStringAsFixed(decimals);
    return '[$mn–$mx]';
  }
}

class _PanelActionChip extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color color;
  final Color? borderColor;
  final bool isActive;

  const _PanelActionChip({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.color,
    this.borderColor,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = MonitorColors.isDark;
    final textCol = isActive
        ? color
        : (dark
            ? Colors.white.withValues(alpha: 0.65)
            : const Color(0xFF475569));
    final bg = isActive
        ? color.withValues(alpha: dark ? 0.16 : 0.10)
        : (dark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));
    final borderCol = borderColor ??
        (dark
            ? Colors.white.withValues(alpha: 0.10)
            : const Color(0xFFCBD5E1));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 42,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 25,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: borderCol, width: 0.7),
              ),
              child: Icon(icon, size: 13, color: color),
            ),
            const SizedBox(height: 2.5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: textCol,
                fontSize: 7,
                fontWeight: FontWeight.w700,
                fontFamilyFallback: MonitorTextStyle.standardFontFallback,
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
    final gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : const Color(0xFF94A3B8).withValues(alpha: 0.20)
      ..strokeWidth = 0.5;

    // Subtle cyber grid lines
    canvas.drawLine(
        Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), gridPaint);
    for (int i = 1; i <= 3; i++) {
      final x = size.width * (i / 4);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final refY = (1 - (60.0 / maxFps).clamp(0.0, 1.0)) * size.height;
    canvas.drawLine(
      Offset(0, refY),
      Offset(size.width, refY),
      Paint()
        ..color = isDark
            ? const Color(0xFF4ADE80).withValues(alpha: 0.18)
            : const Color(0xFF10B981).withValues(alpha: 0.25)
        ..strokeWidth = 0.6,
    );

    _drawFilled(
      canvas,
      size,
      fpsHistory,
      maxFps,
      isDark ? const Color(0xFF4ADE80) : const Color(0xFF10B981),
      highIsGood: true,
    );
    _drawLine(
      canvas,
      size,
      gpuHistory,
      33.3,
      isDark ? const Color(0xFFFB923C) : const Color(0xFFF97316),
      highIsGood: true,
    );
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
              color.withValues(alpha: 0.30),
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
