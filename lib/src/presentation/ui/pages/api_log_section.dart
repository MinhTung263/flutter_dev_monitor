part of 'monitor_dashboard_page.dart';

// ─── Grouped log list ─────────────────────────────────────────────────────────

class _GroupedLogList extends StatelessWidget {
  final List<ApiLogItem> logs;
  final bool showHeaders;
  final String selectedScreen;
  final bool oldestFirst;
  final String query;

  const _GroupedLogList({
    required this.logs,
    required this.showHeaders,
    required this.selectedScreen,
    required this.oldestFirst,
    required this.query,
  });

  List<ApiLogItem> _buildItems() {
    return oldestFirst ? logs.reversed.toList() : logs;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return ApiLogTile(
          log: item,
          showOrder: false,
          showScreenBadge: selectedScreen == MonitorConstants.allScreensKey,
        );
      },
    );
  }
}

// ─── Filter bar ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final List<ApiLogItem> allLogs;
  final String activeFilter;
  final ValueChanged<String> onChanged;
  final bool showHeaders;
  final ValueChanged<bool> onHeaderToggle;
  final bool oldestFirst;
  final VoidCallback onSortToggle;
  final bool showHeaderToggle;

  const _FilterBar({
    required this.allLogs,
    required this.activeFilter,
    required this.onChanged,
    required this.showHeaders,
    required this.onHeaderToggle,
    required this.oldestFirst,
    required this.onSortToggle,
    this.showHeaderToggle = true,
  });

  @override
  Widget build(BuildContext context) {
    final slowCount = allLogs.where((l) => l.isSlow).length;
    final errCount = allLogs.where((l) => !l.isSuccess).length;
    final getCount = allLogs.where((l) => l.method == MonitorFilterKeys.get).length;
    final postCount = allLogs.where((l) => l.method == MonitorFilterKeys.post).length;

    return Container(
      color: MonitorColors.pageBackground,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: LocaleKeys.filterAll.tr,
                    count: allLogs.length,
                    active: activeFilter == MonitorFilterKeys.all,
                    color: MonitorColors.metricTotal,
                    onTap: () => onChanged(MonitorFilterKeys.all),
                  ),
                  if (slowCount > 0) ...[
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: LocaleKeys.filterSlow.tr,
                      count: slowCount,
                      active: activeFilter == MonitorFilterKeys.slow,
                      color: MonitorColors.statusSlow,
                      onTap: () => onChanged(MonitorFilterKeys.slow),
                    ),
                  ],
                  if (errCount > 0) ...[
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: LocaleKeys.filterError.tr,
                      count: errCount,
                      active: activeFilter == MonitorFilterKeys.error,
                      color: MonitorColors.statusError,
                      onTap: () => onChanged(MonitorFilterKeys.error),
                    ),
                  ],
                  if (getCount > 0) ...[
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: MonitorFilterKeys.get,
                      count: getCount,
                      active: activeFilter == MonitorFilterKeys.get,
                      color: MonitorColors.methodGet,
                      onTap: () => onChanged(MonitorFilterKeys.get),
                    ),
                  ],
                  if (postCount > 0) ...[
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: MonitorFilterKeys.post,
                      count: postCount,
                      active: activeFilter == MonitorFilterKeys.post,
                      color: MonitorColors.methodPost,
                      onTap: () => onChanged(MonitorFilterKeys.post),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSortToggle,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: MonitorColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: MonitorColors.border),
              ),
              child: Icon(
                oldestFirst ? Icons.south_rounded : Icons.north_rounded,
                size: 14,
                color: MonitorColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.12)
              : MonitorColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.45)
                : MonitorColors.border.withValues(alpha: 0.8),
            width: active ? 1.0 : 0.8,
          ),
          boxShadow: [
            if (active)
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LabelText(
              label,
              active ? color : MonitorColors.secondaryText,
              size: 10,
              spacing: 0.3,
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: (active ? color : MonitorColors.secondaryText)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: MonoText(
                '$count',
                9,
                color: active ? color : MonitorColors.secondaryText,
                weight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// ─── Search Bar ──────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final bool transparent;

  const _SearchBar({
    required this.query,
    required this.onChanged,
    this.transparent = false,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query && widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.transparent ? Colors.transparent : MonitorColors.pageBackground,
      padding: widget.transparent
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: widget.transparent ? MonitorColors.dropdownBg : MonitorColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.transparent
                ? MonitorColors.divider
                : MonitorColors.border.withValues(alpha: 0.8),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.search, size: 16, color: MonitorColors.secondaryText),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: widget.onChanged,
                style: TextStyle(
                  color: MonitorColors.primaryText,
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: LocaleKeys.searchPlaceholder.tr,
                  hintStyle: TextStyle(
                    color: MonitorColors.secondaryText,
                    fontSize: 12,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            if (widget.query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _controller.clear();
                  widget.onChanged('');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.clear, size: 16, color: MonitorColors.secondaryText),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Event {
  final DateTime timestamp;
  final bool isApi;
  final Object item;
  _Event({required this.timestamp, required this.isApi, required this.item});
}

List<_GitNode> _buildCombinedGitNodes(List<ApiLogItem> apiLogs, List<RouteLogItem> routeLogs) {
  final List<_Event> events = [];
  for (final api in apiLogs) {
    events.add(_Event(timestamp: api.timestamp, isApi: true, item: api));
  }
  for (final route in routeLogs) {
    events.add(_Event(timestamp: route.timestamp, isApi: false, item: route));
  }
  events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final List<String> stack = [];
  final Map<String, int> screenLanes = {};
  final List<int> freeLanes = [];
  int nextLane = 0;

  int getOrCreateLane(String screen) {
    if (screenLanes.containsKey(screen)) {
      return screenLanes[screen]!;
    }
    int l;
    if (freeLanes.isNotEmpty) {
      freeLanes.sort();
      l = freeLanes.removeAt(0);
    } else {
      l = nextLane++;
    }
    screenLanes[screen] = l;
    return l;
  }

  void freeLaneFor(String screen) {
    final l = screenLanes.remove(screen);
    if (l != null) {
      freeLanes.add(l);
    }
  }

  final List<_GitNode> nodes = [];
  final Map<String, int> currentVisitApis = {};
  int? lastRouteNodeIndex;

  for (final ev in events) {
    final beforeLanes = screenLanes.values.toSet();

    if (ev.isApi) {
      final api = ev.item as ApiLogItem;
      String screenKey = api.screen;
      if (!screenLanes.containsKey(screenKey)) {
        screenKey = stack.isNotEmpty ? stack.last : api.screen;
      }
      final l = getOrCreateLane(screenKey);
      final key = '${api.method}_${api.url}_${api.requestBody ?? ""}_${api.queryParams.toString()}';

      if (currentVisitApis.containsKey(key)) {
        final nodeIndex = currentVisitApis[key]!;
        final existingNode = nodes[nodeIndex];
        final existingApi = existingNode.item as ApiLogItem;

        final isLatest = api.timestamp.isAfter(existingApi.timestamp);
        final mergedApi = isLatest
            ? api.copyWith(
                callCount: existingApi.callCount + api.callCount,
              )
            : existingApi.copyWith(
                callCount: existingApi.callCount + api.callCount,
              );

        nodes[nodeIndex] = _GitNode(
          item: mergedApi,
          lane: existingNode.lane,
          topLanes: existingNode.topLanes,
          bottomLanes: existingNode.bottomLanes,
          activeStack: existingNode.activeStack,
        );
      } else {
        nodes.add(_GitNode(
          item: api,
          lane: l,
          topLanes: screenLanes.values.toSet(),
          bottomLanes: screenLanes.values.toSet(),
          activeStack: List.from(stack),
        ));
        currentVisitApis[key] = nodes.length - 1;
      }

      if (lastRouteNodeIndex != null) {
        final rNode = nodes[lastRouteNodeIndex];
        rNode.apiCount += api.callCount;
        rNode.apiDurationMs += api.duration;
      }
    } else {
      currentVisitApis.clear();
      final route = ev.item as RouteLogItem;
      final bool isPush = route.event == RouteLogItem.eventPush;
      final bool isPop = route.event == RouteLogItem.eventPop;

      if (isPush) {
        final l = getOrCreateLane(route.route);
        stack.add(route.route);
        final afterLanes = screenLanes.values.toSet();

        nodes.add(_GitNode(
          item: route,
          lane: l,
          topLanes: beforeLanes,
          bottomLanes: afterLanes,
          isBranch: true,
          activeStack: List.from(stack),
        ));
        lastRouteNodeIndex = nodes.length - 1;
      } else if (isPop) {
        if (stack.isNotEmpty && stack.last == route.route) {
          stack.removeLast();
        }
        final l = getOrCreateLane(route.route);
        freeLaneFor(route.route);
        final afterLanes = screenLanes.values.toSet();

        nodes.add(_GitNode(
          item: route,
          lane: l,
          topLanes: beforeLanes,
          bottomLanes: afterLanes,
          isMerge: true,
          activeStack: List.from(stack),
        ));
        lastRouteNodeIndex = nodes.length - 1;

        if (stack.isNotEmpty) {
          final parentRouteName = stack.last;
          final parentLane = getOrCreateLane(parentRouteName);
          final parentLanes = screenLanes.values.toSet();
          nodes.add(_GitNode(
            item: RouteLogItem(
              id: -route.id - 1, // negative id to avoid conflicts
              event: 'RETURN',
              route: parentRouteName,
              timestamp: route.timestamp.add(const Duration(milliseconds: 1)),
            ),
            lane: parentLane,
            topLanes: parentLanes,
            bottomLanes: parentLanes,
            activeStack: List.from(stack),
          ));
          lastRouteNodeIndex = nodes.length - 1;
        }
      } else {
        if (stack.isNotEmpty) {
          final old = stack.removeLast();
          freeLaneFor(old);
        }
        final l = getOrCreateLane(route.route);
        stack.add(route.route);
        final afterLanes = screenLanes.values.toSet();

        nodes.add(_GitNode(
          item: route,
          lane: l,
          topLanes: beforeLanes,
          bottomLanes: afterLanes,
          activeStack: List.from(stack),
        ));
        lastRouteNodeIndex = nodes.length - 1;
      }
    }
  }

  return nodes;
}

enum FlowDisplayMode {
  all,
  routesOnly,
}

class _FlowScreenGroup {
  final _GitNode routeNode;
  final List<_GitNode> items;
  final int stepNum;
  final bool isCurrent;

  _FlowScreenGroup({
    required this.routeNode,
    required this.items,
    required this.stepNum,
    required this.isCurrent,
  });

  RouteLogItem get routeItem => routeNode.item as RouteLogItem;
  int get totalDurationMs => items.fold(0, (sum, n) {
    if (n.item is ApiLogItem) return sum + (n.item as ApiLogItem).duration;
    return sum;
  });
}

class _FlowLogList extends StatefulWidget {
  const _FlowLogList();

  @override
  State<_FlowLogList> createState() => _FlowLogListState();
}

class _FlowLogListState extends State<_FlowLogList> {
  bool _oldestFirst = false;
  bool _expandAll = true;
  FlowDisplayMode _displayMode = FlowDisplayMode.all;

  List<_FlowScreenGroup> _buildGroups() {
    final globalLogs = MonitorController.instance.globalApiLogs;
    final List<RouteLogItem> routeLogsCopy = List.from(MonitorController.instance.routeLogs);
    
    final topRoute = MonitorNavigatorObserver.pageStack.isNotEmpty
        ? MonitorNavigatorObserver.pageStack.last
        : MonitorConstants.unknownRoute;
        
    final newestRouteLog = routeLogsCopy.isNotEmpty ? routeLogsCopy.first : null;
    final needVirtualCurrent = topRoute != MonitorConstants.unknownRoute &&
        (newestRouteLog == null ||
            newestRouteLog.route != topRoute ||
            newestRouteLog.event == RouteLogItem.eventPop);

    if (needVirtualCurrent) {
      final virtualItem = RouteLogItem(
        id: 0,
        event: RouteLogItem.eventReplace,
        route: topRoute,
        timestamp: DateTime.now(),
      );
      routeLogsCopy.insert(0, virtualItem);
    }

    final allCombinedNodes = _buildCombinedGitNodes(globalLogs, routeLogsCopy);
    
    final List<_FlowScreenGroup> groups = [];
    _GitNode? currentRouteNode;
    List<_GitNode> currentItems = [];

    for (final node in allCombinedNodes) {
      if (node.item is RouteLogItem) {
        if (currentRouteNode != null) {
          groups.add(_FlowScreenGroup(
            routeNode: currentRouteNode,
            items: List.from(currentItems),
            stepNum: 0,
            isCurrent: false,
          ));
          currentItems.clear();
        }
        currentRouteNode = node;
      } else {
        currentItems.add(node);
      }
    }

    if (currentRouteNode != null) {
      groups.add(_FlowScreenGroup(
        routeNode: currentRouteNode,
        items: List.from(currentItems),
        stepNum: 0,
        isCurrent: false,
      ));
    } else if (currentItems.isNotEmpty) {
      final virtualRoute = RouteLogItem(
        id: 0,
        event: RouteLogItem.eventPush,
        route: 'App Launch',
        timestamp: (currentItems.first.item as ApiLogItem).timestamp,
      );
      groups.add(_FlowScreenGroup(
        routeNode: _GitNode(
          item: virtualRoute,
          lane: 0,
          topLanes: {0},
          bottomLanes: {0},
          activeStack: ['App Launch'],
        ),
        items: List.from(currentItems),
        stepNum: 0,
        isCurrent: false,
      ));
    }

    final orderedGroups = _oldestFirst ? groups : groups.reversed.toList();
    final total = orderedGroups.length;

    final List<_FlowScreenGroup> result = [];
    for (int i = 0; i < total; i++) {
      final g = orderedGroups[i];
      final step = _oldestFirst ? i + 1 : total - i;
      final r = g.routeItem;
      final isCurrent = r.route == topRoute && r.event != RouteLogItem.eventPop;
      
      result.add(_FlowScreenGroup(
        routeNode: g.routeNode,
        items: _oldestFirst ? g.items : g.items.reversed.toList(),
        stepNum: step,
        isCurrent: isCurrent,
      ));
    }

    return result;
  }

  Widget _buildModeOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final activeColor = const Color(0xFF57D888);
    final color = selected ? activeColor : MonitorColors.secondaryText;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected 
              ? activeColor.withValues(alpha: 0.08)
              : MonitorColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected 
                ? activeColor.withValues(alpha: 0.35)
                : MonitorColors.divider,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4.5),
            LabelText(
              label,
              color,
              size: 8,
              spacing: 0.2,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups();
    final maxLane = groups.fold(0, (m, g) => math.max(m, g.routeNode.maxLane));
    final graphW = (maxLane + 1) * _GitLanePainter.laneW + 4.0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: MonitorColors.surface,
            border: Border(bottom: BorderSide(color: MonitorColors.divider, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF57D888).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(
                      Icons.alt_route_rounded,
                      size: 13,
                      color: const Color(0xFF57D888),
                    ),
                  ),
                  const SizedBox(width: 7),
                  BodyText(
                    'FLOW TRACE & APIS',
                    11.5,
                    color: MonitorColors.primaryText,
                    weight: FontWeight.bold,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Expand/Collapse All
                  GestureDetector(
                    onTap: () => setState(() => _expandAll = !_expandAll),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: MonitorColors.pageBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: MonitorColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _expandAll ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
                            size: 10,
                            color: MonitorColors.secondaryText,
                          ),
                          const SizedBox(width: 3.5),
                          LabelText(
                            _expandAll ? 'THU GỌN' : 'MỞ RỘNG',
                            MonitorColors.secondaryText,
                            size: 7.5,
                            spacing: 0.2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Sort Order
                  GestureDetector(
                    onTap: () => setState(() => _oldestFirst = !_oldestFirst),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: MonitorColors.pageBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: MonitorColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _oldestFirst ? Icons.south_rounded : Icons.north_rounded,
                            size: 10,
                            color: MonitorColors.primaryText,
                          ),
                          const SizedBox(width: 4),
                          LabelText(
                            _oldestFirst ? 'CŨ NHẤT' : 'MỚI NHẤT',
                            MonitorColors.primaryText,
                            size: 7.5,
                            spacing: 0.2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          color: MonitorColors.pageBackground,
          child: Row(
            children: [
              _buildModeOption(
                label: 'ROUTE & API',
                icon: Icons.list_alt_rounded,
                selected: _displayMode == FlowDisplayMode.all,
                onTap: () => setState(() => _displayMode = FlowDisplayMode.all),
              ),
              const SizedBox(width: 8),
              _buildModeOption(
                label: 'CHỈ ROUTE',
                icon: Icons.route_outlined,
                selected: _displayMode == FlowDisplayMode.routesOnly,
                onTap: () => setState(() => _displayMode = FlowDisplayMode.routesOnly),
              ),
            ],
          ),
        ),
        Expanded(
          child: _displayMode == FlowDisplayMode.routesOnly
              ? _RouteTreeView(
                  logs: MonitorController.instance.routeLogs,
                  oldestFirst: _oldestFirst,
                  compact: true,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                  itemCount: groups.length,
                  itemBuilder: (_, i) {
                    final group = groups[i];
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: graphW,
                            child: CustomPaint(
                              painter: _GitLanePainter(group.routeNode),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _FlowGroupCard(
                              group: group,
                              initiallyExpanded: _expandAll,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A tree branch painter (├── or └──) connecting a child item to its parent group.
class _TreeBranchPainter extends CustomPainter {
  final Color color;
  final bool isLast;

  const _TreeBranchPainter({
    required this.color,
    required this.isLast,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startX = size.width / 2;
    final midY = 14.0; // aligns with the header row of compact tile

    if (isLast) {
      // L-shape
      final path = Path()
        ..moveTo(startX, 0)
        ..lineTo(startX, midY - 3)
        ..quadraticBezierTo(startX, midY, startX + 4, midY)
        ..lineTo(size.width, midY);
      canvas.drawPath(path, paint);
    } else {
      // T-shape
      final path = Path()
        ..moveTo(startX, 0)
        ..lineTo(startX, size.height);
      canvas.drawPath(path, paint);

      final branchPath = Path()
        ..moveTo(startX, midY)
        ..lineTo(size.width, midY);
      canvas.drawPath(branchPath, paint);
    }

    // Small dot at the end of the branch connector
    final dotPaint = Paint()..color = color.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(size.width - 1, midY), 1.3, dotPaint);
  }

  @override
  bool shouldRepaint(_TreeBranchPainter old) =>
      old.color != color || old.isLast != isLast;
}

/// Card container for a Screen Visit and all its child API calls.
class _FlowGroupCard extends StatefulWidget {
  final _FlowScreenGroup group;
  final bool initiallyExpanded;

  const _FlowGroupCard({
    required this.group,
    this.initiallyExpanded = true,
  });

  @override
  State<_FlowGroupCard> createState() => _FlowGroupCardState();
}

class _FlowGroupCardState extends State<_FlowGroupCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(_FlowGroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final item = group.routeItem;
    final isCurrent = group.isCurrent;

    final laneColor = _GitLanePainter._palette[group.routeNode.lane % _GitLanePainter._palette.length];
    final hasChildren = group.items.isNotEmpty;

    final bool isReturn = item.event == 'RETURN';
    final bool isEnter = item.event == RouteLogItem.eventPush || isReturn;
    final bool isBack  = item.event == RouteLogItem.eventPop;
    final Color statusColor = isEnter
        ? MonitorColors.statusSuccess
        : isBack
            ? MonitorColors.secondaryText
            : MonitorColors.statusSlow;

    final IconData dirIcon = isReturn
        ? Icons.keyboard_return_rounded
        : isEnter
            ? Icons.arrow_forward_rounded
            : isBack
                ? Icons.arrow_back_rounded
                : Icons.swap_horiz_rounded;

    final durationStr = item.duration != null
        ? RouteLogController.fmtDuration(item.duration!)
        : null;

    final ts = item.timestamp;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.5),
      decoration: BoxDecoration(
        color: isCurrent
            ? statusColor.withValues(alpha: 0.05)
            : MonitorColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent
              ? statusColor.withValues(alpha: 0.5)
              : MonitorColors.border.withValues(alpha: 0.5),
          width: isCurrent ? 1.0 : 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Group Header (Tappable) ──────────────────────────────
          InkWell(
            onTap: hasChildren ? () => setState(() => _expanded = !_expanded) : null,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(7.5),
              bottom: Radius.circular(_expanded && hasChildren ? 0 : 7.5),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _expanded && hasChildren
                    ? MonitorColors.pageBackground.withValues(alpha: 0.35)
                    : Colors.transparent,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(7.5),
                  bottom: Radius.circular(_expanded && hasChildren ? 0 : 7.5),
                ),
              ),
              child: Row(
                children: [
                  // Lane indicator bar
                  Container(
                    width: 3.5,
                    height: 26,
                    decoration: BoxDecoration(
                      color: laneColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Screen info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Step # + Dir Icon + Duration + Current Badge + Timestamp
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: laneColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: MonoText(
                                '#${group.stepNum}',
                                8,
                                color: laneColor,
                                weight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(dirIcon, size: 11, color: statusColor),
                            if (durationStr != null) ...[
                              const SizedBox(width: 5),
                              MonoText(
                                durationStr,
                                8.5,
                                color: statusColor,
                                weight: FontWeight.w600,
                              ),
                            ],
                            if (isCurrent) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: MonitorColors.metricTotal
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: LabelText(
                                  LocaleKeys.current.tr,
                                  MonitorColors.metricTotal,
                                  size: 7,
                                  spacing: 0.3,
                                ),
                              ),
                            ],
                            const Spacer(),
                            MonoText(
                              timeStr,
                              8.5,
                              color: MonitorColors.secondaryText,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        // Row 2: Route Name
                        MonoText(
                          MonitorController.formatRouteName(item.route),
                          11.5,
                          color: isBack
                              ? MonitorColors.secondaryText
                              : MonitorColors.primaryText,
                          weight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Right side: API stats badge + Expand chevron
                  if (hasChildren) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                      decoration: BoxDecoration(
                        color: MonitorColors.overlayApi.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: MonitorColors.overlayApi.withValues(alpha: 0.35),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.api_outlined,
                            size: 9,
                            color: MonitorColors.overlayApi,
                          ),
                          const SizedBox(width: 3),
                          MonoText(
                            '${group.items.length} • ${fmtDuration(group.totalDurationMs)}',
                            8.5,
                            color: MonitorColors.overlayApi,
                            weight: FontWeight.bold,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: MonitorColors.secondaryText,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // ── Child APIs List ──────────────────────────────────────
          if (_expanded && hasChildren) ...[
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: MonitorColors.divider.withValues(alpha: 0.4),
                    width: 0.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(6, 6, 8, 8),
              child: Column(
                children: List.generate(group.items.length, (idx) {
                  final node = group.items[idx];
                  final isLast = idx == group.items.length - 1;

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tree branch line
                        SizedBox(
                          width: 10,
                          child: CustomPaint(
                            painter: _TreeBranchPainter(
                              color: laneColor,
                              isLast: isLast,
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        // API Tile
                        Expanded(
                          child: ApiLogTile(
                            log: node.item as ApiLogItem,
                            showOrder: false,
                            showScreenBadge: false,
                            lane: node.lane,
                            compact: true,
                            showFullUrl: false,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
