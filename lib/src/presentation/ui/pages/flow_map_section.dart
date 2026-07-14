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

  MapLayoutMode _layoutMode = MapLayoutMode.tree;

  Map<String, Offset> get _activePositions {
    switch (_layoutMode) {
      case MapLayoutMode.tree:
        return _treePositions;
      case MapLayoutMode.grid:
        return _gridPositions;
      case MapLayoutMode.stream:
        return _streamPositions;
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
      if (matchedVisit != null) {
        matchedVisit.apiLogs.add(api);
      } else {
        if (visits.isNotEmpty) {
          final sameScreenVisit = visits.lastWhere(
            (v) => v.route == api.screen,
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
      if (matchedVisit != null) {
        matchedVisit.errorLogs.add(err);
      } else {
        if (visits.isNotEmpty) {
          final sameScreenVisit = visits.lastWhere(
            (v) => v.route == err.screen,
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
    final scaleX = _MiniMap.width / canvasWidth;
    final scaleY = _MiniMap.height / canvasHeight;
    final scale = math.min(scaleX, scaleY);

    final offsetX = (_MiniMap.width - canvasWidth * scale) / 2;
    final offsetY = (_MiniMap.height - canvasHeight * scale) / 2;

    final canvasX = (localPos.dx - offsetX) / scale;
    final canvasY = (localPos.dy - offsetY) / scale;

    final clampedX = canvasX.clamp(0.0, canvasWidth);
    final clampedY = canvasY.clamp(0.0, canvasHeight);

    final currentMatrix = _transformationController.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();

    final tx = viewportSize.width / 2 - clampedX * currentScale;
    final ty = viewportSize.height / 2 - clampedY * currentScale;

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
                              text:
                                  'APIs (${filteredApis.length}/${allApis.length})'),
                          Tab(text: 'Errors (${errors.length})'),
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
                                            MonoText(
                                              localSearchQuery.isEmpty
                                                  ? 'No API requests captured on this screen.'
                                                  : 'No matching API requests found.',
                                              11.5,
                                              color:
                                                  MonitorColors.secondaryText,
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
                                      MonoText(
                                        'No Flutter errors captured on this screen.',
                                        11.5,
                                        color: MonitorColors.secondaryText,
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
    final initialTx = (_lastViewportWidth - _lastCanvasWidth) / 2;
    final targetMatrix = Matrix4.translationValues(initialTx, 0.0, 0.0);
    _animateToMatrix(targetMatrix);
    setState(() {
      _activePositions.clear();
      _draggedRoutes.clear();
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

        final double spacingY = 160.0;
        final double startY = 80.0;

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
        final double canvasHeight;
        final double centerX = canvasWidth / 2;

        if (_layoutMode == MapLayoutMode.grid) {
          final int columns = 2;
          final double spacingX = 260.0;
          final double gridTotalWidth = (columns - 1) * spacingX;
          final double gridStartX = centerX - gridTotalWidth / 2;

          canvasHeight = math.max(
            2400.0,
            ((uniqueRoutes.length + 1) ~/ columns) * spacingY + startY + 600.0,
          );

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
          final Map<int, List<String>> layerNodes = {};
          for (final route in uniqueRoutes) {
            final lvl = levels[route] ?? 0;
            layerNodes[lvl] ??= [];
            layerNodes[lvl]!.add(route);
          }

          canvasHeight = math.max(
              2400.0, (calculatedMaxLevel + 1) * spacingY + startY + 600.0);

          final double spacingX = 240.0;
          for (int lvl = 0; lvl <= calculatedMaxLevel; lvl++) {
            final layer = layerNodes[lvl] ?? [];
            final int N = layer.length;
            final double startX = centerX - ((N - 1) * spacingX) / 2;

            for (int col = 0; col < N; col++) {
              final route = layer[col];
              if (!_draggedRoutes.contains(route)) {
                final x = startX + col * spacingX;
                final y = startY + lvl * spacingY;
                _activePositions[route] = Offset(x, y);
              }
            }
          }
        } else {
          canvasHeight =
              math.max(2400.0, uniqueRoutes.length * spacingY + startY + 600.0);

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
          _isInitialMatrixSet = true;
          if (_activePositions.isNotEmpty) {
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

            _transformationController.value = targetMatrix;
          } else {
            final initialTx = (viewportSize.width - canvasWidth) / 2;
            _transformationController.value =
                Matrix4.translationValues(initialTx, 0.0, 0.0);
          }
        }

        final Map<String, List<ApiLogItem>> routeApis = {};
        final Map<String, List<ErrorLogItem>> routeErrors = {};
        final Map<String, int> routeVisits = {};
        final Map<String, Set<int>> seenApiOrders = {};
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
            final seen = seenApiOrders[visit.route]!;
            if (seen.add(api.orderNumber)) {
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
                  child: SizedBox(
                    width: canvasWidth,
                    height: canvasHeight,
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
                                    if (currentScale > 0.05 && currentScale.isFinite) {
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
                          tooltip: 'Back',
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
                                  : Icons.view_stream_rounded,
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
                            } else {
                              _layoutMode = MapLayoutMode.tree;
                            }
                          });
                        },
                        tooltip: _layoutMode == MapLayoutMode.tree
                            ? 'Switch to Grid Layout'
                            : _layoutMode == MapLayoutMode.grid
                                ? 'Switch to Stream Layout'
                                : 'Switch to Tree Layout',
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
                        tooltip: 'Recenter Camera',
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
                            ? 'Hide Background Grid'
                            : 'Show Background Grid',
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
                        tooltip: 'Reset Layout & Zoom',
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
                            ? 'Exit Full Screen'
                            : 'Full Screen Preview',
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
                      '$visitCount visits',
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
                      '$totalApis requests',
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
      final double curveOffset = isBidirectional ? 30.0 : 15.0;

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
    return oldDelegate.isDark != isDark ||
        oldDelegate.transitions.length != transitions.length;
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

  static const double width = 160.0;
  static const double height = 100.0;

  const _MiniMap({
    required this.transformationController,
    required this.nodePositions,
    required this.transitions,
    required this.activeRoute,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.viewportSize,
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
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = width / canvasWidth;
    final scaleY = height / canvasHeight;
    final scale = math.min(scaleX, scaleY);

    final offsetX = (width - canvasWidth * scale) / 2;
    final offsetY = (height - canvasHeight * scale) / 2;

    Offset toMiniMap(Offset point) {
      return Offset(
        point.dx * scale + offsetX,
        point.dy * scale + offsetY,
      );
    }

    // 1. Draw connections
    final linePaint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (final t in transitions) {
      final from = nodePositions[t.from];
      final to = nodePositions[t.to];
      if (from == null || to == null) continue;

      final start = toMiniMap(from);
      final end = toMiniMap(to);

      linePaint.color = t.isBack
          ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
          : const Color(0xFF6366F1).withValues(alpha: 0.4);

      canvas.drawLine(start, end, linePaint);
    }

    // 2. Draw nodes
    final nodePaint = Paint()..style = PaintingStyle.fill;
    const double nodeW = 18.0;
    const double nodeH = 9.0;

    for (final entry in nodePositions.entries) {
      final route = entry.key;
      final pos = entry.value;

      final center = toMiniMap(pos);

      final isCurrent = route == activeRoute;
      nodePaint.color = isCurrent
          ? const Color(0xFF57D888)
          : MonitorColors.divider.withValues(alpha: 0.8);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: math.max(6.0, nodeW * (scale / 0.1)),
            height: math.max(4.0, nodeH * (scale / 0.1)),
          ),
          const Radius.circular(1.5),
        ),
        nodePaint,
      );
    }

    // 3. Draw viewport indicator
    final double rawScale = matrix.getMaxScaleOnAxis();
    final double viewportScale = (rawScale.isNaN || rawScale.isInfinite || rawScale <= 0.01) ? 1.0 : rawScale;
    final double tx = matrix.entry(0, 3);
    final double ty = matrix.entry(1, 3);

    final double viewportCanvasW = viewportSize.width / viewportScale;
    final double viewportCanvasH = viewportSize.height / viewportScale;
    final double topLeftCanvasX = -tx / viewportScale;
    final double topLeftCanvasY = -ty / viewportScale;

    final miniTopLeft = toMiniMap(Offset(topLeftCanvasX, topLeftCanvasY));
    final miniWidth = viewportCanvasW * scale;
    final miniHeight = viewportCanvasH * scale;

    final miniViewportRect =
        Rect.fromLTWH(miniTopLeft.dx, miniTopLeft.dy, miniWidth, miniHeight);

    final viewportPaint = Paint()
      ..color = const Color(0xFF57D888).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final viewportBorderPaint = Paint()
      ..color = const Color(0xFF57D888).withValues(alpha: 0.7)
      ..strokeWidth = 1.0
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
                tooltip: 'Zoom Out',
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
                tooltip: 'Zoom In',
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
