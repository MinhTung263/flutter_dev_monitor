import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/api_log_item.dart';
import '../../../core/monitor_strings.dart';
import '../../../core/monitor_constants.dart';
import '../../../core/monitor_filter_keys.dart';
import '../../controller/monitor_controller.dart';
import '../theme/monitor_theme.dart';
import 'monitor_text.dart';
import 'responsive_dialog_wrapper.dart';

String _extractCleanPath(String rawUrl) {
  try {
    final uri = Uri.parse(rawUrl);
    return uri.path.isNotEmpty ? uri.path : rawUrl;
  } catch (_) {
    final idx = rawUrl.indexOf('?');
    return idx >= 0 ? rawUrl.substring(0, idx) : rawUrl;
  }
}

Set<String> _findDiffQueryKeys(ApiLogItem log) {
  final pathToCheck = _extractCleanPath(log.url);
  final allLogs = MonitorController.instance.apiLogs.isNotEmpty
      ? MonitorController.instance.apiLogs
      : MonitorController.instance.globalApiLogs;

  final siblingLogs = allLogs.where((l) {
    return l.method == log.method && _extractCleanPath(l.url) == pathToCheck;
  }).toList();

  final Set<String> diffKeys = {};
  if (siblingLogs.length > 1) {
    final Map<String, Set<String>> keyToValues = {};
    for (final sib in siblingLogs) {
      for (final entry in sib.queryParams.entries) {
        keyToValues
            .putIfAbsent(entry.key, () => {})
            .add(entry.value.toString());
      }
    }
    final allKeys = keyToValues.keys.toSet();
    for (final sib in siblingLogs) {
      for (final k in allKeys) {
        if (!sib.queryParams.containsKey(k)) {
          diffKeys.add(k);
        }
      }
    }
    keyToValues.forEach((key, values) {
      if (values.length > 1) {
        diffKeys.add(key);
      }
    });
  }
  return diffKeys;
}

Widget? _buildPayloadRow(BuildContext context, ApiLogItem log) {
  final requestBody = log.requestBody;
  if (requestBody != null && requestBody.isNotEmpty) {
    String clean;
    try {
      clean = requestBody.trim().replaceAll('\n', '').replaceAll(' ', '');
      if (clean.length > 60) {
        clean = '${clean.substring(0, 60)}...';
      }
    } catch (_) {
      clean = requestBody;
    }
    return Row(
      children: [
        Icon(Icons.subdirectory_arrow_right_rounded,
            size: 11, color: MonitorColors.secondaryText.withValues(alpha: 0.6)),
        const SizedBox(width: 3),
        Expanded(
          child: MonoText(
            'Body: $clean',
            9.5,
            color: MonitorColors.secondaryText.withValues(alpha: 0.8),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  if (log.queryParams.isNotEmpty) {
    final diffKeys = _findDiffQueryKeys(log);
    // If there is only 1 call or all sibling calls have identical query parameters, do NOT show params row!
    if (diffKeys.isEmpty) {
      return null;
    }

    final diffEntries = log.queryParams.entries
        .where((e) => diffKeys.contains(e.key))
        .toList();

    if (diffEntries.isEmpty) {
      return null;
    }

    final List<InlineSpan> spans = [];
    spans.add(TextSpan(
      text: 'Params diff: ',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 9.5,
        color: MonitorColors.isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
        fontWeight: FontWeight.w700,
      ),
    ));

    for (int i = 0; i < diffEntries.length; i++) {
      final entry = diffEntries[i];
      final paramColor = MonitorColors.isDark
          ? const Color(0xFFFBBF24)
          : const Color(0xFFD97706);

      spans.add(TextSpan(
        text: '⚡ ${entry.key}=',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9.5,
          color: paramColor,
          fontWeight: FontWeight.w700,
        ),
      ));
      spans.add(TextSpan(
        text: entry.value.toString(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9.5,
          color: paramColor,
          fontWeight: FontWeight.w800,
        ),
      ));

      if (i < diffEntries.length - 1) {
        spans.add(TextSpan(
          text: ',  ',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9.5,
            color: MonitorColors.secondaryText.withValues(alpha: 0.5),
          ),
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: (MonitorColors.isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: (MonitorColors.isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)).withValues(alpha: 0.25),
          width: 0.6,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.difference_rounded,
              size: 11, color: MonitorColors.isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
          const SizedBox(width: 4),
          Expanded(
            child: RichText(
              text: TextSpan(children: spans),
            ),
          ),
        ],
      ),
    );
  }

  return null;
}

Widget? _buildCompactPayloadRow(ApiLogItem log) {
  final requestBody = log.requestBody;
  if (requestBody != null && requestBody.isNotEmpty) {
    String clean;
    try {
      clean = requestBody.trim().replaceAll('\n', '').replaceAll(' ', '');
      if (clean.length > 50) {
        clean = '${clean.substring(0, 50)}...';
      }
    } catch (_) {
      clean = requestBody;
    }
    return MonoText(
      'Body: $clean',
      8.5,
      color: MonitorColors.secondaryText.withValues(alpha: 0.7),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  if (log.queryParams.isNotEmpty) {
    final diffKeys = _findDiffQueryKeys(log);
    if (diffKeys.isEmpty) {
      return null;
    }

    final diffEntries = log.queryParams.entries
        .where((e) => diffKeys.contains(e.key))
        .toList();

    if (diffEntries.isEmpty) {
      return null;
    }

    final List<InlineSpan> spans = [];
    spans.add(TextSpan(
      text: 'Diff: ',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 8.5,
        color: MonitorColors.isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
        fontWeight: FontWeight.w700,
      ),
    ));

    for (int i = 0; i < diffEntries.length; i++) {
      final entry = diffEntries[i];
      final paramColor = MonitorColors.isDark
          ? const Color(0xFFFBBF24)
          : const Color(0xFFD97706);

      spans.add(TextSpan(
        text: '${entry.key}=${entry.value}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 8.5,
          color: paramColor,
          fontWeight: FontWeight.bold,
        ),
      ));

      if (i < diffEntries.length - 1) {
        spans.add(TextSpan(
          text: ', ',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 8.5,
            color: MonitorColors.secondaryText.withValues(alpha: 0.4),
          ),
        ));
      }
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  return null;
}

class ApiLogTile extends StatefulWidget {
  final ApiLogItem log;
  final bool showOrder;
  final bool showScreenBadge;
  final int? lane;
  final bool compact;
  final bool showFullUrl;
  const ApiLogTile({
    super.key,
    required this.log,
    this.showOrder = true,
    this.showScreenBadge = false,
    this.lane,
    this.compact = false,
    this.showFullUrl = false,
  });

  @override
  State<ApiLogTile> createState() => _ApiLogTileState();
}

class _ApiLogTileState extends State<ApiLogTile> {
  bool _expanded = false;

  static const List<Color> _palette = [
    Color(0xFF4D9EFF), // blue
    Color(0xFF57D888), // green
    Color(0xFFE07B39), // orange
    Color(0xFF9B67EE), // purple
    Color(0xFF4DCFDE), // cyan
    Color(0xFFEE6B9E), // pink
  ];

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final statusColor = _statusColor(log);
    final laneColor = widget.lane != null ? _palette[widget.lane! % _palette.length] : null;

    final isExpanded = _expanded;
    final radius = widget.compact ? 6.0 : 8.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      margin: widget.compact
          ? EdgeInsets.symmetric(vertical: isExpanded ? 5.0 : 2.5)
          : EdgeInsets.only(
              top: isExpanded ? 6.0 : 0.0,
              bottom: isExpanded ? 10.0 : 5.0,
            ),
      decoration: BoxDecoration(
        color: MonitorColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isExpanded
              ? (log.isSlow
                  ? MonitorColors.statusSlow.withValues(alpha: 0.8)
                  : (!log.isSuccess
                      ? MonitorColors.statusError.withValues(alpha: 0.8)
                      : MonitorColors.metricTotal.withValues(alpha: 0.65)))
              : (log.isSlow
                  ? MonitorColors.statusSlow.withValues(alpha: widget.compact ? 0.35 : 0.4)
                  : (log.isSuccess
                      ? MonitorColors.border.withValues(alpha: widget.compact ? 0.45 : 1.0)
                      : MonitorColors.statusError.withValues(alpha: 0.35))),
          width: isExpanded
              ? (widget.compact ? 1.0 : 1.2)
              : (widget.compact ? 0.6 : 1.0),
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: MonitorColors.isDark ? 0.40 : 0.08),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 0.5),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (laneColor != null && !widget.compact)
                Container(
                  width: isExpanded ? 5.0 : 4.5,
                  color: laneColor,
                ),
              Expanded(
                child: Column(
                  children: [
                    widget.compact
                        ? _CompactCollapsedRow(
                            log: log,
                            statusColor: statusColor,
                            expanded: _expanded,
                            showFullUrl: widget.showFullUrl,
                            onTap: () => setState(() => _expanded = !_expanded),
                          )
                        : _CollapsedRow(
                            log: log,
                            statusColor: statusColor,
                            expanded: _expanded,
                            showOrder: widget.showOrder,
                            showScreenBadge: widget.showScreenBadge,
                            lane: widget.lane,
                            showFullUrl: widget.showFullUrl,
                            onTap: () => setState(() => _expanded = !_expanded),
                          ),
                    if (_expanded)
                      _ExpandedDetail(
                        log: log,
                        onCollapse: () => setState(() => _expanded = false),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(ApiLogItem log) {
    if (!log.isSuccess) return MonitorColors.statusError;
    if (log.isSlow) return MonitorColors.statusSlow;
    return MonitorColors.statusSuccess;
  }
}

// ─── Collapsed row ────────────────────────────────────────────────────────────

class _CollapsedRow extends StatelessWidget {
  final ApiLogItem log;
  final Color statusColor;
  final bool expanded;
  final bool showOrder;
  final bool showScreenBadge;
  final int? lane;
  final bool showFullUrl;
  final VoidCallback onTap;

  const _CollapsedRow({
    required this.log,
    required this.statusColor,
    required this.expanded,
    required this.showOrder,
    required this.showScreenBadge,
    this.lane,
    required this.showFullUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final payloadRow = _buildPayloadRow(context, log);
    // Shorten URL path (clean endpoint path without query string)
    String displayUrl = log.url;
    if (!showFullUrl) {
      displayUrl = _extractCleanPath(log.url);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: expanded
            ? (MonitorColors.isDark
                ? Colors.white.withValues(alpha: 0.025)
                : Colors.black.withValues(alpha: 0.018))
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Primary API signature (Method + Call Count + URL path + Duration)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _MethodBadge(method: log.method),
                ),
                if (log.hasMultipleCalls) ...[
                  const SizedBox(width: 5),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _CallCountBadge(count: log.callCount),
                  ),
                ],
                const SizedBox(width: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: MonoText(
                      displayUrl,
                      11.5,
                      color: MonitorColors.primaryText,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _DurationLabel(
                      duration: log.duration,
                      isSlow: log.isSlow,
                      color: statusColor),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.of(context).push(
                        MonitorResponsiveRoute(
                          builder: (_) => MonitorApiDetailPage(log: log),
                          settings: const RouteSettings(name: MonitorConstants.apiDetailPage),
                        ),
                      );
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: MonitorColors.expandedDetailBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MonitorColors.border,
                          width: 0.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.open_in_new_rounded,
                        color: MonitorColors.primaryText,
                        size: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: MonitorColors.secondaryText,
                    size: 14,
                  ),
                ),
              ],
            ),
            if (payloadRow != null) ...[
              const SizedBox(height: 4),
              payloadRow,
            ],
            // Row 2: Screen and Caller Metadata
            if (showScreenBadge || log.hasCallerName) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  if (showScreenBadge) ...[
                    _ScreenBadge(screen: log.screen, lane: lane),
                    const SizedBox(width: 6),
                  ],
                  if (log.hasCallerName)
                    Expanded(
                      child: _CallerRow(
                        callerName: log.callerName,
                        color: MonitorColors.secondaryText.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactCollapsedRow extends StatelessWidget {
  final ApiLogItem log;
  final Color statusColor;
  final bool expanded;
  final bool showFullUrl;
  final VoidCallback onTap;

  const _CompactCollapsedRow({
    required this.log,
    required this.statusColor,
    required this.expanded,
    required this.showFullUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compactPayloadRow = _buildCompactPayloadRow(log);
    final isGet = log.method == MonitorFilterKeys.get;
    final methodColor =
        isGet ? MonitorColors.methodGet : MonitorColors.methodPost;

    final ts = log.timestamp;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';

    // Shorten URL path (clean endpoint path without query string)
    String displayUrl = log.url;
    if (!showFullUrl) {
      displayUrl = _extractCleanPath(log.url);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        color: expanded
            ? (MonitorColors.isDark
                ? Colors.white.withValues(alpha: 0.025)
                : Colors.black.withValues(alpha: 0.018))
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Method Badge + Status Code + Duration + Multi-call count + Spacer + Timestamp + Detail button + Expand
            Row(
              children: [
                // Method Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: methodColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                        color: methodColor.withValues(alpha: 0.3), width: 0.5),
                  ),
                  child: LabelText(
                    log.method,
                    methodColor,
                    size: 7.5,
                    spacing: 0.2,
                  ),
                ),
                const SizedBox(width: 5),
                // Status Code
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: MonoText(
                    '${log.statusCode}',
                    8.5,
                    color: statusColor,
                    weight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 5),
                // Duration
                MonoText(
                  '${log.duration}ms',
                  8.5,
                  color: log.duration > 800
                      ? MonitorColors.statusSlow
                      : MonitorColors.secondaryText,
                ),
                if (log.hasMultipleCalls) ...[
                  const SizedBox(width: 4),
                  _CallCountBadge(count: log.callCount),
                ],
                const Spacer(),
                MonoText(
                  timeStr,
                  8.5,
                  color: MonitorColors.secondaryText.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push(
                      MonitorResponsiveRoute(
                        builder: (_) => MonitorApiDetailPage(log: log),
                        settings: const RouteSettings(name: MonitorConstants.apiDetailPage),
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
                    child: Icon(
                      Icons.open_in_new_rounded,
                      color: MonitorColors.primaryText,
                      size: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: MonitorColors.secondaryText,
                  size: 13,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Row 2: Full-width URL
            MonoText(
              displayUrl,
              10.5,
              color: MonitorColors.primaryText,
              weight: FontWeight.w500,
              maxLines: showFullUrl || expanded ? null : 2,
              overflow: showFullUrl || expanded ? null : TextOverflow.ellipsis,
            ),
            if (compactPayloadRow != null) ...[
              const SizedBox(height: 3),
              compactPayloadRow,
            ],
          ],
        ),
      ),
    );
  }
}

class _ScreenBadge extends StatelessWidget {
  final String screen;
  final int? lane;
  const _ScreenBadge({required this.screen, this.lane});

  static const List<Color> _palette = [
    Color(0xFF4D9EFF), // blue
    Color(0xFF57D888), // green
    Color(0xFFE07B39), // orange
    Color(0xFF9B67EE), // purple
    Color(0xFF4DCFDE), // cyan
    Color(0xFFEE6B9E), // pink
  ];

  @override
  Widget build(BuildContext context) {
    final title = MonitorController.formatRouteName(screen);
    final badgeColor = lane != null ? _palette[lane! % _palette.length] : const Color(0xFFA78BFA);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_outlined, size: 9, color: badgeColor),
          const SizedBox(width: 3),
          LabelText(
            title,
            badgeColor,
            size: 7.5,
            spacing: 0.3,
          ),
        ],
      ),
    );
  }
}

// ─── Expanded detail (tabbed) ─────────────────────────────────────────────────

class _ExpandedDetail extends StatefulWidget {
  final ApiLogItem log;
  final VoidCallback? onCollapse;
  const _ExpandedDetail({required this.log, this.onCollapse});

  @override
  State<_ExpandedDetail> createState() => _ExpandedDetailState();
}

class _ExpandedDetailState extends State<_ExpandedDetail> {
  int _tab = 0;

  static const _tabLabels = ['REQUEST', 'RESPONSE', 'TIMELINE', 'HEADERS'];

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(color: MonitorColors.border, height: 1),
        if (log.isSlow) _SlowBanner(duration: log.duration),
        // Tab bar + copy-all button
        Container(
          color: MonitorColors.expandedDetailBg,
          child: Row(
            children: [
              Expanded(
                child: _TabBar(
                  tabs: _tabLabels,
                  active: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
              ),
              // Vertical divider
              Container(
                width: 1,
                height: 34,
                color: MonitorColors.border,
              ),
              // Copy-all button
              GestureDetector(
                onTap: () => _showCopySheet(context, log),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 34,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.copy_all_rounded,
                    size: 16,
                    color: MonitorColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(color: MonitorColors.border, height: 1),
        Container(
          decoration: BoxDecoration(
            color: MonitorColors.expandedDetailBg,
          ),
          child: _buildContent(log),
        ),
        Container(color: MonitorColors.border, height: 1),
        _ExpandedDetailFooter(
          log: log,
          onCollapse: widget.onCollapse,
        ),
      ],
    );
  }

  void _showCopySheet(BuildContext context, ApiLogItem log) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      routeSettings: const RouteSettings(name: MonitorConstants.copyActionsSheet),
      builder: (_) => _CopyActionsSheet(log: log),
    );
  }

  Widget _buildContent(ApiLogItem log) {
    switch (_tab) {
      case 0:
        return _RequestContent(log: log);
      case 1:
        return _ResponseContent(log: log);
      case 2:
        return _TimelineContent(log: log);
      case 3:
        return _HeadersContent(log: log);
      default:
        return const SizedBox();
    }
  }
}

// ─── Expanded detail footer ──────────────────────────────────────────────────

class _ExpandedDetailFooter extends StatelessWidget {
  final ApiLogItem log;
  final VoidCallback? onCollapse;

  const _ExpandedDetailFooter({
    required this.log,
    this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _ApiLogTileState._statusColor(log);
    final ts = log.timestamp;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: MonitorColors.expandedDetailBg,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          // Mini status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 0.5),
            ),
            child: MonoText(
              '${log.statusCode}',
              10,
              color: statusColor,
              weight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          MonoText(
            '${log.duration}ms',
            10,
            color: log.isSlow ? MonitorColors.statusSlow : MonitorColors.secondaryText,
            weight: FontWeight.w600,
          ),
          if (log.hasResponseSize) ...[
            const SizedBox(width: 6),
            MonoText(
              '·  ${log.responseSizeFormatted}',
              10,
              color: MonitorColors.secondaryText,
            ),
          ],
          const SizedBox(width: 6),
          MonoText(
            '·  $timeStr',
            9.5,
            color: MonitorColors.secondaryText.withValues(alpha: 0.7),
          ),
          const Spacer(),
          // Fullscreen Detail button
          InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: () {
              Navigator.of(context).push(
                MonitorResponsiveRoute(
                  builder: (_) => MonitorApiDetailPage(log: log),
                  settings: const RouteSettings(name: MonitorConstants.apiDetailPage),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: MonitorColors.surface,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: MonitorColors.border, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_new_rounded, size: 11, color: MonitorColors.primaryText),
                  const SizedBox(width: 4),
                  BodyText('Detail', 9.5, color: MonitorColors.primaryText, weight: FontWeight.w500),
                ],
              ),
            ),
          ),
          if (onCollapse != null) ...[
            const SizedBox(width: 6),
            // Quick collapse button
            InkWell(
              borderRadius: BorderRadius.circular(5),
              onTap: onCollapse,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: MonitorColors.surface,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: MonitorColors.metricTotal.withValues(alpha: 0.4),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.keyboard_arrow_up_rounded, size: 13, color: MonitorColors.metricTotal),
                    const SizedBox(width: 3),
                    BodyText(
                      LocaleKeys.collapse.tr,
                      9.5,
                      color: MonitorColors.metricTotal,
                      weight: FontWeight.bold,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Tab bar ─────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final List<String> tabs;
  final int active;
  final ValueChanged<int> onTap;

  const _TabBar(
      {required this.tabs, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MonitorColors.expandedDetailBg,
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active == i
                          ? MonitorColors.metricTotal
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: active == i
                    ? LabelText(tabs[i], MonitorColors.metricTotal, size: 9)
                    : BodyText(tabs[i], 9, color: MonitorColors.secondaryText, weight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Timeline content (original) ─────────────────────────────────────────────

class _TimelineContent extends StatelessWidget {
  final ApiLogItem log;
  const _TimelineContent({required this.log});

  @override
  Widget build(BuildContext context) {
    final ts = log.timestamp;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabelText('EXECUTION TIMELINE', MonitorColors.secondaryText, size: 9, spacing: 0.8),
          const SizedBox(height: 12),
          _TimelineStep(
            title: 'Request Sent',
            subtitle: 'Request packet started leaving the device.',
            timeStr: timeStr,
            isFirst: true,
            color: MonitorColors.methodGet,
          ),
          _TimelineStep(
            title: 'Server Processing',
            subtitle: 'Network transfer time and backend server processing.',
            timeStr: '+${log.duration}ms',
            color:
                log.isSlow ? MonitorColors.statusSlow : MonitorColors.methodGet,
          ),
          _TimelineStep(
            title: 'Payload Response',
            subtitle: log.hasResponseSize
                ? 'HTTP ${log.statusCode} — ${log.responseSizeFormatted}'
                : 'HTTP ${log.statusCode} — Data synchronized.',
            timeStr: 'Done',
            isLast: true,
            color: log.isSuccess
                ? MonitorColors.statusSuccess
                : MonitorColors.statusError,
          ),
          const SizedBox(height: 8),
          Container(color: MonitorColors.border, height: 1),
          const SizedBox(height: 6),
          _LogFooter(log: log),
        ],
      ),
    );
  }
}

// ─── cURL generation ─────────────────────────────────────────────────────────

String _fmtParams(Map<String, String> p) =>
    p.entries.map((e) => '${e.key}=${e.value}').join('&');

String _fmtHeaders(Map<String, String> h) =>
    h.entries.map((e) => '${e.key}: ${e.value}').join('\n');

String _buildCurl(ApiLogItem log) {
  final sb = StringBuffer('curl -X ${log.method}');

  // URL (already full URI from options.uri.toString())
  sb.write(" \\\n  '${log.url}'");

  // Request headers
  for (final e in log.requestHeaders.entries) {
    sb.write(" \\\n  -H '${e.key}: ${e.value}'");
  }

  // Body — compact JSON for readability in terminal
  if (log.requestBody != null && log.requestBody!.isNotEmpty) {
    String body = log.requestBody!;
    try {
      body = jsonEncode(jsonDecode(body));
    } catch (_) {
      body = body.replaceAll('\n', ' ').replaceAll(RegExp(r' {2,}'), ' ');
    }
    sb.write(" \\\n  -d '$body'");
  }

  return sb.toString();
}

// ─── Request content ──────────────────────────────────────────────────────────

class _RequestContent extends StatelessWidget {
  final ApiLogItem log;
  final bool isFullPage;
  const _RequestContent({required this.log, this.isFullPage = false});

  @override
  Widget build(BuildContext context) {
    final hasQuery = log.queryParams.isNotEmpty;
    final hasBody = log.requestBody != null && log.requestBody!.isNotEmpty;
    final curl = _buildCurl(log);

    final topContent = [
      // URL row: label + copy url + copy cURL
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SectionLabel('URL'),
          const Spacer(),
          _InlineCopyBtn(text: log.url),
          const SizedBox(width: 6),
          _CurlCopyButton(curl: curl),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MethodBadge(method: log.method),
          const SizedBox(width: 8),
          Expanded(
            child: SelectionArea(
              child: MonoText(log.url, 11, color: MonitorColors.primaryText, height: 1.4),
            ),
          ),
        ],
      ),
      if (hasQuery) ...[
        const SizedBox(height: 12),
        _SectionRow(
            label: 'QUERY PARAMS', copyText: _fmtParams(log.queryParams)),
        const SizedBox(height: 6),
        _KVTable(entries: log.queryParams.entries.toList()),
      ],
    ];

    if (!isFullPage) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...topContent,
            if (hasBody) ...[
              const SizedBox(height: 14),
              _SectionLabel('BODY'),
              const SizedBox(height: 6),
              _BodyBlock(text: log.requestBody!),
            ],
            if (!hasQuery && !hasBody) ...[
              const SizedBox(height: 8),
              BodyText('No query params or body.', 11, color: MonitorColors.secondaryText),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...topContent,
          if (hasBody) ...[
            const SizedBox(height: 10),
            _SectionLabel('BODY'),
            const SizedBox(height: 6),
            Expanded(
              child: _BodyBlock(
                text: log.requestBody!,
                fillHeight: true,
              ),
            ),
          ],
          if (!hasQuery && !hasBody) ...[
            const SizedBox(height: 8),
            BodyText('No query params or body.', 11, color: MonitorColors.secondaryText),
          ],
        ],
      ),
    );
  }
}

// ─── cURL copy button ─────────────────────────────────────────────────────────

class _CurlCopyButton extends StatefulWidget {
  final String curl;
  const _CurlCopyButton({required this.curl});

  @override
  State<_CurlCopyButton> createState() => _CurlCopyButtonState();
}

class _CurlCopyButtonState extends State<_CurlCopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.curl));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _copy,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _copied
              ? MonitorColors.statusSuccess.withValues(alpha: 0.12)
              : MonitorColors.metricTotal.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: _copied
                ? MonitorColors.statusSuccess.withValues(alpha: 0.4)
                : MonitorColors.metricTotal.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check_rounded : Icons.terminal_rounded,
              size: 11,
              color: _copied
                  ? MonitorColors.statusSuccess
                  : MonitorColors.metricTotal,
            ),
            const SizedBox(width: 4),
            BodyText(_copied ? 'Copied!' : 'Copy cURL', 9, color: _copied ? MonitorColors.statusSuccess : MonitorColors.metricTotal, weight: FontWeight.bold),
          ],
        ),
      ),
    );
  }
}

// ─── Response content ─────────────────────────────────────────────────────────

class _ResponseContent extends StatelessWidget {
  final ApiLogItem log;
  final bool isFullPage;
  const _ResponseContent({required this.log, this.isFullPage = false});

  @override
  Widget build(BuildContext context) {
    final hasBody = log.responseBody != null && log.responseBody!.isNotEmpty;
    final statusColor =
        log.isSuccess ? MonitorColors.statusSuccess : MonitorColors.statusError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.06),
            border: Border(
              bottom: BorderSide(color: MonitorColors.border),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.4), width: 0.5),
                ),
                child: MonoText('${log.statusCode}', 11, color: statusColor, weight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              MonoText('${log.duration}ms', 11, color: log.isSlow ? MonitorColors.statusSlow : MonitorColors.secondaryText, weight: FontWeight.w600),
              if (log.hasResponseSize) ...[
                const SizedBox(width: 10),
                MonoText(log.responseSizeFormatted, 11),
              ],
            ],
          ),
        ),
        if (hasBody)
          isFullPage
              ? Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _BodyBlock(
                      text: log.responseBody!,
                      fillHeight: true,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: _BodyBlock(text: log.responseBody!),
                )
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: BodyText('No response body.', 11, color: MonitorColors.secondaryText),
          ),
      ],
    );
  }
}

// ─── Headers content ──────────────────────────────────────────────────────────

class _HeadersContent extends StatelessWidget {
  final ApiLogItem log;
  const _HeadersContent({required this.log});

  @override
  Widget build(BuildContext context) {
    final hasReqHeaders = log.requestHeaders.isNotEmpty;
    final hasResHeaders = log.responseHeaders.isNotEmpty;

    if (!hasReqHeaders && !hasResHeaders) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: BodyText('No headers captured.', 11, color: MonitorColors.secondaryText),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasReqHeaders) ...[
            _SectionRow(
                label: 'REQUEST HEADERS',
                copyText: _fmtHeaders(log.requestHeaders)),
            const SizedBox(height: 6),
            _KVTable(entries: log.requestHeaders.entries.toList()),
          ],
          if (hasReqHeaders && hasResHeaders) const SizedBox(height: 14),
          if (hasResHeaders) ...[
            _SectionRow(
                label: 'RESPONSE HEADERS',
                copyText: _fmtHeaders(log.responseHeaders)),
            const SizedBox(height: 6),
            _KVTable(entries: log.responseHeaders.entries.toList()),
          ],
        ],
      ),
    );
  }
}

// ─── Copy actions sheet ───────────────────────────────────────────────────────

class _CopyActionsSheet extends StatefulWidget {
  final ApiLogItem log;
  const _CopyActionsSheet({required this.log});

  @override
  State<_CopyActionsSheet> createState() => _CopyActionsSheetState();
}

class _CopyActionsSheetState extends State<_CopyActionsSheet> {
  String? _lastCopied;

  Future<void> _copy(String key, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    setState(() => _lastCopied = key);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _lastCopied = null);
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final curl = _buildCurl(log);

    final actions = <_CopyAction>[
      _CopyAction(
        key: 'url',
        icon: Icons.link_rounded,
        label: 'URL',
        preview: log.url,
        text: log.url,
      ),
      _CopyAction(
        key: 'curl',
        icon: Icons.terminal_rounded,
        label: 'cURL',
        preview: 'curl -X ${log.method} \'${log.url}\'…',
        text: curl,
      ),
      if (log.queryParams.isNotEmpty)
        _CopyAction(
          key: 'params',
          icon: Icons.tune_rounded,
          label: 'Query Params',
          preview: _fmtParams(log.queryParams),
          text: _fmtParams(log.queryParams),
        ),
      if (log.requestBody != null && log.requestBody!.isNotEmpty)
        _CopyAction(
          key: 'req_body',
          icon: Icons.upload_rounded,
          label: 'Request Body',
          preview: log.requestBody!.replaceAll('\n', ' ').substring(
              0,
              log.requestBody!.length.clamp(0, 60)),
          text: log.requestBody!,
        ),
      if (log.responseBody != null && log.responseBody!.isNotEmpty)
        _CopyAction(
          key: 'res_body',
          icon: Icons.download_rounded,
          label: 'Response Body',
          preview: log.responseBody!.replaceAll('\n', ' ').substring(
              0,
              log.responseBody!.length.clamp(0, 60)),
          text: log.responseBody!,
        ),
      if (log.requestHeaders.isNotEmpty)
        _CopyAction(
          key: 'req_headers',
          icon: Icons.arrow_upward_rounded,
          label: 'Request Headers',
          preview: '${log.requestHeaders.length} headers',
          text: _fmtHeaders(log.requestHeaders),
        ),
      if (log.responseHeaders.isNotEmpty)
        _CopyAction(
          key: 'res_headers',
          icon: Icons.arrow_downward_rounded,
          label: 'Response Headers',
          preview: '${log.responseHeaders.length} headers',
          text: _fmtHeaders(log.responseHeaders),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: MonitorColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 14),
            decoration: BoxDecoration(
              color: MonitorColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Icon(Icons.copy_all_rounded,
                    size: 16, color: MonitorColors.secondaryText),
                const SizedBox(width: 8),
                BodyText('Copy', 14, weight: FontWeight.bold),
                const Spacer(),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: (log.isSuccess
                            ? MonitorColors.statusSuccess
                            : MonitorColors.statusError)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: MonoText('${log.method} ${log.statusCode}', 10, color: log.isSuccess ? MonitorColors.statusSuccess : MonitorColors.statusError, weight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(height: 1, color: MonitorColors.border),
          // Actions list
          for (final action in actions) ...[
            InkWell(
              onTap: () => _copy(action.key, action.text),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: MonitorColors.expandedDetailBg,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: MonitorColors.border),
                      ),
                      child: Icon(action.icon,
                          size: 15,
                          color: MonitorColors.secondaryText),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BodyText(action.label, 13, weight: FontWeight.w600),
                          const SizedBox(height: 2),
                          MonoText(action.preview, 10, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _lastCopied == action.key
                          ? Icon(Icons.check_rounded,
                              key: const ValueKey('check'),
                              size: 18,
                              color: MonitorColors.statusSuccess)
                          : Icon(Icons.copy_rounded,
                              key: const ValueKey('copy'),
                              size: 16,
                              color: MonitorColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ),
            Container(height: 1, color: MonitorColors.border),
          ],
          SizedBox(
              height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _CopyAction {
  final String key;
  final IconData icon;
  final String label;
  final String preview;
  final String text;

  const _CopyAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.preview,
    required this.text,
  });
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return LabelText(label, MonitorColors.secondaryText, size: 9, spacing: 0.8);
  }
}

/// Section header row: label on left + optional copy button on right.
class _SectionRow extends StatelessWidget {
  final String label;
  final String copyText;

  const _SectionRow({required this.label, required this.copyText});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _SectionLabel(label),
        const Spacer(),
        _InlineCopyBtn(text: copyText),
      ],
    );
  }
}

/// Small icon-only copy button with ✓ feedback.
class _InlineCopyBtn extends StatefulWidget {
  final String text;
  const _InlineCopyBtn({required this.text});

  @override
  State<_InlineCopyBtn> createState() => _InlineCopyBtnState();
}

class _InlineCopyBtnState extends State<_InlineCopyBtn> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _copy,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: (_copied
                  ? MonitorColors.statusSuccess
                  : MonitorColors.secondaryText)
              .withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          _copied ? Icons.check_rounded : Icons.copy_rounded,
          size: 11,
          color: _copied
              ? MonitorColors.statusSuccess
              : MonitorColors.secondaryText,
        ),
      ),
    );
  }
}

class _KVTable extends StatelessWidget {
  final List<MapEntry<String, String>> entries;
  const _KVTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MonitorColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MonitorColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            if (i > 0) Container(height: 1, color: MonitorColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: MonoText(entries[i].key, 10, color: MonitorColors.callerName, weight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectionArea(
                      child: MonoText(entries[i].value, 10, color: MonitorColors.primaryText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BodyBlock extends StatefulWidget {
  final String text;
  final bool fillHeight;
  const _BodyBlock({required this.text, this.fillHeight = false});

  @override
  State<_BodyBlock> createState() => _BodyBlockState();
}

class _BodyBlockState extends State<_BodyBlock> {
  bool _prettyJson = true;
  bool _searchMode = false;
  String _searchQuery = '';
  late final ScrollController _scrollController;
  late final ScrollController _horizontalScrollController;

  late String _formattedText;
  late List<String> _lines;
  final List<int> _matchingLineIndices = [];
  int _currentMatchIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _horizontalScrollController = ScrollController();
    _processText();
  }

  @override
  void didUpdateWidget(covariant _BodyBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _processText();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _processText() {
    final raw = widget.text;
    if (_prettyJson) {
      final trimmed = raw.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          final decoded = jsonDecode(trimmed);
          _formattedText = const JsonEncoder.withIndent('  ').convert(decoded);
        } catch (_) {
          _formattedText = raw;
        }
      } else {
        _formattedText = raw;
      }
    } else {
      _formattedText = raw;
    }
    _lines = _formattedText.split('\n');
    if (_searchQuery.isNotEmpty) {
      _performSearch(_searchQuery);
    }
  }

  void _performSearch(String query) {
    _matchingLineIndices.clear();
    _currentMatchIndex = 0;
    if (query.isEmpty) return;

    final lowerQuery = query.toLowerCase();
    for (int i = 0; i < _lines.length; i++) {
      if (_lines[i].toLowerCase().contains(lowerQuery)) {
        _matchingLineIndices.add(i);
      }
    }
  }

  void _scrollToMatch(int matchIndex) {
    if (_matchingLineIndices.isEmpty || matchIndex >= _matchingLineIndices.length) return;
    final lineIdx = _matchingLineIndices[matchIndex];
    const double lineH = 18.5;
    final targetY = (lineIdx * lineH) - 60.0;
    if (_scrollController.hasClients) {
      final clamped = targetY.clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _nextMatch() {
    if (_matchingLineIndices.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchingLineIndices.length;
      _scrollToMatch(_currentMatchIndex);
    });
  }

  void _prevMatch() {
    if (_matchingLineIndices.isEmpty) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _matchingLineIndices.length) % _matchingLineIndices.length;
      _scrollToMatch(_currentMatchIndex);
    });
  }

  TextSpan _buildHighlightedLine(String line, String query, TextStyle baseStyle) {
    if (query.isEmpty) {
      return TextSpan(text: line, style: baseStyle);
    }

    final lowerLine = line.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <InlineSpan>[];
    int start = 0;

    while (true) {
      final index = lowerLine.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: line.substring(start), style: baseStyle));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: line.substring(start, index), style: baseStyle));
      }

      spans.add(TextSpan(
        text: line.substring(index, index + query.length),
        style: baseStyle.copyWith(
          backgroundColor: Colors.orange.withValues(alpha: 0.85),
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
    }

    return TextSpan(children: spans);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MonitorColors.isDark;
    final headerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final bodyBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderCol = MonitorColors.border.withValues(alpha: 0.8);
    final lineNumCol = MonitorColors.secondaryText.withValues(alpha: 0.5);

    final isJson = widget.text.trim().startsWith('{') || widget.text.trim().startsWith('[');
    final sizeStr = _formatSize(widget.text.length);
    final lineCount = _lines.length;

    final double linesHeight = (_lines.length * 18.5) + 16.0;
    final double boxHeight = linesHeight.clamp(80.0, 360.0);

    final Widget codeContent = Container(
      decoration: BoxDecoration(
        color: bodyBg,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(7.2),
          bottomRight: Radius.circular(7.2),
        ),
      ),
      child: SelectionArea(
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1200,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _lines.length,
                itemExtent: 18.5,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final line = _lines[index];
                  final isMatchedLine = _searchQuery.isNotEmpty &&
                      _matchingLineIndices.contains(index);
                  final isCurrentActiveMatch = _matchingLineIndices.isNotEmpty &&
                      _currentMatchIndex < _matchingLineIndices.length &&
                      _matchingLineIndices[_currentMatchIndex] == index;

                  final lineNumWidth = (_lines.length.toString().length * 7.5 + 16.0).clamp(32.0, 64.0);

                  return Container(
                    color: isCurrentActiveMatch
                        ? Colors.orange.withValues(alpha: 0.18)
                        : isMatchedLine
                            ? Colors.yellow.withValues(alpha: 0.08)
                            : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: lineNumWidth,
                          child: Text(
                            '${index + 1}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: MonitorTextStyle.monoFontFamily,
                              fontSize: 9,
                              color: lineNumCol,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 14,
                          color: borderCol.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            text: _buildHighlightedLine(
                              line,
                              _searchQuery,
                              TextStyle(
                                fontFamily: MonitorTextStyle.monoFontFamily,
                                fontSize: 10,
                                color: MonitorColors.primaryText,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: bodyBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderCol, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: widget.fillHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // ── Header Bar ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7.2),
                topRight: Radius.circular(7.2),
              ),
              border: Border(
                bottom: BorderSide(color: borderCol, width: 0.8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isJson
                              ? MonitorColors.statusSuccess.withValues(alpha: 0.15)
                              : MonitorColors.secondaryText.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: MonoText(
                          isJson ? 'JSON' : 'TEXT',
                          8.0,
                          color: isJson ? MonitorColors.statusSuccess : MonitorColors.secondaryText,
                          weight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '$lineCount lines • $sizeStr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: MonitorTextStyle.monoFontFamily,
                            fontSize: 8.0,
                            color: MonitorColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isJson) ...[
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _prettyJson = !_prettyJson;
                            _processText();
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: _prettyJson
                                ? MonitorColors.metricTotal.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _prettyJson
                                  ? MonitorColors.metricTotal.withValues(alpha: 0.4)
                                  : borderCol,
                              width: 0.6,
                            ),
                          ),
                          child: MonoText(
                            _prettyJson ? 'PRETTY' : 'RAW',
                            7.5,
                            color: _prettyJson
                                ? MonitorColors.metricTotal
                                : MonitorColors.secondaryText,
                            weight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: Icon(
                        _searchMode ? Icons.close : Icons.search,
                        size: 13,
                        color: _searchMode ? MonitorColors.statusError : MonitorColors.secondaryText,
                      ),
                      onPressed: () {
                        setState(() {
                          _searchMode = !_searchMode;
                          if (!_searchMode) {
                            _searchQuery = '';
                            _matchingLineIndices.clear();
                          }
                        });
                      },
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      tooltip: 'Search',
                    ),
                    const SizedBox(width: 4),
                    _CopyButton(text: _formattedText),
                  ],
                ),
              ],
            ),
          ),

          // ── Search Sub-Bar ──────────────────────────────────────────
          if (_searchMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MonitorColors.pageBackground,
                border: Border(bottom: BorderSide(color: borderCol, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      style: TextStyle(
                        fontFamily: MonitorTextStyle.monoFontFamily,
                        fontSize: 10,
                        color: MonitorColors.primaryText,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        hintText: LocaleKeys.searchResponsePlaceholder.tr,
                        hintStyle: TextStyle(
                          fontFamily: MonitorTextStyle.monoFontFamily,
                          fontSize: 9.5,
                          color: MonitorColors.secondaryText.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _performSearch(val);
                          if (_matchingLineIndices.isNotEmpty) {
                            _scrollToMatch(0);
                          }
                        });
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    MonoText(
                      _matchingLineIndices.isEmpty
                          ? '0/0'
                          : '${_currentMatchIndex + 1}/${_matchingLineIndices.length}',
                      8,
                      color: MonitorColors.secondaryText,
                      weight: FontWeight.bold,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.keyboard_arrow_up_rounded,
                          size: 14, color: MonitorColors.primaryText),
                      onPressed: _prevMatch,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      tooltip: LocaleKeys.previousMatch.tr,
                    ),
                    IconButton(
                      icon: Icon(Icons.keyboard_arrow_down_rounded,
                          size: 14, color: MonitorColors.primaryText),
                      onPressed: _nextMatch,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      tooltip: LocaleKeys.nextMatch.tr,
                    ),
                  ],
                ],
              ),
            ),

          // ── Virtualized Code Content (O(1) Memory & Rendering) ───────
          if (widget.fillHeight)
            Expanded(child: codeContent)
          else
            SizedBox(
              height: boxHeight,
              child: codeContent,
            ),
        ],
      ),
    );
  }
}
class _CopyButton extends StatefulWidget {
  final String text;
  const _CopyButton({required this.text});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _copy,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _copied
              ? MonitorColors.statusSuccess.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 10.5,
              color: _copied
                  ? MonitorColors.statusSuccess
                  : MonitorColors.secondaryText,
            ),
            const SizedBox(width: 4),
            BodyText(
              _copied ? 'Copied' : 'Copy',
              9.5,
              color: _copied
                  ? MonitorColors.statusSuccess
                  : MonitorColors.secondaryText,
              weight: FontWeight.w600,
            ),
          ],
        ),
      ),
    );
  }
}





class _MethodBadge extends StatelessWidget {
  final String method;
  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final isGet = method == MonitorFilterKeys.get;
    final color = isGet ? MonitorColors.methodGet : MonitorColors.methodPost;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: BodyText(method, 9, color: color, weight: FontWeight.bold),
    );
  }
}

class _DurationLabel extends StatelessWidget {
  final int duration;
  final bool isSlow;
  final Color color;
  const _DurationLabel(
      {required this.duration, required this.isSlow, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        MonoText('${duration}ms', 11, color: color, weight: FontWeight.bold),
        if (isSlow)
          BodyText('⚠ SLOW', 7, color: MonitorColors.statusSlow, weight: FontWeight.bold),
      ],
    );
  }
}

class _CallerRow extends StatelessWidget {
  final String callerName;
  final Color color;
  const _CallerRow({required this.callerName, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.call_made, size: 10, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: MonoText(callerName, 10, color: color, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _CallCountBadge extends StatelessWidget {
  final int count;
  const _CallCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border:
            Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: MonoText('×$count', 9, color: Color(0xFFB45309), weight: FontWeight.bold),
    );
  }
}

class _SlowBanner extends StatelessWidget {
  final int duration;
  const _SlowBanner({required this.duration});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: MonitorColors.slowBannerBg,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: MonitorColors.statusSlow, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: BodyText('Slow: ${(duration / 1000).toStringAsFixed(2)}s — risk of UI jank.', 10, color: MonitorColors.statusSlow, weight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timeStr;
  final Color color;
  final bool isFirst;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.timeStr,
    required this.color,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: MonitorColors.expandedDetailBg,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 32, color: MonitorColors.border),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyText(title, 11, weight: FontWeight.bold),
              const SizedBox(height: 2),
              BodyText(subtitle, 10, color: MonitorColors.secondaryText),
              const SizedBox(height: 4),
            ],
          ),
        ),
        MonoText(timeStr, 10.5, weight: FontWeight.bold),
      ],
    );
  }
}

class _LogFooter extends StatelessWidget {
  final ApiLogItem log;
  const _LogFooter({required this.log});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoText('${MonitorController.formatRouteName(log.screen)}  ·  ${log.phase == 'OPEN' ? LocaleKeys.initLabel.tr : LocaleKeys.actionLabel.tr}', 10, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (log.hasCallerName) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.call_made, size: 10, color: MonitorColors.callerName),
              const SizedBox(width: 4),
              Expanded(
                child: SelectionArea(
                  child: MonoText(log.callerName, 10, color: MonitorColors.callerName, weight: FontWeight.w600, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class MonitorApiDetailPage extends StatefulWidget {
  final ApiLogItem log;
  const MonitorApiDetailPage({super.key, required this.log});

  @override
  State<MonitorApiDetailPage> createState() => _MonitorApiDetailPageState();
}

class _MonitorApiDetailPageState extends State<MonitorApiDetailPage> {
  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final displayUrl = log.url;

    return ValueListenableBuilder<bool>(
      valueListenable: MonitorColors.isDarkNotifier,
      builder: (context, _, __) {
        final statusColor = _ApiLogTileState._statusColor(log);
        final double screenWidth = MediaQuery.of(context).size.width;
        final bool isLargeScreen = screenWidth > 640;
        return MonitorResponsiveDialogWrapper(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: MonitorColors.surface,
            elevation: 0,
            leading: isLargeScreen
                ? null
                : IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: MonitorColors.primaryText, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoText(
                        displayUrl,
                        12,
                        color: MonitorColors.primaryText,
                        weight: FontWeight.bold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          MonoText(
                            log.method,
                            9.5,
                            color: log.isSuccess
                                ? MonitorColors.statusSuccess
                                : MonitorColors.statusError,
                            weight: FontWeight.bold,
                          ),
                          const SizedBox(width: 8),
                          MonoText(
                            '${log.statusCode}  ·  ${log.duration}ms',
                            9.5,
                            color: statusColor,
                            weight: FontWeight.w600,
                          ),
                          if (log.hasResponseSize) ...[
                            const SizedBox(width: 8),
                            MonoText(
                              '·  ${log.responseSizeFormatted}',
                              9.5,
                              color: MonitorColors.secondaryText,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                color: MonitorColors.border,
                height: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // API Caller & Multiple Calls metadata card (if present)
                  if (log.hasCallerName || log.hasMultipleCalls) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: MonitorColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: MonitorColors.border,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (log.hasMultipleCalls) ...[
                            _CallCountBadge(count: log.callCount),
                            const SizedBox(width: 8),
                          ],
                          if (log.hasCallerName)
                            Expanded(
                              child: _CallerRow(
                                callerName: log.callerName,
                                color: MonitorColors.secondaryText.withValues(alpha: 0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  // Detail Tabs Section filling the entire remaining height!
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: MonitorColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: MonitorColors.border,
                          width: 1.0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _DetailTabsSection(log: log, isFullPage: true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailTabsSection extends StatefulWidget {
  final ApiLogItem log;
  final bool isFullPage;
  const _DetailTabsSection({required this.log, this.isFullPage = false});

  @override
  State<_DetailTabsSection> createState() => _DetailTabsSectionState();
}

class _DetailTabsSectionState extends State<_DetailTabsSection> {
  int _tab = 0;
  static const _tabLabels = ['REQUEST', 'RESPONSE', 'TIMELINE', 'HEADERS'];

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (log.isSlow) _SlowBanner(duration: log.duration),
        // Tab bar + copy-all button
        Container(
          color: MonitorColors.expandedDetailBg,
          child: Row(
            children: [
              Expanded(
                child: _TabBar(
                  tabs: _tabLabels,
                  active: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
              ),
              // Vertical divider
              Container(
                width: 1,
                height: 34,
                color: MonitorColors.border,
              ),
              // Copy-all button
              GestureDetector(
                onTap: () => _showCopySheet(context, log),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 34,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.copy_all_rounded,
                    size: 16,
                    color: MonitorColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(color: MonitorColors.border, height: 1),
        if (widget.isFullPage)
          Expanded(
            child: Container(
              color: MonitorColors.expandedDetailBg,
              child: _buildContent(log, isFullPage: true),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: MonitorColors.expandedDetailBg,
            ),
            child: _buildContent(log, isFullPage: false),
          ),
      ],
    );
  }

  void _showCopySheet(BuildContext context, ApiLogItem log) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      routeSettings: const RouteSettings(name: MonitorConstants.copyActionsSheet),
      builder: (_) => _CopyActionsSheet(log: log),
    );
  }

  Widget _buildContent(ApiLogItem log, {bool isFullPage = false}) {
    switch (_tab) {
      case 0:
        return _RequestContent(log: log, isFullPage: isFullPage);
      case 1:
        return _ResponseContent(log: log, isFullPage: isFullPage);
      case 2:
        return isFullPage
            ? SingleChildScrollView(child: _TimelineContent(log: log))
            : _TimelineContent(log: log);
      case 3:
        return isFullPage
            ? SingleChildScrollView(child: _HeadersContent(log: log))
            : _HeadersContent(log: log);
      default:
        return const SizedBox();
    }
  }
}
