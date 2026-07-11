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
          showScreenBadge: selectedScreen == 'ALL',
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
    final getCount = allLogs.where((l) => l.method == 'GET').length;
    final postCount = allLogs.where((l) => l.method == 'POST').length;

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
                    label: 'ALL',
                    count: allLogs.length,
                    active: activeFilter == 'ALL',
                    color: MonitorColors.metricTotal,
                    onTap: () => onChanged('ALL'),
                  ),
                  if (slowCount > 0) ...[
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'SLOW',
                      count: slowCount,
                      active: activeFilter == 'SLOW',
                      color: MonitorColors.statusSlow,
                      onTap: () => onChanged('SLOW'),
                    ),
                  ],
                  if (errCount > 0) ...[
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'ERR',
                      count: errCount,
                      active: activeFilter == 'ERR',
                      color: MonitorColors.statusError,
                      onTap: () => onChanged('ERR'),
                    ),
                  ],
                  if (getCount > 0) ...[
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'GET',
                      count: getCount,
                      active: activeFilter == 'GET',
                      color: MonitorColors.methodGet,
                      onTap: () => onChanged('GET'),
                    ),
                  ],
                  if (postCount > 0) ...[
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'POST',
                      count: postCount,
                      active: activeFilter == 'POST',
                      color: MonitorColors.methodPost,
                      onTap: () => onChanged('POST'),
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

  const _SearchBar({required this.query, required this.onChanged});

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
      color: MonitorColors.pageBackground,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: MonitorColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: MonitorColors.border.withValues(alpha: 0.8),
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
                  hintText: 'Search by URL, Method, or Status...',
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

  for (final ev in events) {
    final beforeLanes = screenLanes.values.toSet();

    if (ev.isApi) {
      final api = ev.item as ApiLogItem;
      String screenKey = api.screen;
      if (!screenLanes.containsKey(screenKey)) {
        screenKey = stack.isNotEmpty ? stack.last : api.screen;
      }
      final l = getOrCreateLane(screenKey);
      final key = '${api.method}_${api.url}';

      if (currentVisitApis.containsKey(key)) {
        final nodeIndex = currentVisitApis[key]!;
        final existingNode = nodes[nodeIndex];
        final existingApi = existingNode.item as ApiLogItem;

        final isLatest = api.timestamp.isAfter(existingApi.timestamp);
        final mergedApi = existingApi.copyWith(
          callCount: existingApi.callCount + api.callCount,
          duration: isLatest ? api.duration : existingApi.duration,
          statusCode: isLatest ? api.statusCode : existingApi.statusCode,
          timestamp: isLatest ? api.timestamp : existingApi.timestamp,
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
      }
    }
  }

  return nodes;
}

class _FlowLogList extends StatefulWidget {
  const _FlowLogList();

  @override
  State<_FlowLogList> createState() => _FlowLogListState();
}

class _FlowLogListState extends State<_FlowLogList> {
  bool _oldestFirst = false;

  List<_GitNode> _buildItems() {
    final globalLogs = MonitorController.instance.globalApiLogs;
    final List<RouteLogItem> routeLogsCopy = List.from(MonitorController.instance.routeLogs);
    
    final topRoute = MonitorNavigatorObserver.pageStack.isNotEmpty
        ? MonitorNavigatorObserver.pageStack.last
        : '/unknown';
        
    final newestRouteLog = routeLogsCopy.isNotEmpty ? routeLogsCopy.first : null;
    final needVirtualCurrent = topRoute != '/unknown' &&
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
    if (_oldestFirst) {
      return allCombinedNodes;
    }

    // Newest First: Group by screen visits and reverse the groups
    final List<List<_GitNode>> groups = [];
    List<_GitNode>? currentGroup;

    for (final node in allCombinedNodes) {
      if (node.item is RouteLogItem) {
        currentGroup = [node];
        groups.add(currentGroup);
      } else {
        if (currentGroup == null) {
          currentGroup = [];
          groups.add(currentGroup);
        }
        currentGroup.add(node);
      }
    }

    final List<_GitNode> result = [];
    for (final group in groups.reversed) {
      if (group.isEmpty) continue;
      final hasHeader = group[0].item is RouteLogItem;
      if (hasHeader) {
        result.add(group[0]); // Header stays at the top of the group!
        result.addAll(group.sublist(1).reversed); // APIs are reversed underneath
      } else {
        result.addAll(group.reversed);
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    if (items.isEmpty) return const _EmptyState();

    final maxLane = items.fold(0, (m, n) => math.max(m, n.maxLane));
    final graphW = (maxLane + 1) * _GitLanePainter.laneW + 10.0;
    final totalSteps = items.length;

    final topRoute = MonitorNavigatorObserver.pageStack.isNotEmpty
        ? MonitorNavigatorObserver.pageStack.last
        : '/unknown';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: MonitorColors.pageBackground,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.alt_route_rounded, size: 13, color: const Color(0xFF57D888)),
                  const SizedBox(width: 6),
                  BodyText(
                    'FLOW TRACE (ALL)',
                    10.5,
                    color: MonitorColors.primaryText,
                    weight: FontWeight.bold,
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _oldestFirst = !_oldestFirst),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: MonitorColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: MonitorColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _oldestFirst ? Icons.south_rounded : Icons.north_rounded,
                        size: 11,
                        color: MonitorColors.primaryText,
                      ),
                      const SizedBox(width: 4),
                      LabelText(
                        _oldestFirst ? 'CŨ NHẤT TRƯỚC' : 'MỚI NHẤT TRƯỚC',
                        MonitorColors.primaryText,
                        size: 8.5,
                        spacing: 0.3,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final node = items[i];
              final stepNum = _oldestFirst ? i + 1 : totalSteps - i;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: graphW,
                      child: CustomPaint(painter: _GitLanePainter(node)),
                    ),
                    Expanded(
                      child: node.item is RouteLogItem
                          ? _GitRouteInfo(
                              node: node,
                              isCurrent: (node.item as RouteLogItem).route == topRoute &&
                                  (node.item as RouteLogItem).event != RouteLogItem.eventPop,
                              stepNum: stepNum,
                            )
                          : Padding(
                              padding: const EdgeInsets.only(left: 14, top: 4, bottom: 4),
                              child: ApiLogTile(
                                log: node.item as ApiLogItem,
                                showOrder: false,
                                showScreenBadge: false,
                                lane: node.lane,
                                compact: true,
                              ),
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
