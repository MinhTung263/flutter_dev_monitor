part of 'monitor_dashboard_page.dart';

// ─── Error list ───────────────────────────────────────────────────────────────

class _EmptyErrorState extends StatelessWidget {
  const _EmptyErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: MonitorColors.border.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bug_report_outlined,
                size: 26, color: MonitorColors.secondaryText),
          ),
          SizedBox(height: 12),
          BodyText(LocaleKeys.noErrors.tr, 13,
              color: MonitorColors.secondaryText,
              weight: FontWeight.w500),
          SizedBox(height: 4),
          BodyText(LocaleKeys.caughtYet.tr, 11, color: MonitorColors.border),
        ],
      ),
    );
  }
}

class _ErrorList extends StatefulWidget {
  final List<ErrorLogItem> errors;
  final String selectedScreen;
  const _ErrorList({required this.errors, required this.selectedScreen});

  @override
  State<_ErrorList> createState() => _ErrorListState();
}

class _ErrorListState extends State<_ErrorList> {
  final Set<String> _collapsedScreens = {};

  @override
  Widget build(BuildContext context) {
    final List<List<ErrorLogItem>> visits = [];
    List<ErrorLogItem>? currentVisit;

    final globalErrors = MonitorController.instance.errorLogs;
    final List<ErrorLogItem> chronoErrors = globalErrors.reversed.toList();
    for (final err in chronoErrors) {
      if (currentVisit == null || currentVisit.last.screen != err.screen) {
        currentVisit = [err];
        visits.add(currentVisit);
      } else {
        currentVisit.add(err);
      }
    }

    final items = <Object>[];
    final totalVisits = visits.length;
    final List<int> visitOrder = List.generate(totalVisits, (i) => i);
    visitOrder.sort((a, b) => b.compareTo(a));

    for (final i in visitOrder) {
      final visitRawErrors = visits[i];
      final screen = visitRawErrors[0].screen;
      final stepNum = i + 1;

      final List<ErrorLogItem> visitErrors = visitRawErrors.where((err) => widget.errors.contains(err)).toList();
      if (visitErrors.isEmpty) continue;

      final isReturn = visits.sublist(0, i).any((v) => v[0].screen == screen);
      final List<ErrorLogItem> displayErrors = visitErrors.reversed.toList();

      final collapsedKey = 'visit_$i';
      final isCollapsed = _collapsedScreens.contains(collapsedKey);

      items.add(_VisitHeaderData(
        visitIndex: i,
        screenRoute: screen,
        isCollapsed: isCollapsed,
        totalApis: visitErrors.length,
        isReturn: isReturn,
        stepNumber: stepNum,
        isCurrent: (i == totalVisits - 1),
      ));

      if (isCollapsed) continue;
      items.addAll(displayErrors);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is _VisitHeaderData) {
          final collapsedKey = 'visit_${item.visitIndex}';
          return _VisitHeader(
            screenRoute: item.screenRoute,
            isCollapsed: item.isCollapsed,
            totalApis: item.totalApis,
            isReturn: item.isReturn,
            stepNumber: item.stepNumber,
            isCurrent: item.isCurrent,
            onToggle: () {
              setState(() {
                if (_collapsedScreens.contains(collapsedKey)) {
                  _collapsedScreens.remove(collapsedKey);
                } else {
                  _collapsedScreens.add(collapsedKey);
                }
              });
            },
          );
        }
        return _ErrorLogTile(error: item as ErrorLogItem);
      },
    );
  }
}

class _ErrorLogTile extends StatefulWidget {
  final ErrorLogItem error;
  final bool compact;
  const _ErrorLogTile({required this.error, this.compact = false});

  @override
  State<_ErrorLogTile> createState() => _ErrorLogTileState();
}

class _ErrorLogTileState extends State<_ErrorLogTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.error;
    final ts = e.timestamp;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
    final isFlutter = e.type == ErrorLogItem.typeFlutter;
    final typeColor =
        isFlutter ? MonitorColors.statusSlow : MonitorColors.statusError;

    if (widget.compact) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 2.5),
        decoration: BoxDecoration(
          color: MonitorColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: MonitorColors.statusError.withValues(alpha: 0.35),
            width: 0.6,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Type badge + Spacer + Timestamp + Copy button + Expand icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: typeColor.withValues(alpha: 0.30), width: 0.5),
                      ),
                      child: LabelText(e.type, typeColor, size: 7.5, spacing: 0.3),
                    ),
                    const Spacer(),
                    MonoText(
                      timeStr,
                      8.5,
                      color: MonitorColors.secondaryText.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                          text: 'Error: ${e.message}\n\nStacktrace:\n${e.stackTrace}',
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(LocaleKeys.errorCopied.tr,
                                style: TextStyle(
                                    color: MonitorColors.primaryText,
                                    fontFamily: MonitorTextStyle.monoFontFamily,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            backgroundColor: MonitorColors.surface,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(color: MonitorColors.divider, width: 0.5),
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: MonitorColors.expandedDetailBg,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: MonitorColors.border,
                            width: 0.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.copy_rounded, color: MonitorColors.primaryText, size: 11),
                      ),
                    ),
                    const SizedBox(width: 3),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: MonitorColors.secondaryText, size: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Row 2: Full-width error message
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: MonoText(
                    e.message,
                    10.5,
                    color: MonitorColors.statusError,
                    weight: FontWeight.w500,
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
                ),
                if (_expanded && e.stackTrace.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MonitorColors.expandedDetailBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: MonitorColors.divider, width: 0.5),
                    ),
                    child: SelectionArea(
                      child: MonoText(
                        e.stackTrace.split('\n').take(20).join('\n'),
                        9,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: MonitorColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: MonitorColors.statusError.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                              color: typeColor.withValues(alpha: 0.30),
                              width: 0.5),
                        ),
                        child: LabelText(e.type, typeColor,
                            size: 7, spacing: 0.3),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: MonoText(
                          MonitorController.formatRouteName(e.screen),
                          9,
                          color: MonitorColors.secondaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      MonoText(timeStr, 10),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                            text: 'Error: ${e.message}\n\nStacktrace:\n${e.stackTrace}',
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(LocaleKeys.errorCopied.tr,
                                  style: TextStyle(
                                      color: MonitorColors.primaryText,
                                      fontFamily: MonitorTextStyle.monoFontFamily,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              backgroundColor: MonitorColors.surface,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(color: MonitorColors.divider, width: 0.5),
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Icon(Icons.copy_rounded,
                            color: MonitorColors.secondaryText, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                          color: MonitorColors.secondaryText, size: 16),
                    ],
                  ),
                  SizedBox(height: 8),
                  MonoText(
                    e.message,
                    11,
                    color: MonitorColors.statusError,
                    weight: FontWeight.w500,
                    height: 1.4,
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && e.stackTrace.isNotEmpty) ...[
            Container(height: 1, color: MonitorColors.divider),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MonitorColors.expandedDetailBg,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: SelectionArea(
                child: MonoText(
                  e.stackTrace.split('\n').take(20).join('\n'),
                  9.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VisitHeaderData {
  final int visitIndex;
  final String screenRoute;
  final bool isCollapsed;
  final int totalApis;
  final bool isReturn;
  final int stepNumber;
  final bool isCurrent;
  const _VisitHeaderData({
    required this.visitIndex,
    required this.screenRoute,
    required this.isCollapsed,
    required this.totalApis,
    required this.isReturn,
    required this.stepNumber,
    required this.isCurrent,
  });
}

class _VisitHeader extends StatelessWidget {
  final String screenRoute;
  final bool isCollapsed;
  final int totalApis;
  final bool isReturn;
  final int stepNumber;
  final bool isCurrent;
  final VoidCallback onToggle;

  const _VisitHeader({
    required this.screenRoute,
    required this.isCollapsed,
    required this.totalApis,
    required this.isReturn,
    required this.stepNumber,
    required this.isCurrent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final title = MonitorController.formatRouteName(screenRoute);

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(top: 14, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent
              ? MonitorColors.metricTotal.withValues(alpha: 0.08)
              : MonitorColors.divider.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isCurrent
                ? MonitorColors.metricTotal.withValues(alpha: 0.40)
                : MonitorColors.border.withValues(alpha: 0.5),
            width: isCurrent ? 0.9 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCollapsed
                  ? Icons.keyboard_arrow_right_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isCurrent
                  ? MonitorColors.metricTotal
                  : MonitorColors.secondaryText,
            ),
            const SizedBox(width: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: MonitorColors.border.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
              child: MonoText(
                LocaleKeys.step.trWith({'number': stepNumber}),
                8,
                color: MonitorColors.secondaryText,
                weight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.layers_outlined,
                size: 12, color: MonitorColors.secondaryText),
            const SizedBox(width: 6),
            BodyText(
              title,
              11,
              color: MonitorColors.primaryText,
              weight: FontWeight.w600,
            ),
            if (isReturn) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: MonitorColors.statusSlow.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: MonitorColors.statusSlow.withValues(alpha: 0.35),
                    width: 0.5,
                  ),
                ),
                child: LabelText(
                  LocaleKeys.goBack.tr,
                  MonitorColors.statusSlow,
                  size: 7,
                  spacing: 0.3,
                ),
              ),
            ],
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: (isCurrent
                        ? MonitorColors.metricTotal
                        : MonitorColors.divider)
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: LabelText(
                LocaleKeys.errorsCount.trWith({'count': totalApis}),
                isCurrent
                    ? MonitorColors.metricTotal
                    : MonitorColors.secondaryText,
                size: 7,
                spacing: 0.3,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 0.5,
                color: (isCurrent
                        ? MonitorColors.metricTotal
                        : MonitorColors.border)
                    .withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 6),
            MonoText(
              screenRoute,
              9,
              color: isCurrent
                  ? MonitorColors.metricTotal.withValues(alpha: 0.7)
                  : MonitorColors.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}

List<_GitNode> _buildErrorCombinedGitNodes(List<ErrorLogItem> errorLogs, List<RouteLogItem> routeLogs) {
  final List<_Event> events = [];
  for (final err in errorLogs) {
    events.add(_Event(timestamp: err.timestamp, isApi: true, item: err));
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
  int? lastRouteNodeIndex;

  for (final ev in events) {
    final beforeLanes = screenLanes.values.toSet();

    if (ev.isApi) {
      final err = ev.item as ErrorLogItem;
      String screenKey = err.screen;
      if (!screenLanes.containsKey(screenKey)) {
        screenKey = stack.isNotEmpty ? stack.last : err.screen;
      }
      final l = getOrCreateLane(screenKey);
      nodes.add(_GitNode(
        item: err,
        lane: l,
        topLanes: screenLanes.values.toSet(),
        bottomLanes: screenLanes.values.toSet(),
        activeStack: List.from(stack),
      ));

      if (lastRouteNodeIndex != null) {
        final rNode = nodes[lastRouteNodeIndex];
        rNode.apiCount += 1;
      }
    } else {
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

class _ErrorScreenGroup {
  final _GitNode routeNode;
  final List<_GitNode> items;
  final int stepNum;
  final bool isCurrent;

  _ErrorScreenGroup({
    required this.routeNode,
    required this.items,
    required this.stepNum,
    required this.isCurrent,
  });

  RouteLogItem get routeItem => routeNode.item as RouteLogItem;
}

class _ErrorFlowLogList extends StatefulWidget {
  const _ErrorFlowLogList();

  @override
  State<_ErrorFlowLogList> createState() => _ErrorFlowLogListState();
}

class _ErrorFlowLogListState extends State<_ErrorFlowLogList> {
  bool _oldestFirst = false;
  bool _expandAll = true;

  List<_ErrorScreenGroup> _buildGroups() {
    final errorLogs = MonitorController.instance.errorLogs;
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

    final allCombinedNodes = _buildErrorCombinedGitNodes(errorLogs, routeLogsCopy);
    
    final List<_ErrorScreenGroup> groups = [];
    _GitNode? currentRouteNode;
    List<_GitNode> currentItems = [];

    for (final node in allCombinedNodes) {
      if (node.item is RouteLogItem) {
        if (currentRouteNode != null) {
          groups.add(_ErrorScreenGroup(
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
      groups.add(_ErrorScreenGroup(
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
        timestamp: (currentItems.first.item as ErrorLogItem).timestamp,
      );
      groups.add(_ErrorScreenGroup(
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

    final List<_ErrorScreenGroup> result = [];
    for (int i = 0; i < total; i++) {
      final g = orderedGroups[i];
      final step = _oldestFirst ? i + 1 : total - i;
      final r = g.routeItem;
      final isCurrent = r.route == topRoute && r.event != RouteLogItem.eventPop;
      
      result.add(_ErrorScreenGroup(
        routeNode: g.routeNode,
        items: _oldestFirst ? g.items : g.items.reversed.toList(),
        stepNum: step,
        isCurrent: isCurrent,
      ));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups();
    if (groups.isEmpty) return const _EmptyErrorState();

    final maxLane = groups.fold(0, (m, g) => math.max(m, g.routeNode.maxLane));
    final graphW = (maxLane + 1) * _GitLanePainter.laneW + 4.0;

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
                    'FLOW TRACE & ERRORS',
                    10.5,
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
                        color: MonitorColors.surface,
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
                  // Sort button
                  GestureDetector(
                    onTap: () => setState(() => _oldestFirst = !_oldestFirst),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: MonitorColors.surface,
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
        Expanded(
          child: ListView.builder(
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
                      child: _ErrorFlowGroupCard(
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
class _ErrorTreeBranchPainter extends CustomPainter {
  final Color color;
  final bool isLast;

  const _ErrorTreeBranchPainter({
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
    final midY = 14.0;

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

    final dotPaint = Paint()..color = color.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(size.width - 1, midY), 1.3, dotPaint);
  }

  @override
  bool shouldRepaint(_ErrorTreeBranchPainter old) =>
      old.color != color || old.isLast != isLast;
}

/// Card container for a Screen Visit and its errors.
class _ErrorFlowGroupCard extends StatefulWidget {
  final _ErrorScreenGroup group;
  final bool initiallyExpanded;

  const _ErrorFlowGroupCard({
    required this.group,
    this.initiallyExpanded = true,
  });

  @override
  State<_ErrorFlowGroupCard> createState() => _ErrorFlowGroupCardState();
}

class _ErrorFlowGroupCardState extends State<_ErrorFlowGroupCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(_ErrorFlowGroupCard oldWidget) {
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
          color: hasChildren
              ? MonitorColors.statusError.withValues(alpha: 0.4)
              : isCurrent
                  ? statusColor.withValues(alpha: 0.5)
                  : MonitorColors.border.withValues(alpha: 0.5),
          width: isCurrent || hasChildren ? 1.0 : 0.6,
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
                  // Right side: Error stats badge + Expand chevron
                  if (hasChildren) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                      decoration: BoxDecoration(
                        color: MonitorColors.statusError.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: MonitorColors.statusError.withValues(alpha: 0.35),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bug_report_outlined,
                            size: 9,
                            color: MonitorColors.statusError,
                          ),
                          const SizedBox(width: 3),
                          MonoText(
                            '${group.items.length}',
                            8.5,
                            color: MonitorColors.statusError,
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
          // ── Child Errors List ────────────────────────────────────
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
                            painter: _ErrorTreeBranchPainter(
                              color: MonitorColors.statusError,
                              isLast: isLast,
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        // Error Tile
                        Expanded(
                          child: _ErrorLogTile(
                            error: node.item as ErrorLogItem,
                            compact: true,
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
