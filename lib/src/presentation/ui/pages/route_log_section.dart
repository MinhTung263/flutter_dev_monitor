part of 'monitor_dashboard_page.dart';

// ─── Route log section ────────────────────────────────────────────────────────

class _EmptyRouteState extends StatelessWidget {
  const _EmptyRouteState();

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
            child: Icon(Icons.route_outlined,
                size: 26, color: MonitorColors.secondaryText),
          ),
          const SizedBox(height: 12),
          BodyText('No route events yet', 13,
              color: MonitorColors.secondaryText, weight: FontWeight.w500),
          const SizedBox(height: 4),
          BodyText('Navigate around the app to see the flow', 11,
              color: MonitorColors.border),
        ],
      ),
    );
  }
}

class _LiveNavigationStackView extends StatelessWidget {
  const _LiveNavigationStackView();

  @override
  Widget build(BuildContext context) {
    final stack = List<String>.from(MonitorNavigatorObserver.pageStack);
    if (stack.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MonitorColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MonitorColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.layers_outlined, size: 12, color: MonitorColors.metricTotal),
              const SizedBox(width: 5),
              BodyText('LIVE NAVIGATION STACK', 9,
                  color: MonitorColors.secondaryText, weight: FontWeight.bold),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(stack.length, (index) {
                final route = stack[index];
                // Resolve tab routes to show correct screen names (e.g. /home, /invoice)
                final resolvedRoute = MonitorNavigatorObserver.currentRoute == route
                    ? MonitorNavigatorObserver.currentRoute
                    : route;
                final title = MonitorController.formatRouteName(resolvedRoute);
                final isLast = index == stack.length - 1;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLast
                            ? MonitorColors.metricTotal.withValues(alpha: 0.12)
                            : MonitorColors.divider.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isLast
                              ? MonitorColors.metricTotal.withValues(alpha: 0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: BodyText(
                        title,
                        11,
                        color: isLast
                            ? MonitorColors.metricTotal
                            : MonitorColors.primaryText,
                        weight: isLast ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: MonitorColors.border,
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Container that owns the List ↔ Tree toggle ──────────────────────────────

class _RouteLogList extends StatefulWidget {
  final List<RouteLogItem> logs;
  const _RouteLogList({required this.logs});

  @override
  State<_RouteLogList> createState() => _RouteLogListState();
}

class _RouteLogListState extends State<_RouteLogList> {
  bool _oldestFirst = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LiveNavigationStackView(),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => setState(() => _oldestFirst = !_oldestFirst),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: MonitorColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MonitorColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _oldestFirst ? Icons.south_rounded : Icons.north_rounded,
                    size: 12,
                    color: MonitorColors.primaryText,
                  ),
                  const SizedBox(width: 4),
                  BodyText(
                    _oldestFirst ? 'Oldest first' : 'Newest first',
                    10,
                    color: MonitorColors.primaryText,
                    weight: FontWeight.w500,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _RouteTreeView(logs: widget.logs, oldestFirst: _oldestFirst),
        ),
      ],
    );
  }
}

// ─── Git-graph tree view ──────────────────────────────────────────────────────

/// Data model for one row in the git-style graph.
class _GitNode {
  final Object item;

  /// 0-indexed lane (column) where this event's dot sits.
  final int lane;

  /// Lanes that have a vertical line going UP (toward newer events = rows above).
  final Set<int> topLanes;

  /// Lanes that have a vertical line going DOWN (toward older events = rows below).
  final Set<int> bottomLanes;

  /// True when this is a PUSH and the new lane branches from its parent.
  final bool isBranch;

  /// True when this is a POP and the lane merges back to its parent.
  final bool isMerge;

  /// The active navigator routes on the stack during this transition.
  final List<String> activeStack;

  /// Number of APIs called during this route session.
  int apiCount = 0;

  /// Total duration (in ms) of APIs called during this route session.
  int apiDurationMs = 0;

  _GitNode({
    required this.item,
    required this.lane,
    required this.topLanes,
    required this.bottomLanes,
    this.isBranch = false,
    this.isMerge = false,
    required this.activeStack,
  });

  RouteLogItem get routeItem => item as RouteLogItem;

  int get maxLane {
    final all = <int>{...topLanes, ...bottomLanes, lane};
    return all.isEmpty ? 0 : all.reduce(math.max);
  }
}

/// Replays [logs] (newest-first) chronologically and computes a [_GitNode]
/// per event that encodes lane positions and connector geometry.
List<_GitNode> _buildGitNodes(List<RouteLogItem> logs) {
  if (logs.isEmpty) return [];

  // logs is newest-first → reverse for chronological replay
  final chrono = logs.reversed.toList();

  // Compute navigator stack state after each chronological event.
  // states[0] = empty (before first event), states[i+1] = after chrono[i].
  final states = <List<String>>[[]];
  for (final item in chrono) {
    final s = List<String>.from(states.last);
    switch (item.event) {
      case RouteLogItem.eventPush:
        s.add(item.route);
        break;
      case RouteLogItem.eventPop:
        if (s.isNotEmpty) s.removeLast();
        break;
      default: // REPLACE
        if (s.isNotEmpty) s.removeLast();
        s.add(item.route);
    }
    states.add(s);
  }

  final nodes = <_GitNode>[];
  for (int di = 0; di < chrono.length; di++) {
    final ci = chrono.length - 1 - di; // chronological index
    final item = chrono[ci];
    final before = states[ci];      // stack before this event
    final after = states[ci + 1];   // stack after this event

    final int lane;
    final bool isBranch;
    final bool isMerge;

    switch (item.event) {
      case RouteLogItem.eventPush:
        lane = before.length; // 0-indexed depth of the newly pushed route
        isBranch = before.isNotEmpty; // branch from parent lane
        isMerge = false;
        break;
      case RouteLogItem.eventPop:
        lane = after.length; // depth of the route that was popped
        isBranch = false;
        isMerge = after.isNotEmpty; // merge to parent lane
        break;
      default: // REPLACE keeps the same depth
        lane = math.max(0, before.length - 1);
        isBranch = false;
        isMerge = false;
    }

    // topLanes: lanes active AFTER the event (connecting to rows above = newer)
    final topLanes = Set<int>.from(List.generate(after.length, (i) => i));
    // bottomLanes: lanes active BEFORE the event (connecting to rows below = older)
    final bottomLanes = Set<int>.from(List.generate(before.length, (i) => i));

    nodes.add(_GitNode(
      item: item,
      lane: lane,
      topLanes: topLanes,
      bottomLanes: bottomLanes,
      isBranch: isBranch,
      isMerge: isMerge,
      activeStack: List<String>.from({...before, ...after}),
    ));
  }
  return nodes;
}

/// CustomPainter that draws a single git-graph row: lane lines, dot, diagonals.
class _GitLanePainter extends CustomPainter {
  final _GitNode node;

  static const double laneW = 14.0;
  static const double dotR = 4.5;
  static const double lineW = 1.8;

  // Same palette as popular git GUIs: blue → green → orange → purple → …
  static const List<Color> _palette = [
    Color(0xFF4D9EFF), // blue   (main branch)
    Color(0xFF57D888), // green
    Color(0xFFE07B39), // orange
    Color(0xFF9B67EE), // purple
    Color(0xFF4DCFDE), // cyan
    Color(0xFFEE6B9E), // pink
  ];

  const _GitLanePainter(this.node);

  Color _c(int lane) => _palette[lane % _palette.length];

  Paint _lp(int lane, {double? width}) => Paint()
    ..color = _c(lane)
    ..strokeWidth = width ?? lineW
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final dotX = node.lane * laneW + laneW / 2;

    // ── 1. Continuous lanes (active both above and below) ─────────────
    for (final l in node.topLanes.intersection(node.bottomLanes)) {
      final x = l * laneW + laneW / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _lp(l));
    }

    // ── 2. Top-only lanes (exist in newer state, end at dot row) ──────
    for (final l in node.topLanes.difference(node.bottomLanes)) {
      if (l == node.lane) continue; // handled with dot below
      final x = l * laneW + laneW / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, midY), _lp(l));
    }

    // ── 3. Bottom-only lanes (exist in older state, start at dot row) ─
    for (final l in node.bottomLanes.difference(node.topLanes)) {
      if (l == node.lane) continue;
      final x = l * laneW + laneW / 2;
      canvas.drawLine(Offset(x, midY), Offset(x, size.height), _lp(l));
    }

    // ── 4. Dot lane's own vertical segments ───────────────────────────
    if (node.topLanes.contains(node.lane)) {
      canvas.drawLine(Offset(dotX, 0), Offset(dotX, midY), _lp(node.lane));
    }
    if (node.bottomLanes.contains(node.lane)) {
      canvas.drawLine(Offset(dotX, midY), Offset(dotX, size.height), _lp(node.lane));
    }

    // ── 5. Branch diagonal (PUSH): parent-lane bottom → new-lane dot ──
    //   Shows that lane N "emerged" from lane N-1 going into the past (down).
    if (node.isBranch && node.lane > 0) {
      final px = (node.lane - 1) * laneW + laneW / 2;
      canvas.drawLine(
        Offset(px, size.height),
        Offset(dotX, midY),
        _lp(node.lane),
      );
    }

    // ── 6. Merge diagonal (POP): this-lane dot → parent-lane top ──────
    //   Shows that lane N "folded back" into lane N-1 going into the future (up).
    if (node.isMerge && node.lane > 0) {
      final px = (node.lane - 1) * laneW + laneW / 2;
      canvas.drawLine(
        Offset(dotX, midY),
        Offset(px, 0),
        _lp(node.lane),
      );
    }

    // ── 7. Dot ────────────────────────────────────────────────────────
    final bg = MonitorColors.pageBackground;
    // Dark ring so dot is legible over lane lines
    canvas.drawCircle(
        Offset(dotX, midY), dotR + 1.5, Paint()..color = bg);
    // Filled dot
    canvas.drawCircle(Offset(dotX, midY), dotR, Paint()..color = _c(node.lane));
    // POP dots are hollow (ring only)
    if (node.item is RouteLogItem && (node.item as RouteLogItem).event == RouteLogItem.eventPop) {
      canvas.drawCircle(
          Offset(dotX, midY), dotR - 2.0, Paint()..color = bg);
    }
  }

  @override
  bool shouldRepaint(_GitLanePainter old) => old.node != node;
}

class _RouteTreeView extends StatelessWidget {
  final List<RouteLogItem> logs;
  final bool oldestFirst;
  final bool compact;
  const _RouteTreeView({
    required this.logs,
    required this.oldestFirst,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final nodes = _buildGitNodes(logs);
    if (nodes.isEmpty) return const _EmptyRouteState();

    final topRoute = MonitorNavigatorObserver.pageStack.isNotEmpty
        ? MonitorNavigatorObserver.pageStack.last
        : '/unknown';

    final List<_GitNode> finalNodes = [];
    final newestNode = nodes.isNotEmpty ? nodes.first : null;
    final needVirtualCurrent = topRoute != '/unknown' &&
        (newestNode == null ||
            newestNode.routeItem.route != topRoute ||
            newestNode.routeItem.event == RouteLogItem.eventPop);

    if (needVirtualCurrent) {
      final virtualItem = RouteLogItem(
        id: 0,
        event: RouteLogItem.eventReplace,
        route: topRoute,
        timestamp: DateTime.now(),
      );
      finalNodes.add(_GitNode(
        item: virtualItem,
        lane: 0,
        topLanes: {0},
        bottomLanes: {0},
        activeStack: [topRoute],
      ));
    }
    finalNodes.addAll(nodes);

    final displayNodes = oldestFirst ? finalNodes.reversed.toList() : finalNodes;
    final maxLane = finalNodes.fold(0, (m, n) => math.max(m, n.maxLane));
    final graphW = (maxLane + 1) * _GitLanePainter.laneW + 10.0;
    final totalSteps = finalNodes.length;

    final activeIndex = needVirtualCurrent
        ? (oldestFirst ? displayNodes.length - 1 : 0)
        : displayNodes.indexWhere((n) =>
            n.routeItem.event != RouteLogItem.eventPop &&
            n.routeItem.route == topRoute);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: displayNodes.length,
      itemBuilder: (_, i) {
        final node = displayNodes[i];
        // Step number in chronological order
        final stepNum = oldestFirst ? i + 1 : totalSteps - i;
        final isCurrent = i == activeIndex;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Git graph column (fixed width)
              SizedBox(
                width: graphW,
                child: CustomPaint(painter: _GitLanePainter(node)),
              ),
              // Route info card
              Expanded(
                child: _GitRouteInfo(
                  node: node,
                  isCurrent: isCurrent,
                  stepNum: stepNum,
                  compact: compact,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Route label card shown to the right of the git graph lanes.
class _GitRouteInfo extends StatelessWidget {
  final _GitNode node;
  final bool isCurrent;
  final int stepNum; // chronological step number (newest = highest)
  final bool compact;
  final bool isErrorTrace;
  const _GitRouteInfo({
    required this.node,
    required this.isCurrent,
    required this.stepNum,
    this.compact = false,
    this.isErrorTrace = false,
  });

  @override
  Widget build(BuildContext context) {
    final item = node.item as RouteLogItem;
    final ts = item.timestamp;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';

    // ── Human-readable direction instead of PUSH/POP ──────────────────
    final bool isReturn = item.event == 'RETURN';
    final bool isEnter = item.event == RouteLogItem.eventPush || isReturn;
    final bool isBack  = item.event == RouteLogItem.eventPop;
    final Color color  = isEnter
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

    final laneColor = _GitLanePainter._palette[node.lane % _GitLanePainter._palette.length];
    final badgeColor = isErrorTrace ? MonitorColors.statusError : MonitorColors.overlayApi;

    return Container(
      margin: EdgeInsets.only(
        left: compact ? 0 : 8,
        top: compact ? 2 : 4,
        bottom: compact ? 2 : 4,
      ),
      decoration: compact
          ? (isCurrent
              ? BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(6),
                )
              : null)
          : BoxDecoration(
              color: isCurrent
                  ? color.withValues(alpha: 0.07)
                  : MonitorColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrent
                    ? color.withValues(alpha: 0.40)
                    : MonitorColors.border.withValues(alpha: 0.35),
                width: isCurrent ? 0.9 : 0.5,
              ),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!compact)
                Container(
                  width: 4.5,
                  color: laneColor,
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 10,
                    vertical: compact ? 4 : 7,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ── Step number + direction row ──────────────────
                            Row(
                              children: [

                                Icon(dirIcon, size: 11, color: color),
                                // Duration for Back
                                if (durationStr != null) ...[
                                  const SizedBox(width: 6),
                                  MonoText(durationStr, 9,
                                      color: color, weight: FontWeight.w600),
                                ],
                                // CURRENT badge
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
                                        'CURRENT', MonitorColors.metricTotal,
                                        size: 7, spacing: 0.3),
                                  ),
                                ],
                                // API stats badge
                                if (node.apiCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: badgeColor
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: badgeColor
                                            .withValues(alpha: 0.35),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isErrorTrace ? Icons.bug_report_outlined : Icons.api_outlined,
                                          size: 8,
                                          color: badgeColor,
                                        ),
                                        const SizedBox(width: 2.5),
                                        MonoText(
                                          isErrorTrace ? '${node.apiCount}' : '${node.apiCount} • ${fmtDuration(node.apiDurationMs)}',
                                          8,
                                          color: badgeColor,
                                          weight: FontWeight.bold,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            // ── Route name ──────────────────────────────────
                            MonoText(
                              MonitorController.formatRouteName(item.route),
                              11,
                              color: isBack
                                  ? MonitorColors.secondaryText
                                  : MonitorColors.primaryText,
                              weight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // ── Timestamp ─────────────────────────────────────────
                      MonoText(timeStr, 9, color: MonitorColors.secondaryText),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


