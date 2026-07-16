// ignore_for_file: unnecessary_getters_setters

import 'dart:ui' show FramePhase;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/monitor_constants.dart';
import '../../controller/monitor_controller.dart';
import '../../controller/overlay_controller.dart';
import '../../../domain/overlay_state_entity.dart';
import '../../navigation/monitor_navigator_observer.dart';
import '../pages/monitor_dashboard_page.dart';
import '../theme/monitor_theme.dart';

import 'fps_overlay_grid_painter.dart';
import 'fps_overlay_tucked_handle.dart';
import 'fps_overlay_pill_badge.dart';
import 'fps_overlay_details_panel.dart';
import 'responsive_dialog_wrapper.dart';

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
  bool _isDragging = false;

  double _pendingFps = 0.0;
  double _pendingBuild = 0.0;
  double _pendingGpu = 0.0;
  Ticker? _ticker;
  Duration _lastPublish = Duration.zero;

  OverlayController get _overlayCtrl => OverlayController.instance;
  MonitorController get _ctrl => MonitorController.instance;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onMonitorControllerChanged);
    _manageListening();
  }

  @override
  void didUpdateWidget(FpsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isShowing != widget.isShowing) _manageListening();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onMonitorControllerChanged);
    _ticker?.dispose();
    if (_isListening) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    super.dispose();
  }

  void _onMonitorControllerChanged() {
    _manageListening();
  }

  void _manageListening() {
    final bool shouldListen = widget.isShowing && !_ctrl.isDashboardOpen;
    if (shouldListen && !_isListening) {
      _isListening = true;
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      if (_ticker == null) {
        _ticker = createTicker(_onTick)..start();
      } else {
        _ticker!.start();
      }
    } else if (!shouldListen && _isListening) {
      _isListening = false;
      if (!widget.isShowing) {
        _overlayCtrl.collapse(
          MediaQuery.of(context).size.width,
          OverlayLayout.pillW,
          OverlayLayout.edgeMargin,
        );
      }
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

  void _onExpandPanel() => _overlayCtrl.expand();

  void _onCollapse() {
    _overlayCtrl.collapse(
      MediaQuery.of(context).size.width,
      OverlayLayout.pillW,
      OverlayLayout.edgeMargin,
    );
  }

  void _onOpenDashboard() {
    final nav = MonitorNavigatorObserver.navigatorState;
    if (nav == null) return;
    if (_ctrl.isDashboardOpen) {
      return;
    }
    final route = MonitorNavigatorObserver.currentRoute;
    nav.push(MonitorResponsiveRoute(
      builder: (_) => MonitorDashboardPage(
          initialScreen: route.isEmpty ? MonitorConstants.unknownRoute : route),
      settings: const RouteSettings(name: '/MonitorDashboardPage'),
    ));
  }

  void _onClearData() {
    _ctrl.clearAll();
  }

  void _onToggleGrid() => _overlayCtrl.toggleGrid();

  @override
  Widget build(BuildContext context) {
    if (!widget.isShowing) return widget.child;

    return ListenableBuilder(
      listenable: _overlayCtrl,
      builder: (context, _) {
        if (!_overlayCtrl.isInitialized) {
          return widget.child;
        }

        final state = _overlayCtrl.state;

        // Initializing position if not set
        if (!state.positionInit) {
          final size = MediaQuery.of(context).size;
          final padding = MediaQuery.of(context).padding;
          final top = padding.top + OverlayLayout.edgeMargin;
          final left =
              size.width - OverlayLayout.pillW - OverlayLayout.edgeMargin;

          // Let initialization defer so it doesn't trigger build locks
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _overlayCtrl.initializePosition(top, left);
          });
        }

        final mq = MediaQuery.of(context);
        final sw = mq.size.width;
        final sh = mq.size.height;
        final pad = mq.padding;

        final isExpanded = state.isExpanded;
        final isTucked = state.isTucked;
        final tuckedLeft = state.tuckedLeft;
        final gridMode = state.gridMode;

        final w = isExpanded ? OverlayLayout.expandedW : OverlayLayout.pillW;
        final h = isExpanded ? OverlayLayout.expandedH : OverlayLayout.pillH;
        final minLeft = OverlayLayout.edgeMargin;
        final maxLeft = sw - w - OverlayLayout.edgeMargin;
        final minTop = pad.top + OverlayLayout.edgeMargin;
        final maxTop = sh - pad.bottom - h - OverlayLayout.edgeMargin;

        double currentLeft = state.left ?? minLeft;
        double currentTop = state.top ?? minTop;

        if (!isTucked) {
          final double safeMaxTop = maxTop < minTop ? minTop : maxTop;
          
          if (_isDragging) {
            // Allow the overlay (both pill and expanded) to go slightly offscreen to trigger tucking.
            final minLeftDrag = -w * 0.5;
            final maxLeftDragDrag = sw - w * 0.5;
            final double safeMaxLeftDrag = maxLeftDragDrag < minLeftDrag ? minLeftDrag : maxLeftDragDrag;
            
            currentLeft = currentLeft.clamp(minLeftDrag, safeMaxLeftDrag);
            currentTop = currentTop.clamp(minTop, safeMaxTop);
          } else {
            // Clamp strictly within screen boundaries if not dragging (e.g. when expanded)
            final double safeMaxLeft = maxLeft < minLeft ? minLeft : maxLeft;
            currentLeft = currentLeft.clamp(minLeft, safeMaxLeft);
            currentTop = currentTop.clamp(minTop, safeMaxTop);
          }
        }

        return Stack(
          children: [
            Listener(
              onPointerUp: (_) => MonitorNavigatorObserver.scheduleTabRouteResolutionForce(),
              behavior: HitTestBehavior.translucent,
              child: widget.child,
            ),
            ListenableBuilder(
              listenable: _ctrl,
              builder: (context, _) {
                if (_ctrl.isDashboardOpen) {
                  return const SizedBox.shrink();
                }

                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Stack(
                    children: [
                    if (gridMode != GridMode.off)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ListenableBuilder(
                            listenable: MonitorColors.isDarkNotifier,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: FpsOverlayGridPainter(
                                  mode: gridMode,
                                  isDark: MonitorColors.isDark,
                                  padding: pad,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    Positioned(
                      top: currentTop,
                      left: currentLeft,
                      child: GestureDetector(
                        onPanStart: (_) {
                          setState(() {
                            _isDragging = true;
                          });
                        },
                        onPanUpdate: (d) {
                          if (isTucked) {
                            final double currentX = d.globalPosition.dx;
                            const double pullThreshold = 45.0;

                            bool shouldUntuck = false;
                            if (tuckedLeft) {
                              if (currentX > pullThreshold) {
                                shouldUntuck = true;
                              }
                            } else {
                              if (currentX < sw - pullThreshold) {
                                shouldUntuck = true;
                              }
                            }

                            if (shouldUntuck) {
                              _overlayCtrl.untuck(
                                sw,
                                OverlayLayout.pillW,
                                OverlayLayout.expandedW,
                                OverlayLayout.edgeMargin,
                                dragX: currentX,
                              );
                            } else {
                              final double nextTop = (currentTop + d.delta.dy).clamp(
                                pad.top + OverlayLayout.edgeMargin,
                                sh - pad.bottom - 48.0 - OverlayLayout.edgeMargin,
                              );
                              _overlayCtrl.updatePosition(nextTop, currentLeft);
                            }
                            return;
                          }

                          final double nextTop = (currentTop + d.delta.dy).clamp(
                            pad.top + OverlayLayout.edgeMargin,
                            sh - pad.bottom - h - OverlayLayout.edgeMargin,
                          );
                          final minLeftDrag = -w * 0.5;
                          final maxLeftDrag = sw - w * 0.5;
                          final double nextLeft =
                              (currentLeft + d.delta.dx).clamp(minLeftDrag, maxLeftDrag);

                          _overlayCtrl.updatePosition(nextTop, nextLeft);
                        },
                        onPanEnd: (details) {
                          setState(() {
                            _isDragging = false;
                          });
                          if (isTucked) {
                            _overlayCtrl.finalizePosition(currentTop, currentLeft);
                            return;
                          }

                          // Only tuck if dragged intentionally deep into the edge (at least 25% offscreen)
                          if (currentLeft < -w * 0.25) {
                            _overlayCtrl.tuck(true, sw, 18.0);
                          } else if (currentLeft + w > sw + w * 0.25) {
                            _overlayCtrl.tuck(false, sw, 18.0);
                          } else {
                            final center = currentLeft + w / 2;
                            final double snapLeft = center < sw / 2
                                ? OverlayLayout.edgeMargin
                                : sw - w - OverlayLayout.edgeMargin;
                            _overlayCtrl.finalizePosition(currentTop, snapLeft);
                          }
                        },
                        onPanCancel: () {
                          setState(() {
                            _isDragging = false;
                          });
                        },
                        onTap: () {
                          if (isTucked) {
                            _overlayCtrl.untuck(
                              sw,
                              OverlayLayout.pillW,
                              OverlayLayout.expandedW,
                              OverlayLayout.edgeMargin,
                            );
                          } else {
                            if (!isExpanded) {
                              _onOpenDashboard();
                            }
                          }
                        },
                        onLongPress: (isExpanded || isTucked) ? null : _onExpandPanel,
                        child: isExpanded
                            ? FpsOverlayDetailsPanel(
                                onCollapse: _onCollapse,
                                onHide: widget.onHide,
                                onOpenDashboard: _onOpenDashboard,
                                onClear: _onClearData,
                                gridMode: gridMode,
                                onToggleGrid: _onToggleGrid,
                              )
                            : isTucked
                                ? FpsOverlayTuckedHandle(tuckedLeft: tuckedLeft)
                                : const FpsOverlayPillBadge(),
                      ),
                    ),
                  ],
                ),
              );
            },
            ),
          ],
        );
      },
    );
  }
}
