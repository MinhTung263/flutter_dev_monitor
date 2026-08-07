part of 'monitor_dashboard_page.dart';

class _FlowMapList extends StatefulWidget {
  final bool isFullScreen;
  const _FlowMapList({this.isFullScreen = false});

  @override
  State<_FlowMapList> createState() => _FlowMapListState();
}

enum MapLayoutMode {
  tree,
  grid,
  stream,
  circular,
}

enum MapPathMode {
  curved,
  orthogonal,
  arc,
}

class _FlowMapListState extends State<_FlowMapList>
    with TickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  late AnimationController _pulseAnimationController;
  Animation<Matrix4>? _mapAnimation;

  MapPathMode _pathMode = MapPathMode.curved;
  String? _focusedRoute;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animationController.addListener(() {
      if (_mapAnimation != null) {
        _transformationController.value = _mapAnimation!.value;
      }
    });
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  void _animateToMatrix(Matrix4 targetMatrix) {
    _mapAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward(from: 0.0);
  }

  final Map<String, Offset> _treePositions = {};
  final Map<String, Offset> _gridPositions = {};
  final Map<String, Offset> _streamPositions = {};
  final Map<String, Offset> _circularPositions = {};

  MapLayoutMode _layoutMode = MapLayoutMode.tree;

  Map<String, Offset> get _activePositions {
    switch (_layoutMode) {
      case MapLayoutMode.tree:
        return _treePositions;
      case MapLayoutMode.grid:
        return _gridPositions;
      case MapLayoutMode.stream:
        return _streamPositions;
      case MapLayoutMode.circular:
        return _circularPositions;
    }
  }

  TapDownDetails? _doubleTapDetails;
  bool _isInitialMatrixSet = false;
  double _lastViewportWidth = 0.0;
  double _lastViewportHeight = 0.0;
  double _lastCanvasWidth = 0.0;
  bool _showBgGrid = true;
  final Set<String> _draggedRoutes = {};



  List<_ScreenVisit> _buildScreenVisits() {
    final routeLogs =
        List<RouteLogItem>.from(MonitorController.instance.routeLogs);
    final apiLogs =
        List<ApiLogItem>.from(MonitorController.instance.globalApiLogs);

    if (routeLogs.isEmpty) {
      final topRoute = MonitorNavigatorObserver.pageStack.isNotEmpty
          ? MonitorNavigatorObserver.pageStack.last
          : MonitorConstants.unknownRoute;
      if (topRoute != MonitorConstants.unknownRoute) {
        routeLogs.add(RouteLogItem(
          id: 0,
          event: RouteLogItem.eventReplace,
          route: topRoute,
          timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
        ));
      }
    }

    routeLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    apiLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final List<_ScreenVisit> visits = [];
    _ScreenVisit? currentVisit;
    final List<String> activeStack = [];

    for (final route in routeLogs) {
      final isPageStart = route.event == RouteLogItem.eventPush ||
          route.event == RouteLogItem.eventReplace;

      if (isPageStart) {
        if (currentVisit != null) {
          currentVisit.endTime = route.timestamp;
        }

        if (route.event == RouteLogItem.eventPush) {
          activeStack.add(route.route);
        } else if (route.event == RouteLogItem.eventReplace) {
          if (activeStack.isNotEmpty) {
            activeStack.removeLast();
          }
          activeStack.add(route.route);
        }

        currentVisit = _ScreenVisit(
          route: route.route,
          startTime: route.timestamp,
          routeItem: route,
          depth: activeStack.length,
        );
        visits.add(currentVisit);
      } else if (route.event == RouteLogItem.eventPop) {
        if (currentVisit != null) {
          currentVisit.endTime = route.timestamp;
        }

        if (activeStack.isNotEmpty && activeStack.last == route.route) {
          activeStack.removeLast();
        }

        final parentRouteName =
            activeStack.isNotEmpty && activeStack.last != route.route
                ? activeStack.last
                : MonitorConstants.unknownRoute;

        currentVisit = _ScreenVisit(
          route: parentRouteName,
          startTime: route.timestamp,
          routeItem: route,
          depth: activeStack.length,
        );
        visits.add(currentVisit);
      }
    }

    for (final api in apiLogs) {
      _ScreenVisit? matchedVisit;
      // Clean popup suffix if any, to match the page visit route
      final cleanScreen = api.screen.contains(' -> ')
          ? api.screen.split(' -> ')[0]
          : api.screen;
      final apiRouteBase =
          cleanScreen.contains('#') ? cleanScreen.split('#')[0] : cleanScreen;

      // 1. Try to find a visit of the SAME route (by base path) that overlaps in time.
      for (final visit in visits) {
        final visitRouteBase =
            visit.route.contains('#') ? visit.route.split('#')[0] : visit.route;
        if (visitRouteBase == apiRouteBase) {
          final afterStart = api.timestamp.isAfter(visit.startTime) ||
              api.timestamp.isAtSameMomentAs(visit.startTime);
          final beforeEnd =
              visit.endTime == null || api.timestamp.isBefore(visit.endTime!);
          if (afterStart && beforeEnd) {
            matchedVisit = visit;
            break;
          }
        }
      }

      // 2. If no time-matching visit of the same route is found (e.g. API logged after pop),
      // associate with the most recent visit of the SAME route (by base path) before/at the API timestamp.
      if (matchedVisit == null) {
        for (final visit in visits.reversed) {
          final visitRouteBase = visit.route.contains('#')
              ? visit.route.split('#')[0]
              : visit.route;
          if (visitRouteBase == apiRouteBase) {
            final startedBefore = api.timestamp.isAfter(visit.startTime) ||
                api.timestamp.isAtSameMomentAs(visit.startTime);
            if (startedBefore) {
              matchedVisit = visit;
              break;
            }
          }
        }
      }

      // 3. Fallback: if still no match, get the absolute latest visit of the same route (by base path).
      if (matchedVisit == null) {
        for (final visit in visits.reversed) {
          final visitRouteBase = visit.route.contains('#')
              ? visit.route.split('#')[0]
              : visit.route;
          if (visitRouteBase == apiRouteBase) {
            matchedVisit = visit;
            break;
          }
        }
      }

      // 4. Fallback: only if no visit of the same route exists, try matching any visit by timestamp.
      if (matchedVisit == null) {
        for (final visit in visits) {
          final afterStart = api.timestamp.isAfter(visit.startTime) ||
              api.timestamp.isAtSameMomentAs(visit.startTime);
          final beforeEnd =
              visit.endTime == null || api.timestamp.isBefore(visit.endTime!);
          if (afterStart && beforeEnd) {
            matchedVisit = visit;
            break;
          }
        }
      }

      if (matchedVisit != null) {
        matchedVisit.apiLogs.add(api);
      } else {
        if (visits.isNotEmpty) {
          final sameScreenVisit = visits.lastWhere(
            (v) {
              final vBase =
                  v.route.contains('#') ? v.route.split('#')[0] : v.route;
              return vBase == apiRouteBase;
            },
            orElse: () => visits.last,
          );
          sameScreenVisit.apiLogs.add(api);
        } else if (currentVisit != null) {
          currentVisit.apiLogs.add(api);
        }
      }
    }

    final errorLogs =
        List<ErrorLogItem>.from(MonitorController.instance.errorLogs);
    errorLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final err in errorLogs) {
      _ScreenVisit? matchedVisit;
      // Clean popup suffix if any
      final cleanScreen = err.screen.contains(' -> ')
          ? err.screen.split(' -> ')[0]
          : err.screen;
      final errRouteBase =
          cleanScreen.contains('#') ? cleanScreen.split('#')[0] : cleanScreen;

      // 1. Try to find a visit of the SAME route (by base path) that overlaps in time.
      for (final visit in visits) {
        final visitRouteBase =
            visit.route.contains('#') ? visit.route.split('#')[0] : visit.route;
        if (visitRouteBase == errRouteBase) {
          final afterStart = err.timestamp.isAfter(visit.startTime) ||
              err.timestamp.isAtSameMomentAs(visit.startTime);
          final beforeEnd =
              visit.endTime == null || err.timestamp.isBefore(visit.endTime!);
          if (afterStart && beforeEnd) {
            matchedVisit = visit;
            break;
          }
        }
      }

      // 2. If no time-matching visit of the same route is found (e.g. Error logged after pop),
      // associate with the most recent visit of the SAME route (by base path) before/at the Error timestamp.
      if (matchedVisit == null) {
        for (final visit in visits.reversed) {
          final visitRouteBase = visit.route.contains('#')
              ? visit.route.split('#')[0]
              : visit.route;
          if (visitRouteBase == errRouteBase) {
            final startedBefore = err.timestamp.isAfter(visit.startTime) ||
                err.timestamp.isAtSameMomentAs(visit.startTime);
            if (startedBefore) {
              matchedVisit = visit;
              break;
            }
          }
        }
      }

      // 3. Fallback: if still no match, get the absolute latest visit of the same route (by base path).
      if (matchedVisit == null) {
        for (final visit in visits.reversed) {
          final visitRouteBase = visit.route.contains('#')
              ? visit.route.split('#')[0]
              : visit.route;
          if (visitRouteBase == errRouteBase) {
            matchedVisit = visit;
            break;
          }
        }
      }

      // 4. Fallback: only if no visit of the same route exists, try matching any visit by timestamp.
      if (matchedVisit == null) {
        for (final visit in visits) {
          final afterStart = err.timestamp.isAfter(visit.startTime) ||
              err.timestamp.isAtSameMomentAs(visit.startTime);
          final beforeEnd =
              visit.endTime == null || err.timestamp.isBefore(visit.endTime!);
          if (afterStart && beforeEnd) {
            matchedVisit = visit;
            break;
          }
        }
      }

      if (matchedVisit != null) {
        matchedVisit.errorLogs.add(err);
      } else {
        if (visits.isNotEmpty) {
          final sameScreenVisit = visits.lastWhere(
            (v) {
              final vBase =
                  v.route.contains('#') ? v.route.split('#')[0] : v.route;
              return vBase == errRouteBase;
            },
            orElse: () => visits.last,
          );
          sameScreenVisit.errorLogs.add(err);
        } else if (currentVisit != null) {
          currentVisit.errorLogs.add(err);
        }
      }
    }

    return visits;
  }

  List<String> _getUniqueRoutes(List<_ScreenVisit> visits) {
    final List<String> routes = [];
    for (final visit in visits) {
      if (visit.route != MonitorConstants.unknownRoute &&
          !routes.contains(visit.route)) {
        routes.add(visit.route);
      }
    }
    if (routes.isEmpty) {
      routes.add(MonitorConstants.unknownRoute);
    }
    return routes;
  }

  List<_RouteTransition> _getTransitions(List<_ScreenVisit> visits) {
    final Map<String, _RouteTransition> transitionMap = {};
    for (int i = 0; i < visits.length - 1; i++) {
      final from = visits[i].route;
      final to = visits[i + 1].route;
      if (from == to ||
          from == MonitorConstants.unknownRoute ||
          to == MonitorConstants.unknownRoute) {
        continue;
      }
      final isBack = visits[i + 1].routeItem.event == RouteLogItem.eventPop;
      final key = '$from->$to';
      if (transitionMap.containsKey(key)) {
        transitionMap[key]!.count++;
      } else {
        transitionMap[key] =
            _RouteTransition(from: from, to: to, isBack: isBack);
      }
    }
    return transitionMap.values.toList();
  }

  void _handleMiniMapGesture(
    Offset localPos,
    Size viewportSize,
    double canvasWidth,
    double canvasHeight,
  ) {
    if (_activePositions.isEmpty) return;

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final pos in _activePositions.values) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dy > maxY) maxY = pos.dy;
    }

    const double cardHalfW = 90.0;
    const double cardHalfH = 32.5;

    minX -= cardHalfW;
    maxX += cardHalfW;
    minY -= cardHalfH;
    maxY += cardHalfH;

    final contentW = (maxX - minX).abs();
    final contentH = (maxY - minY).abs();
    final double safeContentW = contentW < 1 ? 1 : contentW;
    final double safeContentH = contentH < 1 ? 1 : contentH;

    const double padding = 6.0;
    final double scaleX = (_MiniMap.width - padding * 2) / safeContentW;
    final double scaleY = (_MiniMap.height - padding * 2) / safeContentH;
    final double mmScale = math.min(scaleX, scaleY);

    final double offsetX =
        padding + (_MiniMap.width - padding * 2 - safeContentW * mmScale) / 2;
    final double offsetY =
        padding + (_MiniMap.height - padding * 2 - safeContentH * mmScale) / 2;

    final double worldX = (localPos.dx - offsetX) / mmScale + minX;
    final double worldY = (localPos.dy - offsetY) / mmScale + minY;

    final currentMatrix = _transformationController.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();

    final tx = viewportSize.width / 2 - worldX * currentScale;
    final double ty = viewportSize.height / 2 - worldY * currentScale;

    setState(() {
      final Matrix4 newMatrix = Matrix4.identity();
      newMatrix.multiply(Matrix4.translationValues(tx, ty, 0.0));
      newMatrix
          .multiply(Matrix4.diagonal3Values(currentScale, currentScale, 1.0));
      _transformationController.value = newMatrix;
    });
  }

  void _showScreenApisBottomSheet(
      String route, List<ApiLogItem> allApis, List<ErrorLogItem> errors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MonitorColors.surface,
      isScrollControlled: true,
      routeSettings: const RouteSettings(name: MonitorConstants.screenApiDetailSheet),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        String localSearchQuery = '';

        return StatefulBuilder(
          builder: (context, setLocalState) {
            final List<ApiLogItem> filteredApis;
            if (localSearchQuery.isEmpty) {
              filteredApis = allApis;
            } else {
              final q = localSearchQuery.toLowerCase();
              filteredApis = allApis.where((l) {
                final urlMatch = l.url.toLowerCase().contains(q);
                final methodMatch = l.method.toLowerCase().contains(q);
                final statusMatch = l.statusCode.toString().contains(q);
                return urlMatch || methodMatch || statusMatch;
              }).toList();
            }

            return DefaultTabController(
              length: 2,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.8,
                padding: const EdgeInsets.only(
                    top: 8, left: 16, right: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: MonitorColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MonoText(
                                LocaleKeys.logsForScreen.tr,
                                9,
                                color: MonitorColors.secondaryText,
                                weight: FontWeight.bold,
                              ),
                              const SizedBox(height: 2),
                              MonoText(
                                MonitorController.formatRouteName(route),
                                14.5,
                                color: MonitorColors.primaryText,
                                weight: FontWeight.bold,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: MonitorColors.secondaryText, size: 20),
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: MonitorColors.dropdownBg,
                            padding: const EdgeInsets.all(6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: MonitorColors.dropdownBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TabBar(
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: MonitorColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        labelColor: MonitorColors.primaryText,
                        unselectedLabelColor: MonitorColors.secondaryText,
                        labelStyle: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                        unselectedLabelStyle: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500),
                        dividerColor: Colors.transparent,
                        tabs: [
                          Tab(
                              text: LocaleKeys.mapApisCount.trWith({
                            'filtered': filteredApis.length,
                            'total': allApis.length,
                          })),
                          Tab(
                              text: LocaleKeys.errorsCount
                                  .trWith({'count': errors.length})),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: APIs
                          Column(
                            children: [
                              if (allApis.isNotEmpty) ...[
                                _SearchBar(
                                  query: localSearchQuery,
                                  onChanged: (v) {
                                    setLocalState(() {
                                      localSearchQuery = v;
                                    });
                                  },
                                  transparent: true,
                                ),
                                const SizedBox(height: 12),
                              ],
                              Expanded(
                                child: filteredApis.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: MonitorColors.divider
                                                    .withValues(alpha: 0.5),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(Icons.api_outlined,
                                                  size: 24,
                                                  color: MonitorColors
                                                      .secondaryText),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              localSearchQuery.isEmpty
                                                  ? LocaleKeys
                                                      .mapNoApiRequests.tr
                                                  : LocaleKeys
                                                      .mapNoMatchingApi.tr,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color:
                                                    MonitorColors.secondaryText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: filteredApis.length,
                                        itemBuilder: (context, idx) {
                                          final apiLog = filteredApis[
                                              filteredApis.length - 1 - idx];
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
                                            child: ApiLogTile(
                                              log: apiLog,
                                              compact: false,
                                              showOrder: false,
                                              showScreenBadge: false,
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                          // Tab 2: Errors
                          errors.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: MonitorColors.divider
                                              .withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.bug_report_outlined,
                                            size: 24,
                                            color: MonitorColors.secondaryText),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        LocaleKeys.mapNoFlutterErrors.tr,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: MonitorColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: errors.length,
                                  itemBuilder: (context, idx) {
                                    final errLog =
                                        errors[errors.length - 1 - idx];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _ErrorLogTile(
                                        error: errLog,
                                        compact: false,
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _zoom(double factor) {
    if (_activePositions.isEmpty) return;

    final matrix = _transformationController.value.clone();
    final double currentScale = matrix.getMaxScaleOnAxis();
    if (currentScale.isNaN || currentScale.isInfinite || currentScale <= 0.05) {
      return;
    }

    double targetScale = currentScale * factor;
    targetScale = targetScale.clamp(0.15, 2.0);

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final pos in _activePositions.values) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dy > maxY) maxY = pos.dy;
    }

    final double graphCenterX = (minX + maxX) / 2;
    final double graphCenterY = (minY + maxY) / 2;

    final double px = _lastViewportWidth / 2;
    final double py = _lastViewportHeight / 2;

    final double tx = px - (graphCenterX * targetScale);
    final double ty = py - (graphCenterY * targetScale);

    final newMatrix = Matrix4.identity()
      ..setEntry(0, 0, targetScale)
      ..setEntry(1, 1, targetScale)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);

    _animateToMatrix(newMatrix);
  }

  void _zoomIn() {
    _zoom(1.2);
  }

  void _zoomOut() {
    _zoom(1 / 1.2);
  }

  void _handleDoubleTap() {
    if (_doubleTapDetails == null) return;
    final localPos = _doubleTapDetails!.localPosition;
    final matrix = _transformationController.value.clone();
    final currentScale = matrix.getMaxScaleOnAxis();
    if (currentScale.isNaN || currentScale.isInfinite || currentScale <= 0.05) {
      return;
    }

    if (currentScale >= 2.0) {
      _resetZoom();
      return;
    }

    const double zoomFactor = 1.4;
    final double x = localPos.dx;
    final double y = localPos.dy;

    matrix.multiply(Matrix4.translationValues(x, y, 0.0));
    matrix.multiply(Matrix4.diagonal3Values(zoomFactor, zoomFactor, 1.0));
    matrix.multiply(Matrix4.translationValues(-x, -y, 0.0));

    // Clamp resulting scale to valid range
    final resultScale = matrix.getMaxScaleOnAxis();
    if (resultScale < 0.15 || resultScale > 2.0) return;

    _animateToMatrix(matrix);
  }

  void _resetZoom() {
    setState(() {
      _activePositions.clear();
      _draggedRoutes.clear();
    });
    // Wait for the layout to rebuild with default positions, then recenter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _recenterCamera();
      }
    });
  }

  Future<void> _confirmAndResetZoom(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      routeSettings: const RouteSettings(name: MonitorConstants.resetConfirmDialog),
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => MonitorConfirmDialog(
        title: LocaleKeys.resetConfirmTitle.tr,
        message: LocaleKeys.resetLayoutConfirmMessage.tr,
        confirmLabel: LocaleKeys.confirm.tr,
        cancelLabel: LocaleKeys.cancel.tr,
      ),
    );
    if (confirmed == true && mounted) {
      _resetZoom();
    }
  }

  void _recenterCamera({bool animate = true}) {
    if (_lastViewportWidth <= 0 || _lastViewportHeight <= 0) return;

    if (_activePositions.isEmpty) {
      final initialTx = (_lastViewportWidth - _lastCanvasWidth) / 2;
      final targetMatrix = Matrix4.translationValues(initialTx, 0.0, 0.0);
      if (animate) {
        _animateToMatrix(targetMatrix);
      } else {
        _transformationController.value = targetMatrix;
      }
      return;
    }

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final pos in _activePositions.values) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dy > maxY) maxY = pos.dy;
    }

    const double cardWidth = 175.0;
    const double cardHeight = 80.0;

    const double margin = 28.0;
    final double graphWidth = (maxX - minX) + cardWidth + margin * 2;
    final double graphHeight = (maxY - minY) + cardHeight + margin * 2;

    final double graphCenterX = (minX + maxX) / 2;
    final double graphCenterY = (minY + maxY) / 2;

    final double scaleX = _lastViewportWidth / graphWidth;
    final double scaleY = _lastViewportHeight / graphHeight;

    double fitScale = math.min(scaleX, scaleY);
    if (fitScale.isNaN || fitScale.isInfinite || fitScale <= 0.0) {
      fitScale = 1.0;
    } else {
      fitScale = fitScale.clamp(0.2, 1.0);
    }

    final double tx = (_lastViewportWidth / 2) - (graphCenterX * fitScale);
    final double ty = (_lastViewportHeight / 2) - (graphCenterY * fitScale);

    final targetMatrix = Matrix4.identity()
      ..setEntry(0, 0, fitScale)
      ..setEntry(1, 1, fitScale)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);

    if (animate) {
      _animateToMatrix(targetMatrix);
    } else {
      _transformationController.value = targetMatrix;
    }
  }

  void _focusOnNode(String route) {
    final pos = _activePositions[route];
    if (pos == null) return;

    const double fitScale = 0.95;
    final double tx = (_lastViewportWidth / 2) - (pos.dx * fitScale);
    final double ty = (_lastViewportHeight / 2) - (pos.dy * fitScale);

    final targetMatrix = Matrix4.identity()
      ..setEntry(0, 0, fitScale)
      ..setEntry(1, 1, fitScale)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);

    _animateToMatrix(targetMatrix);
  }

  void _showSearchNodeSheet(List<String> routes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      routeSettings: const RouteSettings(name: MonitorConstants.mapSearchSheet),
      builder: (context) {
        return _MapSearchSheet(
          routes: routes,
          onSelected: (route) {
            _focusOnNode(route);
          },
        );
      },
    );
  }

  Future<void> _exportInteractiveMapHtml(
    List<String> uniqueRoutes,
    List<_RouteTransition> transitions,
    double canvasWidth,
    double canvasHeight,
  ) async {
    try {
      // Calculate sharing origin bounds before async gap
      final box = context.findRenderObject() as RenderBox?;
      final Rect? sharePositionOrigin =
          box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

      final visits = _buildScreenVisits();

      // Calculate API and error mappings
      final Map<String, List<ApiLogItem>> routeApis = {};
      final Map<String, List<ErrorLogItem>> routeErrors = {};
      final Map<String, int> routeVisits = {};
      final Map<String, Set<String>> seenApiOrders = {};
      final Map<String, Set<String>> seenErrorKeys = {};
      final Map<String, String> routeTypes = {};

      for (final r in uniqueRoutes) {
        routeApis[r] = [];
        routeErrors[r] = [];
        routeVisits[r] = 0;
        seenApiOrders[r] = {};
        seenErrorKeys[r] = {};
        routeTypes[r] = 'page';
      }

      for (final visit in visits) {
        if (!routeApis.containsKey(visit.route)) continue;
        routeTypes[visit.route] = visit.routeItem.routeType;
        for (final api in visit.apiLogs) {
          final key =
              '${api.timestamp.microsecondsSinceEpoch}_${api.method}_${api.url}';
          if (seenApiOrders[visit.route]!.add(key)) {
            routeApis[visit.route]!.add(api);
          }
        }
        for (final err in visit.errorLogs) {
          final key =
              '${err.timestamp.microsecondsSinceEpoch}_${err.message.hashCode}';
          if (seenErrorKeys[visit.route]!.add(key)) {
            routeErrors[visit.route]!.add(err);
          }
        }
        routeVisits[visit.route] = routeVisits[visit.route]! + 1;
      }

      final activeRoute = visits.isNotEmpty ? visits.last.route : '';

      final List<Map<String, dynamic>> nodes = [];
      for (final route in uniqueRoutes) {
        final apis = routeApis[route] ?? [];
        final errors = routeErrors[route] ?? [];
        final pos = _activePositions[route] ?? Offset.zero;
        nodes.add({
          'route': route,
          'title': MonitorController.formatRouteName(route),
          'x': pos.dx,
          'y': pos.dy,
          'isCurrent': route == activeRoute,
          'visitCount': routeVisits[route] ?? 0,
          'routeType': routeTypes[route] ?? 'page',
          'apis': apis
              .map((api) => {
                    'method': api.method,
                    'url': api.url,
                    'statusCode': api.statusCode,
                    'duration': api.duration,
                    'phase': api.phase,
                    'timestamp': api.timestamp.toIso8601String(),
                    'requestHeaders': api.requestHeaders,
                    'requestBody': api.requestBody,
                    'responseHeaders': api.responseHeaders,
                    'responseBody': api.responseBody,
                    'responseBytes': api.responseBytes,
                  })
              .toList(),
          'errors': errors
              .map((err) => {
                    'message': err.message,
                    'stackTrace': err.stackTrace,
                    'type': err.type,
                    'timestamp': err.timestamp.toIso8601String(),
                  })
              .toList(),
        });
      }

      final List<Map<String, dynamic>> transitionsData = transitions
          .map((t) => {
                'from': t.from,
                'to': t.to,
                'isBack': t.isBack,
              })
          .toList();

      final Map<String, dynamic> exportData = {
        'layoutMode': _layoutMode.name,
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
        'nodes': nodes,
        'transitions': transitionsData,
      };

      final String jsonData = jsonEncode(exportData).replaceAll('</', '<\\/');
      final String htmlContent = _buildHtmlTemplate(jsonData);

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/interactive_flow_map.html');
      await tempFile.writeAsString(htmlContent);

      debugPrint(
          '[DevMonitor] HTML file written: ${tempFile.path}, size=${await tempFile.length()} bytes');
      debugPrint('[DevMonitor] HTML content length: ${htmlContent.length}');

      if (!mounted) return;

      final shareText = LocaleKeys.mapSubject.tr.isNotEmpty
          ? LocaleKeys.mapSubject.tr
          : 'Interactive DevMonitor Flow Map';

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              tempFile.path,
              mimeType: 'text/html',
            ),
          ],
          subject: shareText,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (e) {
      debugPrint('[DevMonitor] Error exporting HTML map: $e');
    }
  }

  /// Delegates to [buildFlowMapHtml] defined in flow_map_html_builder.dart.
  String _buildHtmlTemplate(String jsonData) =>
      buildFlowMapHtml(jsonData: jsonData);

  @override
  void dispose() {
    _pulseAnimationController.dispose();
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visits = _buildScreenVisits();

    if (visits.isEmpty) {
      return const _EmptyState();
    }

    final uniqueRoutes = _getUniqueRoutes(visits);
    final transitions = _getTransitions(visits);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        const double cardWidth = 175.0;
        const double cardHeight = 80.0;

        const double baseCenterX = 1200.0;
        const double baseStartY = 600.0;

        if (_layoutMode == MapLayoutMode.grid) {
          final int columns = uniqueRoutes.length <= 1 ? 1 : 2;
          const double gridGapX = 48.0;
          const double gridGapY = 60.0;
          final double spacingX = cardWidth + gridGapX;
          final double rowSpacingY = cardHeight + gridGapY;
          final double gridTotalWidth = (columns - 1) * spacingX;
          final double gridStartX = baseCenterX - gridTotalWidth / 2;

          for (int i = 0; i < uniqueRoutes.length; i++) {
            final route = uniqueRoutes[i];
            if (!_draggedRoutes.contains(route)) {
              final row = i ~/ columns;
              final col = i % columns;
              final x = gridStartX + col * spacingX;
              final y = baseStartY + row * rowSpacingY;
              _activePositions[route] = Offset(x, y);
            }
          }
        } else if (_layoutMode == MapLayoutMode.tree) {
          // 1. Build adjacency maps for forward transitions
          final Map<String, List<String>> forwardAdj = {};
          final Map<String, List<String>> reverseAdj = {};
          for (final route in uniqueRoutes) {
            forwardAdj[route] = [];
            reverseAdj[route] = [];
          }

          for (final t in transitions) {
            if (!t.isBack && t.from != t.to) {
              if (forwardAdj.containsKey(t.from) && forwardAdj.containsKey(t.to)) {
                if (!forwardAdj[t.from]!.contains(t.to)) {
                  forwardAdj[t.from]!.add(t.to);
                }
                if (!reverseAdj[t.to]!.contains(t.from)) {
                  reverseAdj[t.to]!.add(t.from);
                }
              }
            }
          }

          // 2. Identify root nodes (in-degree == 0 among uniqueRoutes)
          final List<String> roots = [];
          for (final route in uniqueRoutes) {
            if (reverseAdj[route]!.isEmpty) {
              roots.add(route);
            }
          }
          if (roots.isEmpty && uniqueRoutes.isNotEmpty) {
            roots.add(uniqueRoutes.first);
          }

          // 3. Assign layer levels using BFS starting from roots
          final Map<String, int> nodeLevels = {};
          final List<String> bfsQueue = [];

          for (final root in roots) {
            nodeLevels[root] = 0;
            bfsQueue.add(root);
          }

          final Set<String> bfsVisited = Set.from(roots);

          while (bfsQueue.isNotEmpty) {
            final current = bfsQueue.removeAt(0);
            final currentLvl = nodeLevels[current] ?? 0;

            for (final next in forwardAdj[current] ?? <String>[]) {
              final newLvl = currentLvl + 1;
              if (!nodeLevels.containsKey(next) || newLvl > nodeLevels[next]!) {
                nodeLevels[next] = newLvl;
              }
              if (!bfsVisited.contains(next)) {
                bfsVisited.add(next);
                bfsQueue.add(next);
              }
            }
          }

          // Any disconnected routes get assigned level 0
          for (final route in uniqueRoutes) {
            if (!nodeLevels.containsKey(route)) {
              nodeLevels[route] = 0;
            }
          }

          // Helper for stable pseudo-random jitter
          double seededRnd(String key, int salt) {
            int hash = key.hashCode ^ (salt * 0x45d9f3b);
            hash = ((hash >> 16) ^ hash) * 0x45d9f3b;
            hash = ((hash >> 16) ^ hash) * 0x45d9f3b;
            hash = (hash >> 16) ^ hash;
            return ((hash & 0x7FFFFFFF) % 10000) / 10000.0;
          }

          // 4. Position nodes organically based on parent tree connections with spacious layout
          final Map<String, Offset> tempPositions = {};

          // Place roots with ample separation
          for (int i = 0; i < roots.length; i++) {
            final r = roots[i];
            final double ox = (i - (roots.length - 1) / 2.0) * 240.0 + (seededRnd(r, 1) - 0.5) * 35.0;
            final double oy = (seededRnd(r, 2) - 0.5) * 20.0;
            tempPositions[r] = Offset(baseCenterX + ox, baseStartY + oy);
          }

          // Sort routes by level ascending to position parents before children
          final sortedRoutes = List<String>.from(uniqueRoutes)
            ..sort((a, b) => (nodeLevels[a] ?? 0).compareTo(nodeLevels[b] ?? 0));

          for (final route in sortedRoutes) {
            if (tempPositions.containsKey(route)) continue;

            final parents = reverseAdj[route] ?? [];
            final validParents = parents.where((p) => tempPositions.containsKey(p)).toList();

            if (validParents.isNotEmpty) {
              final p = validParents.first;
              final pPos = tempPositions[p]!;
              final children = forwardAdj[p] ?? [];
              final sibIdx = math.max(0, children.indexOf(route));
              final k = math.max(1, children.length);

              const double stepX = 245.0;
              const double stepY = 155.0;
              final double fanOutX = (sibIdx - (k - 1) / 2.0) * stepX;
              final double jitterX = (seededRnd(route, 11) - 0.5) * 45.0;
              final double jitterY = (seededRnd(route, 22) - 0.5) * 28.0;
              final double zigZag = k == 1
                  ? (((nodeLevels[route] ?? 1) % 2 == 1 ? 1.0 : -1.0) * (25.0 + seededRnd(route, 33) * 25.0))
                  : 0.0;

              tempPositions[route] = Offset(
                pPos.dx + fanOutX + zigZag + jitterX,
                pPos.dy + stepY + jitterY,
              );
            } else {
              // Unconnected node - place in organic ring close to center
              final double angle = seededRnd(route, 41) * 2 * math.pi;
              final double dist = 210.0 + seededRnd(route, 52) * 80.0;
              tempPositions[route] = Offset(
                baseCenterX + dist * math.cos(angle),
                baseStartY + dist * math.sin(angle),
              );
            }
          }

          // 5. Anti-overlap force relaxation (25 iterations) with larger minimum separation
          const double minSepX = cardWidth + 48.0;
          const double minSepY = cardHeight + 42.0;

          for (int iter = 0; iter < 25; iter++) {
            for (int i = 0; i < uniqueRoutes.length; i++) {
              final rA = uniqueRoutes[i];
              final posA = tempPositions[rA] ?? const Offset(baseCenterX, baseStartY);
              for (int j = i + 1; j < uniqueRoutes.length; j++) {
                final rB = uniqueRoutes[j];
                final posB = tempPositions[rB] ?? const Offset(baseCenterX, baseStartY);

                final double dx = posB.dx - posA.dx;
                final double dy = posB.dy - posA.dy;
                final double absDx = dx.abs();
                final double absDy = dy.abs();

                if (absDx < minSepX && absDy < minSepY) {
                  final double overlapX = minSepX - absDx;
                  final double overlapY = minSepY - absDy;

                  double pushX = 0;
                  double pushY = 0;
                  if (overlapX / minSepX < overlapY / minSepY) {
                    final double signX = dx == 0 ? (rA.hashCode > rB.hashCode ? 1.0 : -1.0) : dx.sign;
                    pushX = signX * overlapX * 0.5;
                  } else {
                    final double signY = dy == 0 ? (rA.hashCode > rB.hashCode ? 1.0 : -1.0) : dy.sign;
                    pushY = signY * overlapY * 0.5;
                  }

                  tempPositions[rA] = Offset(posA.dx - pushX, posA.dy - pushY);
                  tempPositions[rB] = Offset(posB.dx + pushX, posB.dy + pushY);
                }
              }
            }
          }

          // 6. Recenter the whole cluster to (baseCenterX, baseStartY)
          if (tempPositions.isNotEmpty) {
            double sumX = 0;
            double sumY = 0;
            for (final pos in tempPositions.values) {
              sumX += pos.dx;
              sumY += pos.dy;
            }
            final double avgX = sumX / tempPositions.length;
            final double avgY = sumY / tempPositions.length;
            final double shiftX = baseCenterX - avgX;
            final double shiftY = baseStartY - avgY;

            for (final route in uniqueRoutes) {
              if (!_draggedRoutes.contains(route)) {
                final raw = tempPositions[route] ?? const Offset(baseCenterX, baseStartY);
                _activePositions[route] = Offset(raw.dx + shiftX, raw.dy + shiftY);
              }
            }
          }
        } else if (_layoutMode == MapLayoutMode.circular) {
          final double calculatedRadius =
              (uniqueRoutes.length * (cardWidth + 50.0)) / (2 * math.pi);
          final double radius =
              math.max(140.0, calculatedRadius).clamp(140.0, 450.0);
          final double centerY = baseStartY + radius;

          final int N = uniqueRoutes.length;
          final double angleStep = N > 0 ? (2 * math.pi) / N : 0.0;

          for (int i = 0; i < N; i++) {
            final route = uniqueRoutes[i];
            if (!_draggedRoutes.contains(route)) {
              final double angle =
                  i * angleStep - (math.pi / 2); // Start at 12 o'clock
              final double x = baseCenterX + radius * math.cos(angle);
              final double y = centerY + radius * math.sin(angle);
              _activePositions[route] = Offset(x, y);
            }
          }
        } else {
          const double streamGapY = 55.0;
          final double streamSpacingY = cardHeight + streamGapY;

          for (int i = 0; i < uniqueRoutes.length; i++) {
            final route = uniqueRoutes[i];
            if (!_draggedRoutes.contains(route)) {
              final y = baseStartY + i * streamSpacingY;
              _activePositions[route] = Offset(baseCenterX, y);
            }
          }
        }

        // Bounding box of content
        double minX = double.infinity;
        double maxX = -double.infinity;
        double minY = double.infinity;
        double maxY = -double.infinity;

        for (final pos in _activePositions.values) {
          if (pos.dx < minX) minX = pos.dx;
          if (pos.dx > maxX) maxX = pos.dx;
          if (pos.dy < minY) minY = pos.dy;
          if (pos.dy > maxY) maxY = pos.dy;
        }

        final double graphContentW = (maxX.isFinite && minX.isFinite) ? (maxX - minX + cardWidth) : 400.0;
        final double graphContentH = (maxY.isFinite && minY.isFinite) ? (maxY - minY + cardHeight) : 400.0;

        final double canvasWidth = math.max(viewportSize.width, graphContentW + 2000.0);
        final double canvasHeight = math.max(viewportSize.height, graphContentH + 2000.0);

        _lastViewportWidth = viewportSize.width;
        _lastViewportHeight = viewportSize.height;
        _lastCanvasWidth = canvasWidth;

        if (!_isInitialMatrixSet && viewportSize.width > 50) {
          _isInitialMatrixSet = true;
          _recenterCamera(animate: false);
        }

        final Map<String, List<ApiLogItem>> routeApis = {};
        final Map<String, List<ErrorLogItem>> routeErrors = {};
        final Map<String, int> routeVisits = {};
        final Map<String, Set<String>> seenApiOrders = {};
        final Map<String, Set<String>> seenErrorKeys = {};
        final Map<String, String> routeTypes = {};

        for (final r in uniqueRoutes) {
          routeApis[r] = [];
          routeErrors[r] = [];
          routeVisits[r] = 0;
          seenApiOrders[r] = {};
          seenErrorKeys[r] = {};
          routeTypes[r] = 'page';
        }

        for (final visit in visits) {
          if (!routeApis.containsKey(visit.route)) continue;
          routeTypes[visit.route] = visit.routeItem.routeType;
          for (final api in visit.apiLogs) {
            final key =
                '${api.timestamp.microsecondsSinceEpoch}_${api.method}_${api.url}';
            final seen = seenApiOrders[visit.route]!;
            if (seen.add(key)) {
              routeApis[visit.route]!.add(api);
            }
          }
          for (final err in visit.errorLogs) {
            final key =
                '${err.timestamp.microsecondsSinceEpoch}_${err.message.hashCode}';
            final seen = seenErrorKeys[visit.route]!;
            if (seen.add(key)) {
              routeErrors[visit.route]!.add(err);
            }
          }
          routeVisits[visit.route] = routeVisits[visit.route]! + 1;
        }

        final activeRoute = visits.isNotEmpty ? visits.last.route : '';

        final issueRoutes = <String>{};
        for (final route in uniqueRoutes) {
          final apis = routeApis[route] ?? [];
          final errors = routeErrors[route] ?? [];
          final hasSlow = apis.any((api) => api.isSlow);
          final hasError = errors.isNotEmpty;
          if (hasSlow || hasError) {
            issueRoutes.add(route);
          }
        }

        return Scaffold(
          backgroundColor: MonitorColors.pageBackground,
          body: Stack(
            children: [
              GestureDetector(
                onDoubleTapDown: (details) => _doubleTapDetails = details,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  constrained: false,
                  minScale: 0.15,
                  maxScale: 2.5,
                  boundaryMargin: const EdgeInsets.all(500.0),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_focusedRoute != null) {
                        setState(() => _focusedRoute = null);
                      }
                    },
                    child: Container(
                      width: canvasWidth,
                      height: canvasHeight,
                      color: MonitorColors.pageBackground,
                      child: Stack(
                        children: [
                          if (_showBgGrid)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _CanvasGridPainter(
                                  canvasWidth: canvasWidth,
                                  canvasHeight: canvasHeight,
                                  isDark: MonitorColors.isDark,
                                ),
                              ),
                            ),
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _pulseAnimationController,
                              builder: (context, _) {
                                return CustomPaint(
                                  painter: _StateGraphPainter(
                                    transitions: transitions,
                                    nodePositions: _activePositions,
                                    cardWidth: cardWidth,
                                    cardHeight: cardHeight,
                                    isDark: MonitorColors.isDark,
                                    pathMode: _pathMode,
                                    focusedRoute: _focusedRoute,
                                    pulseProgress: _pulseAnimationController.value,
                                    issueRoutes: issueRoutes,
                                    routeTypes: routeTypes,
                                  ),
                                );
                              },
                            ),
                          ),
                          for (final route in uniqueRoutes) ...[
                            if (_activePositions.containsKey(route))
                              Positioned(
                                left: _activePositions[route]!.dx - cardWidth / 2,
                                top: _activePositions[route]!.dy - cardHeight / 2,
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      final double currentScale =
                                          _transformationController.value
                                              .getMaxScaleOnAxis();
                                      if (currentScale > 0.05 &&
                                          currentScale.isFinite) {
                                        final currentPos = _activePositions[route] ??
                                            const Offset(baseCenterX, baseStartY);
                                        final newDx = (currentPos.dx +
                                                details.delta.dx / currentScale)
                                            .clamp(cardWidth / 2 + 16.0,
                                                canvasWidth - cardWidth / 2 - 16.0);
                                        final newDy = (currentPos.dy +
                                                details.delta.dy / currentScale)
                                            .clamp(cardHeight / 2 + 16.0,
                                                canvasHeight - cardHeight / 2 - 16.0);
                                        _activePositions[route] =
                                            Offset(newDx, newDy);
                                        _draggedRoutes.add(route);
                                      }
                                    });
                                  },
                                  child: _FlowMapStateCard(
                                    route: route,
                                    routeType: routeTypes[route] ?? 'page',
                                    visitCount: routeVisits[route] ?? 0,
                                    apiLogs: routeApis[route] ?? [],
                                    flutterErrors: routeErrors[route] ?? [],
                                    isCurrent: route == activeRoute,
                                    isFocused: route == _focusedRoute,
                                    width: cardWidth,
                                    height: cardHeight,
                                    onTap: () {
                                      setState(() {
                                        if (_focusedRoute == route) {
                                          final apis = routeApis[route] ?? [];
                                          final errors = routeErrors[route] ?? [];
                                          if (apis.isNotEmpty || errors.isNotEmpty) {
                                            _showScreenApisBottomSheet(
                                              route,
                                              apis,
                                              errors,
                                            );
                                          }
                                        } else {
                                          _focusedRoute = route;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: _MiniMap(
                  transformationController: _transformationController,
                  nodePositions: _activePositions,
                  transitions: transitions,
                  activeRoute: activeRoute,
                  canvasWidth: canvasWidth,
                  canvasHeight: canvasHeight,
                  viewportSize: viewportSize,
                  issueRoutes: issueRoutes,
                  onGesture: (localPos) => _handleMiniMapGesture(
                    localPos,
                    viewportSize,
                    canvasWidth,
                    canvasHeight,
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: _ZoomControls(
                  transformationController: _transformationController,
                  onZoomIn: _zoomIn,
                  onZoomOut: _zoomOut,
                ),
              ),
              Positioned(
                top: widget.isFullScreen
                    ? MediaQuery.of(context).padding.top + 16
                    : 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: MonitorColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: MonitorColors.divider, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isFullScreen) ...[
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded,
                              color: MonitorColors.primaryText, size: 16),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: LocaleKeys.mapBack.tr,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                        Container(
                            width: 1, height: 20, color: MonitorColors.divider),
                      ],
                      // 1. Layout mode
                      IconButton(
                        icon: Icon(
                          _layoutMode == MapLayoutMode.tree
                              ? Icons.account_tree_rounded
                              : _layoutMode == MapLayoutMode.grid
                                  ? Icons.grid_view_rounded
                                  : _layoutMode == MapLayoutMode.stream
                                      ? Icons.view_stream_rounded
                                      : Icons.circle_outlined,
                          color: MonitorColors.primaryText,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _isInitialMatrixSet = false;
                            _activePositions.clear();
                            _draggedRoutes.clear();
                            if (_layoutMode == MapLayoutMode.tree) {
                              _layoutMode = MapLayoutMode.grid;
                            } else if (_layoutMode == MapLayoutMode.grid) {
                              _layoutMode = MapLayoutMode.stream;
                            } else if (_layoutMode == MapLayoutMode.stream) {
                              _layoutMode = MapLayoutMode.circular;
                            } else {
                              _layoutMode = MapLayoutMode.tree;
                            }
                          });
                        },
                        tooltip: _layoutMode == MapLayoutMode.tree
                            ? LocaleKeys.mapSwitchGrid.tr
                            : _layoutMode == MapLayoutMode.grid
                                ? LocaleKeys.mapSwitchStream.tr
                                : _layoutMode == MapLayoutMode.stream
                                    ? LocaleKeys.mapSwitchCircular.tr
                                    : LocaleKeys.mapSwitchTree.tr,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      Container(
                          width: 1, height: 20, color: MonitorColors.divider),
                      // 2. Path Style mode (Curved / Metro / Arc)
                      IconButton(
                        icon: Icon(
                          _pathMode == MapPathMode.curved
                              ? Icons.alt_route_rounded
                              : _pathMode == MapPathMode.orthogonal
                                  ? Icons.polyline_rounded
                                  : Icons.gesture_rounded,
                          color: MonitorColors.primaryText,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_pathMode == MapPathMode.curved) {
                              _pathMode = MapPathMode.orthogonal;
                            } else if (_pathMode == MapPathMode.orthogonal) {
                              _pathMode = MapPathMode.arc;
                            } else {
                              _pathMode = MapPathMode.curved;
                            }
                          });
                        },
                        tooltip: _pathMode == MapPathMode.curved
                            ? 'Kiểu đường: Bézier - Nhấn để đổi sang Metro'
                            : _pathMode == MapPathMode.orthogonal
                                ? 'Kiểu đường: Metro - Nhấn để đổi sang Vòng cung'
                                : 'Kiểu đường: Vòng cung - Nhấn để đổi sang Bézier',
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      Container(
                          width: 1, height: 20, color: MonitorColors.divider),
                      // 3. Recenter camera
                      IconButton(
                        icon: Icon(Icons.gps_fixed_rounded,
                            color: MonitorColors.primaryText, size: 18),
                        onPressed: _recenterCamera,
                        tooltip: LocaleKeys.mapRecenterCamera.tr,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      Container(
                          width: 1, height: 20, color: MonitorColors.divider),
                      IconButton(
                        icon: Icon(Icons.search_rounded,
                            color: MonitorColors.primaryText, size: 18),
                        onPressed: () => _showSearchNodeSheet(uniqueRoutes),
                        tooltip: LocaleKeys.mapSearchScreen.tr,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),

                      Container(
                          width: 1, height: 20, color: MonitorColors.divider),
                      IconButton(
                        icon: Icon(Icons.share_rounded,
                            color: MonitorColors.primaryText, size: 18),
                        onPressed: () => _exportInteractiveMapHtml(
                          uniqueRoutes,
                          transitions,
                          canvasWidth,
                          canvasHeight,
                        ),
                        tooltip: LocaleKeys.mapExportWeb.tr,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      Container(
                          width: 1, height: 20, color: MonitorColors.divider),
                      // 3. Background grid dots
                      IconButton(
                        icon: Icon(
                          _showBgGrid
                              ? Icons.grid_on_rounded
                              : Icons.grid_off_rounded,
                          color: MonitorColors.primaryText,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _showBgGrid = !_showBgGrid;
                          });
                        },
                        tooltip: _showBgGrid
                            ? LocaleKeys.mapHideGrid.tr
                            : LocaleKeys.mapShowGrid.tr,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      Container(
                          width: 1, height: 20, color: MonitorColors.divider),
                      IconButton(
                        icon: Icon(Icons.refresh,
                            color: MonitorColors.primaryText, size: 18),
                        onPressed: () => _confirmAndResetZoom(context),
                        tooltip: LocaleKeys.mapResetLayoutZoom.tr,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      Container(
                          width: 1, height: 20, color: MonitorColors.divider),
                      IconButton(
                        icon: Icon(
                          widget.isFullScreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          color: MonitorColors.primaryText,
                          size: 18,
                        ),
                        onPressed: () {
                          if (widget.isFullScreen) {
                            Navigator.of(context).pop();
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                settings: const RouteSettings(name: MonitorConstants.flowMapFullScreen),
                                builder: (context) => const Scaffold(
                                  body: _FlowMapList(isFullScreen: true),
                                ),
                              ),
                            );
                          }
                        },
                        tooltip: widget.isFullScreen
                            ? LocaleKeys.mapExitFullScreen.tr
                            : LocaleKeys.mapFullScreen.tr,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RouteTransition {
  final String from;
  final String to;
  int count = 1;
  final bool isBack;

  _RouteTransition({
    required this.from,
    required this.to,
    this.isBack = false,
  });

  String get key => '$from->$to';
}

class _FlowMapStateCard extends StatelessWidget {
  final String route;
  final String routeType;
  final int visitCount;
  final List<ApiLogItem> apiLogs;
  final List<ErrorLogItem> flutterErrors;
  final bool isCurrent;
  final bool isFocused;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _FlowMapStateCard({
    required this.route,
    required this.routeType,
    required this.visitCount,
    required this.apiLogs,
    required this.flutterErrors,
    required this.isCurrent,
    this.isFocused = false,
    required this.width,
    required this.height,
    required this.onTap,
  });

  Widget _buildTypeBadge(String type) {
    Color bg;
    Color text;
    String label;

    switch (type) {
      case 'bottomSheet':
        label = 'SHEET';
        bg = const Color(0xFF7B61FF).withValues(alpha: 0.12);
        text = const Color(0xFF7B61FF);
        break;
      case 'dialog':
        label = 'DIALOG';
        bg = const Color(0xFFFF9800).withValues(alpha: 0.12);
        text = const Color(0xFFFF9800);
        break;
      case 'popup':
        label = 'POPUP';
        bg = const Color(0xFFE91E63).withValues(alpha: 0.12);
        text = const Color(0xFFE91E63);
        break;
      case 'page':
      default:
        label = 'PAGE';
        bg = const Color(0xFF2196F3).withValues(alpha: 0.12);
        text = const Color(0xFF2196F3);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: text.withValues(alpha: 0.25), width: 0.5),
      ),
      child: MonoText(
        label,
        6.5,
        color: text,
        weight: FontWeight.bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalApis = apiLogs.length;
    final errorCount = apiLogs.where((api) => !api.isSuccess).length;
    final slowCount = apiLogs.where((api) => api.isSlow).length;
    final successCount =
        apiLogs.where((api) => api.isSuccess && !api.isSlow).length;

    final hasIssues = errorCount > 0 || flutterErrors.isNotEmpty;
    final hasWarning = slowCount > 0;

    Color borderThemeColor = const Color(0xFF57D888);
    if (hasIssues) {
      borderThemeColor = MonitorColors.statusError;
    } else if (hasWarning) {
      borderThemeColor = MonitorColors.statusSlow;
    }

    Color borderColor;
    double borderWidth = 1.0;
    if (isFocused) {
      borderColor = const Color(0xFF6366F1);
      borderWidth = 2.2;
    } else if (isCurrent) {
      borderColor = borderThemeColor;
      borderWidth = 2.0;
    } else if (hasIssues || hasWarning) {
      borderColor = borderThemeColor.withValues(alpha: 0.7);
      borderWidth = 1.2;
    } else {
      borderColor = MonitorColors.border;
      borderWidth = 1.0;
    }

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: borderColor,
              width: borderWidth,
            ),
          ),
          color: MonitorColors.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isCurrent) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: borderThemeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: MonoText(
                          'ACTIVE',
                          6,
                          color: borderThemeColor,
                          weight: FontWeight.bold,
                        ),
                      ),
                    ],
                    _buildTypeBadge(routeType),
                    Expanded(
                      child: MonoText(
                        MonitorController.formatRouteName(route),
                        10,
                        color: MonitorColors.primaryText,
                        weight: FontWeight.bold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (flutterErrors.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color:
                              MonitorColors.statusError.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: MonitorColors.statusError
                                  .withValues(alpha: 0.3),
                              width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bug_report_rounded,
                                size: 7.5, color: MonitorColors.statusError),
                            const SizedBox(width: 2),
                            MonoText(
                              '${flutterErrors.length}',
                              7.5,
                              color: MonitorColors.statusError,
                              weight: FontWeight.bold,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.directions_run_rounded,
                        size: 9, color: MonitorColors.secondaryText),
                    const SizedBox(width: 3),
                    MonoText(
                      LocaleKeys.mapVisitsCount.trWith({'count': visitCount}),
                      8.5,
                      color: MonitorColors.secondaryText,
                    ),
                  ],
                ),
                Container(
                  height: 3.5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: MonitorColors.pageBackground,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: totalApis == 0
                        ? Container(
                            color: MonitorColors.border.withValues(alpha: 0.2))
                        : Row(
                            children: [
                              if (successCount > 0)
                                Expanded(
                                  flex: successCount,
                                  child:
                                      Container(color: const Color(0xFF57D888)),
                                ),
                              if (slowCount > 0)
                                Expanded(
                                  flex: slowCount,
                                  child: Container(
                                      color: MonitorColors.statusSlow),
                                ),
                              if (errorCount > 0)
                                Expanded(
                                  flex: errorCount,
                                  child: Container(
                                      color: MonitorColors.statusError),
                                ),
                            ],
                          ),
                  ),
                ),
                Row(
                  children: [
                    MonoText(
                      LocaleKeys.mapRequestsCount.trWith({'count': totalApis}),
                      8,
                      color: MonitorColors.primaryText,
                      weight: FontWeight.bold,
                    ),
                    if (totalApis > 0) ...[
                      const SizedBox(width: 4),
                      _buildMiniBadge(successCount, const Color(0xFF57D888)),
                      const SizedBox(width: 2),
                      _buildMiniBadge(slowCount, MonitorColors.statusSlow),
                      const SizedBox(width: 2),
                      _buildMiniBadge(errorCount, MonitorColors.statusError),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildMiniBadge(int count, Color color) {
    if (count == 0) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: MonoText(
        '$count',
        6.5,
        color: color,
        weight: FontWeight.bold,
      ),
    );
  }
}

class _StateGraphPainter extends CustomPainter {
  final List<_RouteTransition> transitions;
  final Map<String, Offset> nodePositions;
  final double cardWidth;
  final double cardHeight;
  final bool isDark;
  final MapPathMode pathMode;
  final String? focusedRoute;
  final double pulseProgress;
  final Set<String> issueRoutes;
  final Map<String, String> routeTypes;

  _StateGraphPainter({
    required this.transitions,
    required this.nodePositions,
    required this.cardWidth,
    required this.cardHeight,
    required this.isDark,
    this.pathMode = MapPathMode.curved,
    this.focusedRoute,
    this.pulseProgress = 0.0,
    required this.issueRoutes,
    required this.routeTypes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()..style = PaintingStyle.fill;

    final Set<String> bidirectionalKeys = {};
    for (final t in transitions) {
      final reverseKey = '${t.to}->${t.from}';
      if (transitions.any((x) => x.key == reverseKey)) {
        bidirectionalKeys.add(t.key);
      }
    }

    final bool hasFocusActive = focusedRoute != null;

    for (final t in transitions) {
      final fromPos = nodePositions[t.from];
      final toPos = nodePositions[t.to];
      if (fromPos == null || toPos == null) continue;

      final bool isSelf = t.from == t.to;
      final bool isBidirectional = bidirectionalKeys.contains(t.key);
      final path = _buildPath(
        fromPos: fromPos,
        toPos: toPos,
        isBack: t.isBack,
        isSelf: isSelf,
        isBidirectional: isBidirectional,
        size: size,
      );

      final String targetType = routeTypes[t.to] ?? '';
      final bool isDialog = targetType == 'dialog' ||
          targetType == 'sheet' ||
          targetType == 'bottomSheet' ||
          targetType == 'popup' ||
          t.to.toLowerCase().contains('dialog') ||
          t.to.toLowerCase().contains('bottomsheet');
      final bool hasError = issueRoutes.contains(t.to);
      final bool isFocused = focusedRoute != null &&
          (t.from == focusedRoute || t.to == focusedRoute);

      final double alphaMultiplier =
          hasFocusActive ? (isFocused ? 1.0 : 0.12) : 0.88;

      Color lineColor;
      if (hasError) {
        lineColor = const Color(0xFFEF4444); // Red
      } else if (t.isBack) {
        lineColor = const Color(0xFFF59E0B); // Amber
      } else if (isDialog) {
        lineColor = const Color(0xFFA855F7); // Magenta / Purple
      } else {
        lineColor = const Color(0xFF6366F1); // Indigo
      }

      final strokeW = isFocused
          ? 3.2
          : (t.count > 1 ? math.min(3.2, 1.8 + t.count * 0.35) : 2.0);

      // Glow effect if focused
      if (isFocused) {
        final glowPaint = Paint()
          ..color = lineColor.withValues(alpha: 0.35 * alphaMultiplier)
          ..strokeWidth = strokeW + 5.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, glowPaint);
      }

      linePaint.color = lineColor.withValues(alpha: alphaMultiplier);
      linePaint.strokeWidth = strokeW;
      linePaint.strokeCap = StrokeCap.round;

      if (isDialog) {
        _drawDashedPath(canvas, path, linePaint, const [7.0, 4.0]);
      } else if (t.isBack) {
        _drawDashedPath(canvas, path, linePaint, const [3.0, 4.0]);
      } else {
        canvas.drawPath(path, linePaint);
      }

      final pathMetrics = path.computeMetrics().toList();
      for (final metric in pathMetrics) {
        if (metric.length < 10) continue;

        // 1. Sleek Arrowhead at end
        final tangentEnd = metric.getTangentForOffset(metric.length - 3);
        if (tangentEnd != null) {
          final angle = -tangentEnd.angle;
          final pEnd = tangentEnd.position;
          final double arrowSize = isFocused ? 9.5 : 8.0;
          final arrowPath = Path()
            ..moveTo(pEnd.dx, pEnd.dy)
            ..lineTo(
              pEnd.dx - arrowSize * math.cos(angle - 0.45),
              pEnd.dy - arrowSize * math.sin(angle - 0.45),
            )
            ..lineTo(
              pEnd.dx - (arrowSize * 0.6) * math.cos(angle),
              pEnd.dy - (arrowSize * 0.6) * math.sin(angle),
            )
            ..lineTo(
              pEnd.dx - arrowSize * math.cos(angle + 0.45),
              pEnd.dy - arrowSize * math.sin(angle + 0.45),
            )
            ..close();

          arrowPaint.color = lineColor.withValues(alpha: alphaMultiplier);
          canvas.drawPath(arrowPath, arrowPaint);
        }

        // 2. Animated Flow Wave / Particle
        if (pulseProgress >= 0.0 && (!hasFocusActive || isFocused)) {
          final double phase = (t.key.hashCode.abs() % 100) / 100.0;
          final double particleOffset =
              metric.length * ((pulseProgress + phase) % 1.0);
          final particleTangent = metric.getTangentForOffset(particleOffset);
          if (particleTangent != null) {
            final particlePaint = Paint()
              ..color = isDark
                  ? Colors.white.withValues(alpha: 0.95)
                  : lineColor.withValues(alpha: 0.95)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(
                particleTangent.position, isFocused ? 3.5 : 2.5, particlePaint);

            final particleGlow = Paint()
              ..color = lineColor.withValues(alpha: 0.45)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(
                particleTangent.position, isFocused ? 7.0 : 5.0, particleGlow);
          }
        }

        // 3. Traffic Badge for count > 1
        if (t.count > 1 && (!hasFocusActive || isFocused)) {
          final midTangent = metric.getTangentForOffset(metric.length * 0.5);
          if (midTangent != null) {
            final midPos = midTangent.position;
            final String countText = '×${t.count}';
            final textSpan = TextSpan(
              text: countText,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: lineColor,
              ),
            );
            final textPainter = TextPainter(
              text: textSpan,
              textDirection: TextDirection.ltr,
            )..layout();

            final badgeW = textPainter.width + 10.0;
            const badgeH = 16.0;
            final badgeRect = RRect.fromRectAndRadius(
              Rect.fromCenter(center: midPos, width: badgeW, height: badgeH),
              const Radius.circular(8.0),
            );

            final badgeBgPaint = Paint()
              ..color = isDark ? const Color(0xFF0F172A) : Colors.white
              ..style = PaintingStyle.fill;
            final badgeBorderPaint = Paint()
              ..color = lineColor.withValues(alpha: 0.6)
              ..strokeWidth = 1.0
              ..style = PaintingStyle.stroke;

            canvas.drawRRect(badgeRect, badgeBgPaint);
            canvas.drawRRect(badgeRect, badgeBorderPaint);

            textPainter.paint(
              canvas,
              Offset(midPos.dx - textPainter.width / 2,
                  midPos.dy - textPainter.height / 2),
            );
          }
        }
      }
    }
  }

  Path _buildPath({
    required Offset fromPos,
    required Offset toPos,
    required bool isBack,
    required bool isSelf,
    required bool isBidirectional,
    required Size size,
  }) {
    if (isSelf) {
      final double topCenterY = fromPos.dy - cardHeight / 2;
      final double startX = fromPos.dx + cardWidth * 0.22;
      final double endX = fromPos.dx - cardWidth * 0.22;
      final p = Path()..moveTo(startX, topCenterY);
      p.cubicTo(
        startX + 30.0,
        topCenterY - 45.0,
        endX - 30.0,
        topCenterY - 45.0,
        endX,
        topCenterY,
      );
      return p;
    }

    final double dx = toPos.dx - fromPos.dx;
    final double dy = toPos.dy - fromPos.dy;
    final double dist = math.sqrt(dx * dx + dy * dy);

    if (pathMode == MapPathMode.orthogonal) {
      final bool isDown = dy >= 0;
      final double trackShiftX = isBack
          ? 26.0
          : (isBidirectional ? -26.0 : 0.0);
      final double trackShiftMidY = isBack
          ? (isDown ? -18.0 : 18.0)
          : (isBidirectional ? (isDown ? 18.0 : -18.0) : 0.0);

      final Offset startPoint = isDown
          ? Offset(fromPos.dx + trackShiftX, fromPos.dy + cardHeight / 2)
          : Offset(fromPos.dx + trackShiftX, fromPos.dy - cardHeight / 2);
      final Offset endPoint = isDown
          ? Offset(toPos.dx + trackShiftX, toPos.dy - cardHeight / 2)
          : Offset(toPos.dx + trackShiftX, toPos.dy + cardHeight / 2);

      final double midY = (startPoint.dy + endPoint.dy) / 2 + trackShiftMidY;
      const double radius = 16.0;

      final p = Path()..moveTo(startPoint.dx, startPoint.dy);
      if ((startPoint.dx - endPoint.dx).abs() < 10.0) {
        p.lineTo(endPoint.dx, endPoint.dy);
      } else {
        final double dirY = (endPoint.dy - startPoint.dy).sign;
        final double dirX = (endPoint.dx - startPoint.dx).sign;
        final double r = math.min(
            radius,
            math.min((startPoint.dx - endPoint.dx).abs() / 2,
                (startPoint.dy - endPoint.dy).abs() / 2));

        p.lineTo(startPoint.dx, midY - dirY * r);
        p.quadraticBezierTo(
            startPoint.dx, midY, startPoint.dx + dirX * r, midY);
        p.lineTo(endPoint.dx - dirX * r, midY);
        p.quadraticBezierTo(endPoint.dx, midY, endPoint.dx, midY + dirY * r);
        p.lineTo(endPoint.dx, endPoint.dy);
      }
      return p;
    }

    if (pathMode == MapPathMode.curved) {
      Offset startPoint;
      Offset endPoint;
      Offset c1;
      Offset c2;

      final double lateralAnchorShift = isBack
          ? 32.0
          : (isBidirectional ? -24.0 : 0.0);

      if (isBack) {
        final bool bendLeft = fromPos.dx >= toPos.dx;
        final double lateralOffset = bendLeft ? -75.0 : 75.0;
        startPoint = Offset(
            fromPos.dx + (bendLeft ? -cardWidth / 3 : cardWidth / 3) + lateralAnchorShift,
            fromPos.dy - cardHeight / 2);
        endPoint = Offset(
            toPos.dx + (bendLeft ? -cardWidth / 3 : cardWidth / 3) + lateralAnchorShift,
            toPos.dy + cardHeight / 2);
        c1 = Offset(startPoint.dx + lateralOffset, startPoint.dy - 48.0);
        c2 = Offset(endPoint.dx + lateralOffset, endPoint.dy + 48.0);
      } else if (dy.abs() >= dx.abs()) {
        final bool isDown = dy > 0;
        startPoint = Offset(
            fromPos.dx + lateralAnchorShift,
            fromPos.dy + (isDown ? cardHeight / 2 : -cardHeight / 2));
        endPoint = Offset(
            toPos.dx + lateralAnchorShift,
            toPos.dy + (isDown ? -cardHeight / 2 : cardHeight / 2));
        final double handleY = (endPoint.dy - startPoint.dy) * 0.5;
        c1 = Offset(startPoint.dx, startPoint.dy + handleY);
        c2 = Offset(endPoint.dx, endPoint.dy - handleY);
      } else {
        final bool isRight = dx > 0;
        startPoint = Offset(
            fromPos.dx + (isRight ? cardWidth / 2 : -cardWidth / 2),
            fromPos.dy + lateralAnchorShift * 0.5);
        endPoint = Offset(
            toPos.dx + (isRight ? -cardWidth / 2 : cardWidth / 2),
            toPos.dy + lateralAnchorShift * 0.5);
        final double handleX = (endPoint.dx - startPoint.dx) * 0.5;
        c1 = Offset(startPoint.dx + handleX, startPoint.dy);
        c2 = Offset(endPoint.dx - handleX, endPoint.dy);
      }

      final p = Path()..moveTo(startPoint.dx, startPoint.dy);
      p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, endPoint.dx, endPoint.dy);
      return p;
    }

    // Default: MapPathMode.arc (Outward Quadratic Arc)
    if (dist < 1.0) return Path()..moveTo(fromPos.dx, fromPos.dy);
    final double ux = dx / dist;
    final double uy = dy / dist;

    final double edgeOffsetFrom = _getEdgeOffset(ux, uy);
    final double edgeOffsetTo = _getEdgeOffset(-ux, -uy);

    final startPoint =
        fromPos + Offset(ux * edgeOffsetFrom, uy * edgeOffsetFrom);
    final endPoint = toPos - Offset(ux * edgeOffsetTo, uy * edgeOffsetTo);

    final double curveOffset = isBack
        ? (-38.0 - dist * 0.045)
        : (isBidirectional ? (30.0 + dist * 0.035) : (20.0 + dist * 0.025));

    final double px = -uy;
    final double py = ux;

    final controlPoint = Offset(
      (startPoint.dx + endPoint.dx) / 2 + px * curveOffset,
      (startPoint.dy + endPoint.dy) / 2 + py * curveOffset,
    );

    return Path()
      ..moveTo(startPoint.dx, startPoint.dy)
      ..quadraticBezierTo(
          controlPoint.dx, controlPoint.dy, endPoint.dx, endPoint.dy);
  }

  void _drawDashedPath(
      Canvas canvas, Path path, Paint paint, List<double> dashArray) {
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0.0;
      int dashIndex = 0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = dashArray[dashIndex % dashArray.length];
        final double nextDistance = math.min(distance + len, metric.length);
        if (draw) {
          final extract = metric.extractPath(distance, nextDistance);
          canvas.drawPath(extract, paint);
        }
        distance = nextDistance;
        dashIndex++;
        draw = !draw;
      }
    }
  }

  double _getEdgeOffset(double ux, double uy) {
    final double halfW = cardWidth / 2;
    final double halfH = cardHeight / 2;
    if (ux.abs() < 0.001) return halfH;
    final double slope = uy / ux;
    final double xDist = halfW;
    final double yDist = (halfW * slope).abs();
    if (yDist <= halfH) {
      return math.sqrt(xDist * xDist + yDist * yDist);
    } else {
      final double yDist2 = halfH;
      final double xDist2 = (halfH / slope).abs();
      return math.sqrt(xDist2 * xDist2 + yDist2 * yDist2);
    }
  }

  @override
  bool shouldRepaint(covariant _StateGraphPainter oldDelegate) {
    return true;
  }
}

class _ScreenVisit {
  final String route;
  final DateTime startTime;
  DateTime? endTime;
  final List<ApiLogItem> apiLogs = [];
  final List<ErrorLogItem> errorLogs = [];
  final RouteLogItem routeItem;
  final int depth;

  _ScreenVisit({
    required this.route,
    required this.startTime,
    required this.routeItem,
    required this.depth,
  });

  Duration get duration => endTime != null
      ? endTime!.difference(startTime)
      : DateTime.now().difference(startTime);

  int get errorCount => apiLogs.where((api) => !api.isSuccess).length;
  int get slowCount => apiLogs.where((api) => api.isSlow).length;
  int get successCount =>
      apiLogs.where((api) => api.isSuccess && !api.isSlow).length;
}

class _MiniMap extends StatelessWidget {
  final TransformationController transformationController;
  final Map<String, Offset> nodePositions;
  final List<_RouteTransition> transitions;
  final String activeRoute;
  final double canvasWidth;
  final double canvasHeight;
  final Size viewportSize;
  final Function(Offset localPos)? onGesture;
  final Set<String> issueRoutes;

  static const double width = 120.0;
  static const double height = 75.0;

  const _MiniMap({
    required this.transformationController,
    required this.nodePositions,
    required this.transitions,
    required this.activeRoute,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.viewportSize,
    required this.issueRoutes,
    this.onGesture,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => onGesture?.call(details.localPosition),
      onPanUpdate: (details) => onGesture?.call(details.localPosition),
      onTapDown: (details) => onGesture?.call(details.localPosition),
      child: ValueListenableBuilder<Matrix4>(
        valueListenable: transformationController,
        builder: (context, matrix, _) {
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: MonitorColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MonitorColors.divider, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: _MiniMapPainter(
                  matrix: matrix,
                  nodePositions: nodePositions,
                  transitions: transitions,
                  activeRoute: activeRoute,
                  canvasWidth: canvasWidth,
                  canvasHeight: canvasHeight,
                  viewportSize: viewportSize,
                  width: width,
                  height: height,
                  isDark: MonitorColors.isDark,
                  issueRoutes: issueRoutes,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  final Matrix4 matrix;
  final Map<String, Offset> nodePositions;
  final List<_RouteTransition> transitions;
  final String activeRoute;
  final double canvasWidth;
  final double canvasHeight;
  final Size viewportSize;
  final double width;
  final double height;
  final bool isDark;
  final Set<String> issueRoutes;

  _MiniMapPainter({
    required this.matrix,
    required this.nodePositions,
    required this.transitions,
    required this.activeRoute,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.viewportSize,
    required this.width,
    required this.height,
    required this.isDark,
    required this.issueRoutes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodePositions.isEmpty) return;

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final pos in nodePositions.values) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dy > maxY) maxY = pos.dy;
    }

    const double cardHalfW = 90.0;
    const double cardHalfH = 32.5;

    minX -= cardHalfW;
    maxX += cardHalfW;
    minY -= cardHalfH;
    maxY += cardHalfH;

    final contentW = (maxX - minX).abs();
    final contentH = (maxY - minY).abs();
    final double safeContentW = contentW < 1 ? 1 : contentW;
    final double safeContentH = contentH < 1 ? 1 : contentH;

    const double padding = 6.0;
    final double scaleX = (width - padding * 2) / safeContentW;
    final double scaleY = (height - padding * 2) / safeContentH;
    final double mmScale = math.min(scaleX, scaleY);

    final double offsetX =
        padding + (width - padding * 2 - safeContentW * mmScale) / 2;
    final double offsetY =
        padding + (height - padding * 2 - safeContentH * mmScale) / 2;

    Offset toMiniMap(Offset point) {
      return Offset(
        (point.dx - minX) * mmScale + offsetX,
        (point.dy - minY) * mmScale + offsetY,
      );
    }

    // 0. Draw dot grid (matching HTML)
    final dotPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    for (double gx = padding; gx < width - padding; gx += 14) {
      for (double gy = padding; gy < height - padding; gy += 14) {
        canvas.drawCircle(Offset(gx, gy), 0.6, dotPaint);
      }
    }

    // 1. Draw connections
    final linePaint = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (final t in transitions) {
      final from = nodePositions[t.from];
      final to = nodePositions[t.to];
      if (from == null || to == null) continue;

      final start = toMiniMap(from);
      final end = toMiniMap(to);

      // HTML uses a uniform light blue for connections
      linePaint.color = const Color(0xFF4F8EF7).withValues(alpha: 0.25);
      canvas.drawLine(start, end, linePaint);
    }

    // 2. Draw nodes
    final nodePaint = Paint()..style = PaintingStyle.fill;
    final nodeBorderPaint = Paint()
      ..color = const Color(0xFF4F8EF7).withValues(alpha: 0.6)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (final entry in nodePositions.entries) {
      final route = entry.key;
      final pos = entry.value;

      final center = toMiniMap(pos);

      final isCurrent = route == activeRoute;
      // HTML uses blue for all nodes, we keep active node green to stand out
      nodePaint.color = isCurrent
          ? const Color(0xFF57D888)
          : const Color(0xFF4F8EF7).withValues(alpha: 0.7);

      final nodeW = math.max(6.0, 180.0 * mmScale);
      final nodeH = math.max(4.0, 65.0 * mmScale);
      
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: nodeW,
          height: nodeH,
        ),
        const Radius.circular(1.5),
      );

      canvas.drawRRect(rrect, nodePaint);
      canvas.drawRRect(rrect, nodeBorderPaint);

      if (issueRoutes.contains(route)) {
        final dotRadius = math.max(1.5, math.min(3.0, nodeW / 8));
        final dotPaint = Paint()..color = const Color(0xFFEF4444);
        final dotCenter = Offset(
          center.dx + nodeW / 2 - dotRadius - 1,
          center.dy - nodeH / 2 + dotRadius + 1,
        );
        canvas.drawCircle(dotCenter, dotRadius, dotPaint);
      }
    }

    // 3. Draw viewport indicator (fixed small box centered on viewport)

    // Compute the world coordinates of the viewport center using the inverse matrix
    final Matrix4 inv = Matrix4.copy(matrix);
    inv.invert();
    final Offset viewCenter =
        Offset(viewportSize.width / 2, viewportSize.height / 2);
    final Offset worldCenter = MatrixUtils.transformPoint(inv, viewCenter);
    // Map this world center to mini‑map coordinates
    final miniCenter = toMiniMap(worldCenter);

    // Fixed small size (same as HTML implementation)
    const double fixedW = 16.0;
    const double fixedH = 11.0;
    Rect miniViewportRect = Rect.fromCenter(
      center: miniCenter,
      width: fixedW,
      height: fixedH,
    );

    // HTML uses a red dashed box; we use a thin red box for performance
    final viewportPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    final viewportBorderPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawRect(miniViewportRect, viewportPaint);
    canvas.drawRect(miniViewportRect, viewportBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) {
    return oldDelegate.matrix != matrix ||
        oldDelegate.viewportSize != viewportSize ||
        oldDelegate.canvasWidth != canvasWidth ||
        oldDelegate.canvasHeight != canvasHeight ||
        oldDelegate.isDark != isDark;
  }
}

class _CanvasGridPainter extends CustomPainter {
  final double canvasWidth;
  final double canvasHeight;
  final bool isDark;

  _CanvasGridPainter({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotColor = isDark
        ? Colors.white.withValues(alpha: 0.30)
        : Colors.black.withValues(alpha: 0.22);

    paint.color = dotColor;

    const double step = 28.0;
    final List<Offset> points = [];

    for (double x = 0; x <= canvasWidth; x += step) {
      for (double y = 0; y <= canvasHeight; y += step) {
        points.add(Offset(x, y));
      }
    }

    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant _CanvasGridPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.canvasWidth != canvasWidth ||
        oldDelegate.canvasHeight != canvasHeight;
  }
}

class _ZoomControls extends StatelessWidget {
  final TransformationController transformationController;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _ZoomControls({
    required this.transformationController,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MonitorColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MonitorColors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ValueListenableBuilder<Matrix4>(
        valueListenable: transformationController,
        builder: (context, matrix, _) {
          final double scale = matrix.getMaxScaleOnAxis();
          final int percentage = (scale * 100).round();

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.remove,
                    color: MonitorColors.primaryText, size: 16),
                onPressed: onZoomOut,
                tooltip: LocaleKeys.mapZoomOut.tr,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 42),
                alignment: Alignment.center,
                child: MonoText(
                  '$percentage%',
                  10.5,
                  color: MonitorColors.primaryText,
                  weight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon:
                    Icon(Icons.add, color: MonitorColors.primaryText, size: 16),
                onPressed: onZoomIn,
                tooltip: LocaleKeys.mapZoomIn.tr,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MapSearchSheet extends StatefulWidget {
  final List<String> routes;
  final ValueChanged<String> onSelected;

  const _MapSearchSheet({
    required this.routes,
    required this.onSelected,
  });

  @override
  State<_MapSearchSheet> createState() => _MapSearchSheetState();
}

class _MapSearchSheetState extends State<_MapSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredRoutes = [];

  @override
  void initState() {
    super.initState();
    _filteredRoutes = widget.routes;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredRoutes = widget.routes;
      } else {
        _filteredRoutes = widget.routes.where((r) {
          final title = MonitorController.formatRouteName(r).toLowerCase();
          final path = r.toLowerCase();
          return title.contains(query) || path.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: MonitorColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: MonitorColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  BodyText(LocaleKeys.mapSearchTitle.tr, 15,
                      weight: FontWeight.bold),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: MonitorColors.secondaryText, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style:
                    TextStyle(color: MonitorColors.primaryText, fontSize: 14),
                decoration: InputDecoration(
                  hintText: LocaleKeys.mapSearchHint.tr,
                  hintStyle: TextStyle(
                      color: MonitorColors.secondaryText, fontSize: 13),
                  prefixIcon: Icon(Icons.search,
                      color: MonitorColors.secondaryText, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: MonitorColors.secondaryText, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: MonitorColors.pageBackground,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: MonitorColors.divider),
            Flexible(
              child: _filteredRoutes.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 40, color: MonitorColors.secondaryText),
                          const SizedBox(height: 8),
                          BodyText(LocaleKeys.mapSearchNotFound.tr, 13,
                              color: MonitorColors.secondaryText),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredRoutes.length,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (context, index) {
                        final r = _filteredRoutes[index];
                        final title = MonitorController.formatRouteName(r);
                        final isPopup =
                            r.contains('dialog') || r.contains('bottomSheet');

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: (isPopup ? Colors.amber : Colors.blue)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              isPopup
                                  ? Icons.filter_none_rounded
                                  : Icons.crop_portrait_rounded,
                              size: 16,
                              color: isPopup ? Colors.amber : Colors.blue,
                            ),
                          ),
                          title: BodyText(title, 14, weight: FontWeight.w600),
                          subtitle: MonoText(
                            r.contains('#') ? r.split('#').first : r,
                            11,
                            color: MonitorColors.secondaryText,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onSelected(r);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
