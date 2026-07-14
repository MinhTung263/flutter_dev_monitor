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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: typeColor.withValues(alpha: 0.30), width: 0.5),
                          ),
                          child: LabelText(e.type, typeColor, size: 7, spacing: 0.3),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: MonoText(
                            e.message,
                            10.5,
                            color: MonitorColors.statusError,
                            weight: FontWeight.w500,
                            maxLines: _expanded ? null : 1,
                            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        MonoText(timeStr, 8.5),
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
                          child: Icon(Icons.copy_rounded, color: MonitorColors.secondaryText, size: 12),
                        ),
                        const SizedBox(width: 6),
                        Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: MonitorColors.secondaryText, size: 14),
                      ],
                    ),
                    if (!_expanded) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: MonoText(
                          e.message,
                          9.5,
                          color: MonitorColors.secondaryText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_expanded && e.stackTrace.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4, left: 4),
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

class _ErrorFlowLogList extends StatefulWidget {
  const _ErrorFlowLogList();

  @override
  State<_ErrorFlowLogList> createState() => _ErrorFlowLogListState();
}

class _ErrorFlowLogListState extends State<_ErrorFlowLogList> {
  bool _oldestFirst = false;

  List<_FlowTreeNode> _buildItems() {
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
    
    final List<_GitNode> sortedNodes;
    if (_oldestFirst) {
      sortedNodes = allCombinedNodes;
    } else {
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
          result.addAll(group.sublist(1).reversed); // Errors are reversed underneath
        } else {
          result.addAll(group.reversed);
        }
      }
      sortedNodes = result;
    }

    final n = sortedNodes.length;
    final List<int> depths = sortedNodes.map((node) {
      if (node.item is RouteLogItem) {
        final route = node.item as RouteLogItem;
        if (route.event == RouteLogItem.eventPop) {
          return node.activeStack.length;
        }
        final d = node.activeStack.length - 1;
        return d < 0 ? 0 : d;
      } else {
        return node.activeStack.length;
      }
    }).toList();

    final List<_FlowTreeNode> treeNodes = [];
    for (int i = 0; i < n; i++) {
      final depth = depths[i];
      
      final List<bool> showVerticalLines = List.filled(depth, false);
      for (int col = 0; col < depth; col++) {
        for (int j = i + 1; j < n; j++) {
          if (depths[j] < col) {
            break;
          }
          if (depths[j] == col) {
            showVerticalLines[col] = true;
            break;
          }
        }
      }

      bool isLastSibling = true;
      for (int j = i + 1; j < n; j++) {
        if (depths[j] < depth) {
          break;
        }
        if (depths[j] == depth) {
          isLastSibling = false;
          break;
        }
      }

      treeNodes.add(_FlowTreeNode(
        originalNode: sortedNodes[i],
        depth: depth,
        showVerticalLines: showVerticalLines,
        isLastSibling: isLastSibling,
      ));
    }

    return treeNodes;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    if (items.isEmpty) return const _EmptyErrorState();

    final totalSteps = items.length;

    final topRoute = MonitorNavigatorObserver.pageStack.isNotEmpty
        ? MonitorNavigatorObserver.pageStack.last
        : MonitorConstants.unknownRoute;

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

              final treeWidth = node.depth * _FlowTreePainter.indentW;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (treeWidth > 0)
                      SizedBox(
                        width: treeWidth,
                        child: CustomPaint(
                          painter: _FlowTreePainter(
                            depth: node.depth,
                            showVerticalLines: node.showVerticalLines,
                            isLastSibling: node.isLastSibling,
                            isDark: MonitorColors.isDark,
                          ),
                        ),
                      ),
                    Expanded(
                      child: node.item is RouteLogItem
                          ? _GitRouteInfo(
                              node: node.originalNode,
                              isCurrent: (node.item as RouteLogItem).route == topRoute &&
                                  (node.item as RouteLogItem).event != RouteLogItem.eventPop,
                              stepNum: stepNum,
                              compact: true,
                              isErrorTrace: true,
                            )
                          : Padding(
                              padding: const EdgeInsets.only(left: 14, top: 4, bottom: 4),
                              child: _ErrorLogTile(
                                error: node.item as ErrorLogItem,
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
