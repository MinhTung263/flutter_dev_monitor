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

class _FlowMapListState extends State<_FlowMapList>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _mapAnimation;

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
    _transformationController.addListener(_onTransformationChanged);
  }

  void _onTransformationChanged() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
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
      routeSettings: const RouteSettings(name: '/MonitorScreenApiDetail'),
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

  void _recenterCamera() {
    if (_activePositions.isEmpty) {
      final initialTx = (_lastViewportWidth - _lastCanvasWidth) / 2;
      final targetMatrix = Matrix4.translationValues(initialTx, 0.0, 0.0);
      _animateToMatrix(targetMatrix);
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

    const double cardWidth = 180.0;
    const double cardHeight = 65.0;

    final double graphWidth = (maxX - minX) + cardWidth + 80.0;
    final double graphHeight = (maxY - minY) + cardHeight + 80.0;

    final double graphCenterX = (minX + maxX) / 2;
    final double graphCenterY = (minY + maxY) / 2;

    final double scaleX = _lastViewportWidth / graphWidth;
    final double scaleY = _lastViewportHeight / graphHeight;

    double fitScale = math.min(scaleX, scaleY);
    fitScale = fitScale.clamp(0.7, 1.0);

    final double tx = (_lastViewportWidth / 2) - (graphCenterX * fitScale);
    final double ty = (_lastViewportHeight / 2) - (graphCenterY * fitScale);

    final targetMatrix = Matrix4.identity()
      ..setEntry(0, 0, fitScale)
      ..setEntry(1, 1, fitScale)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);

    _animateToMatrix(targetMatrix);
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

      final tempDir = await getTemporaryDirectory();
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
    _transformationController.removeListener(_onTransformationChanged);
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

        final double spacingY = 220.0;
        double startY = 80.0;

        const double cardWidth = 180.0;
        const double cardHeight = 90.0;

        int maxLayerSize = 1;
        int calculatedMaxLevel = 0;
        final Map<String, int> levels = {};

        if (_layoutMode == MapLayoutMode.tree) {
          final List<String> queue = [];
          final Set<String> visited = {};

          if (uniqueRoutes.isNotEmpty) {
            final root = uniqueRoutes.first;
            levels[root] = 0;
            queue.add(root);
            visited.add(root);
          }

          while (queue.isNotEmpty) {
            final parent = queue.removeAt(0);
            final parentLevel = levels[parent] ?? 0;

            for (final t in transitions) {
              if (t.from == parent) {
                final child = t.to;
                if (!visited.contains(child)) {
                  levels[child] = parentLevel + 1;
                  queue.add(child);
                  visited.add(child);
                }
              }
            }
          }

          int maxLvl = 0;
          for (final lvl in levels.values) {
            if (lvl > maxLvl) maxLvl = lvl;
          }
          for (final route in uniqueRoutes) {
            if (!levels.containsKey(route)) {
              levels[route] = maxLvl + 1;
            }
          }

          for (final lvl in levels.values) {
            if (lvl > calculatedMaxLevel) calculatedMaxLevel = lvl;
          }

          final Map<int, int> layerCounts = {};
          for (final route in uniqueRoutes) {
            final lvl = levels[route] ?? 0;
            layerCounts[lvl] = (layerCounts[lvl] ?? 0) + 1;
          }

          for (final count in layerCounts.values) {
            if (count > maxLayerSize) maxLayerSize = count;
          }
        }

        final double dynamicWidthFactor = maxLayerSize * 260.0 + 400.0;
        final canvasWidth = math.max(3200.0,
            math.max(viewportSize.width * 2.0, dynamicWidthFactor + 1600.0));
        double canvasHeight = 2400.0;
        final double centerX = canvasWidth / 2;

        if (_layoutMode == MapLayoutMode.grid) {
          final int columns = 2;
          final double spacingX = 320.0;
          final double gridTotalWidth = (columns - 1) * spacingX;
          final double gridStartX = centerX - gridTotalWidth / 2;

          final int rows = (uniqueRoutes.length + columns - 1) ~/ columns;
          final double actualHeight = math.max(1, rows) * spacingY;
          canvasHeight = math.max(2400.0, actualHeight + 600.0);
          startY = (canvasHeight - actualHeight) / 2;

          for (int i = 0; i < uniqueRoutes.length; i++) {
            final route = uniqueRoutes[i];
            if (!_draggedRoutes.contains(route)) {
              final row = i ~/ columns;
              final col = i % columns;
              final x = gridStartX + col * spacingX;
              final y = startY + row * spacingY;
              _activePositions[route] = Offset(x, y);
            }
          }
        } else if (_layoutMode == MapLayoutMode.tree) {
          final double actualHeight = (calculatedMaxLevel + 1) * spacingY;
          canvasHeight = math.max(2400.0, actualHeight + 600.0);
          startY = (canvasHeight - actualHeight) / 2;

          final Map<String, List<String>> childrenMap = {};
          final Set<String> allChildren = {};
          final Set<String> visited = {};

          for (final t in transitions) {
            if (!t.isBack) {
              if (!visited.contains(t.to) && t.from != t.to) {
                childrenMap.putIfAbsent(t.from, () => []).add(t.to);
                allChildren.add(t.to);
                visited.add(t.to);
              }
            }
          }

          final Map<String, double> subtreeWidths = {};
          final Set<String> measureVisited = {};
          double measure(String node) {
            if (measureVisited.contains(node)) {
              return cardWidth; // Cycle or DAG prevention
            }
            measureVisited.add(node);

            final children = childrenMap[node] ?? [];
            if (children.isEmpty) {
              subtreeWidths[node] = cardWidth;
              return cardWidth;
            }
            double totalWidth = 0.0;
            for (final child in children) {
              totalWidth += measure(child);
            }
            totalWidth += (children.length - 1) * 120.0; // sibling spacing
            subtreeWidths[node] = math.max(cardWidth, totalWidth);
            return subtreeWidths[node]!;
          }

          final List<String> roots = [];
          for (final route in uniqueRoutes) {
            if (!allChildren.contains(route)) {
              roots.add(route);
            }
          }
          if (roots.isEmpty && uniqueRoutes.isNotEmpty) {
            roots.add(uniqueRoutes.first);
          }

          for (final root in roots) {
            measure(root);
          }

          int maxLvl = 0;
          final Set<String> layoutVisited = {};
          void layoutNode(String node, double x, int level) {
            if (layoutVisited.contains(node)) return;
            layoutVisited.add(node);

            if (level > maxLvl) maxLvl = level;
            final double y = startY + level * spacingY;
            if (!_draggedRoutes.contains(node)) {
              _activePositions[node] = Offset(x, y);
            }

            final children = childrenMap[node] ?? [];
            if (children.isEmpty) return;

            double totalChildrenWidth = 0.0;
            for (final child in children) {
              totalChildrenWidth += subtreeWidths[child] ?? cardWidth;
            }
            totalChildrenWidth += (children.length - 1) * 120.0;

            double currentX = x - totalChildrenWidth / 2;
            for (final child in children) {
              final double childWidth = subtreeWidths[child] ?? cardWidth;
              final double childCenterX = currentX + childWidth / 2;
              layoutNode(child, childCenterX, level + 1);
              currentX += childWidth + 120.0;
            }
          }

          double totalRootsWidth = 0.0;
          for (final root in roots) {
            totalRootsWidth += subtreeWidths[root] ?? cardWidth;
          }
          totalRootsWidth += (roots.length - 1) * 200.0;

          double currentRootX = centerX - totalRootsWidth / 2;
          for (final root in roots) {
            final double rootWidth = subtreeWidths[root] ?? cardWidth;
            final double rootCenterX = currentRootX + rootWidth / 2;
            layoutNode(root, rootCenterX, 0);
            currentRootX += rootWidth + 200.0;
          }

          // Fallback for unreachable nodes
          for (int i = 0; i < uniqueRoutes.length; i++) {
            final route = uniqueRoutes[i];
            if (!_activePositions.containsKey(route)) {
              if (!_draggedRoutes.contains(route)) {
                _activePositions[route] = Offset(
                  centerX + (i * 200.0) - (uniqueRoutes.length * 100.0),
                  startY + actualHeight + 200.0,
                );
              }
            }
          }
        } else if (_layoutMode == MapLayoutMode.circular) {
          final double radius = math.max(250.0, uniqueRoutes.length * 45.0);
          final double actualHeight = radius * 2;
          canvasHeight = math.max(2400.0, actualHeight + 600.0);
          startY = (canvasHeight - actualHeight) / 2;
          final double centerY = startY + radius;

          final int N = uniqueRoutes.length;
          final double angleStep = N > 0 ? (2 * math.pi) / N : 0.0;

          for (int i = 0; i < N; i++) {
            final route = uniqueRoutes[i];
            if (!_draggedRoutes.contains(route)) {
              final double angle =
                  i * angleStep - (math.pi / 2); // Start at 12 o'clock
              final double x = centerX + radius * math.cos(angle);
              final double y = centerY + radius * math.sin(angle);
              _activePositions[route] = Offset(x, y);
            }
          }
        } else {
          final double actualHeight =
              math.max(1, uniqueRoutes.length) * spacingY;
          canvasHeight = math.max(2400.0, actualHeight + 600.0);
          startY = (canvasHeight - actualHeight) / 2;

          for (int i = 0; i < uniqueRoutes.length; i++) {
            final route = uniqueRoutes[i];
            if (!_draggedRoutes.contains(route)) {
              final y = startY + i * spacingY;
              _activePositions[route] = Offset(centerX, y);
            }
          }
        }

        _lastViewportWidth = viewportSize.width;
        _lastViewportHeight = viewportSize.height;
        _lastCanvasWidth = canvasWidth;

        if (!_isInitialMatrixSet) {
          if (_activePositions.isNotEmpty && viewportSize.width > 50) {
            _isInitialMatrixSet = true;
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

            const double cardWidth = 180.0;
            const double cardHeight = 65.0;

            final double graphWidth = (maxX - minX) + cardWidth + 80.0;
            final double graphHeight = (maxY - minY) + cardHeight + 80.0;

            final double graphCenterX = (minX + maxX) / 2;
            final double graphCenterY = (minY + maxY) / 2;

            final double scaleX = viewportSize.width / graphWidth;
            final double scaleY = viewportSize.height / graphHeight;

            double fitScale = math.min(scaleX, scaleY);
            if (fitScale.isNaN || fitScale.isInfinite || fitScale <= 0.0) {
              fitScale = 1.0;
            } else {
              fitScale = fitScale.clamp(0.7, 1.0);
            }

            final double tx =
                (viewportSize.width / 2) - (graphCenterX * fitScale);
            final double ty =
                (viewportSize.height / 2) - (graphCenterY * fitScale);

            final targetMatrix = Matrix4.identity()
              ..setEntry(0, 0, fitScale)
              ..setEntry(1, 1, fitScale)
              ..setEntry(0, 3, tx)
              ..setEntry(1, 3, ty);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _animateToMatrix(targetMatrix);
              }
            });
          } else {
            final initialTx = (viewportSize.width - canvasWidth) / 2;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _animateToMatrix(
                    Matrix4.translationValues(initialTx, 0.0, 0.0));
              }
            });
          }
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
                  maxScale: 2.0,
                  boundaryMargin: const EdgeInsets.all(500.0),
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
                          child: CustomPaint(
                            painter: _StateGraphPainter(
                              transitions: transitions,
                              nodePositions: _activePositions,
                              cardWidth: cardWidth,
                              cardHeight: cardHeight,
                              isDark: MonitorColors.isDark,
                            ),
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
                                      _activePositions[route] =
                                          _activePositions[route]! +
                                              details.delta / currentScale;
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
                                  width: cardWidth,
                                  height: cardHeight,
                                  onTap: () {
                                    final apis = routeApis[route] ?? [];
                                    final errors = routeErrors[route] ?? [];
                                    if (apis.isEmpty && errors.isEmpty) return;
                                    _showScreenApisBottomSheet(
                                      route,
                                      apis,
                                      errors,
                                    );
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
                      // 2. Recenter camera
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
                        onPressed: _resetZoom,
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

    return SizedBox(
      width: width,
      height: height,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isCurrent
                ? borderThemeColor
                : (hasIssues || hasWarning
                    ? borderThemeColor.withValues(alpha: 0.7)
                    : MonitorColors.border),
            width: isCurrent ? 2.0 : 1.0,
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

  _StateGraphPainter({
    required this.transitions,
    required this.nodePositions,
    required this.cardWidth,
    required this.cardHeight,
    required this.isDark,
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

    for (final t in transitions) {
      final fromPos = nodePositions[t.from];
      final toPos = nodePositions[t.to];
      if (fromPos == null || toPos == null) continue;

      final double dx = toPos.dx - fromPos.dx;
      final double dy = toPos.dy - fromPos.dy;
      final double dist = math.sqrt(dx * dx + dy * dy);
      if (dist < 1.0) continue;

      final double ux = dx / dist;
      final double uy = dy / dist;

      final double edgeOffsetFrom = _getEdgeOffset(ux, uy);
      final double edgeOffsetTo = _getEdgeOffset(-ux, -uy);

      final startPoint =
          fromPos + Offset(ux * edgeOffsetFrom, uy * edgeOffsetFrom);
      final endPoint = toPos - Offset(ux * edgeOffsetTo, uy * edgeOffsetTo);

      final isBidirectional = bidirectionalKeys.contains(t.key);
      final double baseOffset =
          t.isBack ? 65.0 : (isBidirectional ? 45.0 : 30.0);
      double curveOffset = baseOffset + (dist * 0.12);

      // Determine bend direction: always bend outwards from the center line of the canvas
      final double centerX = size.width / 2;
      final double midX = (startPoint.dx + endPoint.dx) / 2;
      if (midX < centerX) {
        curveOffset = -curveOffset;
      }

      final double px = -uy;
      final double py = ux;

      final controlPoint = Offset(
        (startPoint.dx + endPoint.dx) / 2 + px * curveOffset,
        (startPoint.dy + endPoint.dy) / 2 + py * curveOffset,
      );

      final path = Path()
        ..moveTo(startPoint.dx, startPoint.dy)
        ..quadraticBezierTo(
            controlPoint.dx, controlPoint.dy, endPoint.dx, endPoint.dy);

      final color = t.isBack
          ? const Color(0xFFF59E0B).withValues(alpha: 0.85)
          : const Color(0xFF6366F1).withValues(alpha: 0.85);
      linePaint.color = color;
      arrowPaint.color = color;

      canvas.drawPath(path, linePaint);

      final pathMetrics = path.computeMetrics();
      for (final metric in pathMetrics) {
        final tangent = metric.getTangentForOffset(metric.length - 8);
        if (tangent != null) {
          final angle = -tangent.angle;
          final arrowPath = Path()
            ..moveTo(endPoint.dx, endPoint.dy)
            ..lineTo(endPoint.dx - 8 * math.cos(angle - 0.5),
                endPoint.dy - 8 * math.sin(angle - 0.5))
            ..lineTo(endPoint.dx - 8 * math.cos(angle + 0.5),
                endPoint.dy - 8 * math.sin(angle + 0.5))
            ..close();
          canvas.drawPath(arrowPath, arrowPaint);
        }
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
