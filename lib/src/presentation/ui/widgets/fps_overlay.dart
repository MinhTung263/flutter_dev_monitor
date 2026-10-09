// ignore_for_file: unnecessary_getters_setters


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
import 'monitor_theme_scope.dart';
import 'responsive_dialog_wrapper.dart';

class FpsOverlay extends StatefulWidget {
  final Widget child;
  final bool isShowing;
  final bool expandedByDefault;
  final bool enableSnapToEdge;
  final bool tuckedByDefault;
  final bool alwaysHideToEdge;
  final VoidCallback? onHide;

  const FpsOverlay({
    super.key,
    required this.child,
    this.isShowing = true,
    this.expandedByDefault = false,
    this.enableSnapToEdge = true,
    this.tuckedByDefault = false,
    this.alwaysHideToEdge = false,
    this.onHide,
  });

  @override
  State<FpsOverlay> createState() => _FpsOverlayState();
}

class _FpsOverlayState extends State<FpsOverlay> {
  // ── Frame timing ──────────────────────────────────────────────────────
  bool _isListening = false;
  bool _isDragging = false;

  DateTime _lastPublishTime = DateTime.fromMillisecondsSinceEpoch(0);

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
      _lastPublishTime = DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted || timings.isEmpty) return;

    try {
      // 1. Lấy tần số quét phần cứng chuẩn của màn hình (60Hz / 90Hz / 120Hz)
      double targetFps = 60.0;
      try {
        final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
        if (view != null && view.display.refreshRate > 0) {
          targetFps = view.display.refreshRate.clamp(30.0, 144.0);
        }
      } catch (_) {}

      // 2. Ngân sách chuẩn của 1 Frame theo Flutter DevTools
      // 60Hz  -> 16.67ms (16,667 µs)
      // 120Hz -> 8.33ms  (8,333 µs)
      final targetBudgetUs = (1000000.0 / targetFps).round();

      double totalBuildMs = 0.0;
      double totalRasterMs = 0.0;
      double totalEffectiveFps = 0.0;
      int count = 0;

      for (final t in timings) {
        final buildUs = t.buildDuration.inMicroseconds;
        final rasterUs = t.rasterDuration.inMicroseconds;
        final totalUs = buildUs + rasterUs;

        // Chuẩn DevTools: Frame được tính là Jank khi Build hoặc Raster hoặc Total vượt ngân sách
        if (buildUs > targetBudgetUs || rasterUs > targetBudgetUs || totalUs > targetBudgetUs) {
          _ctrl.recordJankFrame();
        }

        totalBuildMs += buildUs / 1000.0;
        totalRasterMs += rasterUs / 1000.0;

        // Tính FPS hiệu dụng cho từng frame riêng lẻ
        final double frameFps;
        if (totalUs <= targetBudgetUs) {
          frameFps = targetFps;
        } else {
          frameFps = (1000000.0 / totalUs).clamp(1.0, targetFps);
        }
        totalEffectiveFps += frameFps;
        count++;
      }

      if (count == 0) return;

      final avgBuildMs = totalBuildMs / count;
      final avgRasterMs = totalRasterMs / count;
      final calculatedFps = totalEffectiveFps / count;

      final now = DateTime.now();
      if (now.difference(_lastPublishTime).inMilliseconds >= 300) {
        _lastPublishTime = now;
        final route = MonitorNavigatorObserver.currentRoute;
        _ctrl.addFpsSample(route.isEmpty ? '/init' : route, calculatedFps);
        _ctrl.notifyFpsUpdate(calculatedFps, avgBuildMs, avgRasterMs);
        _ctrl.addOverlaySamples(calculatedFps, avgRasterMs, avgBuildMs);
      }
    } catch (_) {}
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
      settings: const RouteSettings(name: MonitorConstants.dashboardRoute),
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
            if (widget.tuckedByDefault || widget.alwaysHideToEdge) {
              _overlayCtrl.tuck(false, size.width, 18.0);
            }
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

                return MonitorThemeScope(
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
                      child: RepaintBoundary(
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

                          if (widget.alwaysHideToEdge) {
                            final isLeft = (currentLeft + w / 2) < sw / 2;
                            _overlayCtrl.tuck(isLeft, sw, 18.0);
                          } else if (currentLeft < -w * 0.25) {
                            _overlayCtrl.tuck(true, sw, 18.0);
                          } else if (currentLeft + w > sw + w * 0.25) {
                            _overlayCtrl.tuck(false, sw, 18.0);
                          } else if (widget.enableSnapToEdge) {
                            final center = currentLeft + w / 2;
                            final double snapLeft = center < sw / 2
                                ? OverlayLayout.edgeMargin
                                : sw - w - OverlayLayout.edgeMargin;
                            _overlayCtrl.finalizePosition(currentTop, snapLeft);
                          } else {
                            _overlayCtrl.finalizePosition(currentTop, currentLeft);
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
