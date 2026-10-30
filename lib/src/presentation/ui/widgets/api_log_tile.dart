import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/api_log_item.dart';
import '../../../core/monitor_strings.dart';
import '../../../core/monitor_constants.dart';
import '../../controller/monitor_controller.dart';
import '../theme/monitor_theme.dart';
import 'monitor_text.dart';
import 'monitor_theme_scope.dart';
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

Map<String, String> _extractEffectiveQueryParams(ApiLogItem log) {
  if (log.queryParams.isNotEmpty) return log.queryParams;
  try {
    final uri = Uri.parse(log.url);
    if (uri.queryParameters.isNotEmpty) {
      return uri.queryParameters;
    }
  } catch (_) {}
  return const {};
}

void _flattenJsonIntoMap(
  dynamic value,
  String prefix,
  Map<String, String> out, {
  int depth = 0,
}) {
  if (value == null) {
    out[prefix] = 'null';
    return;
  }
  if (depth < 3 && value is Map) {
    if (value.isEmpty) {
      out[prefix] = '{}';
      return;
    }
    value.forEach((k, v) {
      final nextKey = prefix.isEmpty ? k.toString() : '$prefix.$k';
      _flattenJsonIntoMap(v, nextKey, out, depth: depth + 1);
    });
    return;
  }
  if (depth < 2 &&
      value is List &&
      value.isNotEmpty &&
      value.length <= 4 &&
      value.every((e) => e is Map)) {
    for (int i = 0; i < value.length; i++) {
      final nextKey = '$prefix[$i]';
      _flattenJsonIntoMap(value[i], nextKey, out, depth: depth + 1);
    }
    return;
  }
  if (value is Map || value is List) {
    out[prefix] = jsonEncode(value);
  } else {
    out[prefix] = value.toString();
  }
}

Map<String, String> _extractBodyMapParams(ApiLogItem log) {
  final raw = log.requestBody;
  if (raw == null || raw.isEmpty) return const {};
  final trimmed = raw.trim();
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final Map<dynamic, dynamic> targetMap =
            (decoded['@type'] == 'FormData' && decoded['@fields'] is Map)
                ? decoded['@fields'] as Map
                : decoded;
        final result = <String, String>{};
        _flattenJsonIntoMap(targetMap, '', result);
        return result;
      }
    } catch (_) {}
  } else if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        final result = <String, String>{};
        _flattenJsonIntoMap(decoded, 'body', result);
        return result;
      }
    } catch (_) {}
  }
  return const {};
}

Map<String, String> _extractAllParamsMap(ApiLogItem log) {
  final query = _extractEffectiveQueryParams(log);
  final body = _extractBodyMapParams(log);
  if (query.isEmpty && body.isEmpty) {
    if (log.requestBody != null && log.requestBody!.trim().isNotEmpty) {
      return {'@body': log.requestBody!.trim()};
    }
    return const {};
  }
  return {...query, ...body};
}

class _ParamDiffEntry {
  final String key;
  final String currentValue;
  final List<({int callIndex, String value, String phase})> otherValues;
  final List<({int callIndex, String value, String phase, bool isCurrent})>
      allCallValues;
  final bool isMissingInCurrent;

  const _ParamDiffEntry({
    required this.key,
    required this.currentValue,
    required this.otherValues,
    required this.allCallValues,
    this.isMissingInCurrent = false,
  });
}

class _SiblingEndpointInfo {
  final List<ApiLogItem> siblings;
  final int currentCallIndex;
  final Set<String> diffKeys;
  final List<_ParamDiffEntry> diffEntries;
  final Map<String, String> sameParams;
  final bool hasDiffCaller;
  final bool hasDiffPhase;

  const _SiblingEndpointInfo({
    required this.siblings,
    required this.currentCallIndex,
    required this.diffKeys,
    required this.diffEntries,
    required this.sameParams,
    required this.hasDiffCaller,
    required this.hasDiffPhase,
  });

  bool get hasMultipleCallsToEndpoint => siblings.length > 1;
  bool get hasParamDiffs => diffEntries.isNotEmpty;
}

_SiblingEndpointInfo _analyzeSiblingEndpoint(ApiLogItem log) {
  final pathToCheck = _extractCleanPath(log.url);
  final allLogs = MonitorController.instance.apiLogs.isNotEmpty
      ? MonitorController.instance.apiLogs
      : MonitorController.instance.globalApiLogs;

  final siblingLogs = allLogs.where((l) {
    return l.method == log.method && _extractCleanPath(l.url) == pathToCheck;
  }).toList();

  // Sort oldest -> newest so #1 is the first call, #2 is the second call, etc.
  siblingLogs.sort((a, b) {
    final cmp = a.timestamp.compareTo(b.timestamp);
    if (cmp != 0) return cmp;
    return a.id.compareTo(b.id);
  });

  int currentIdx = siblingLogs.indexWhere((s) => s.id == log.id);
  if (currentIdx < 0) currentIdx = 0;
  final int currentCallNumber = currentIdx + 1;

  if (siblingLogs.length <= 1) {
    return _SiblingEndpointInfo(
      siblings: siblingLogs.isEmpty ? [log] : siblingLogs,
      currentCallIndex: 1,
      diffKeys: const {},
      diffEntries: const [],
      sameParams: _extractAllParamsMap(log),
      hasDiffCaller: false,
      hasDiffPhase: false,
    );
  }

  final List<Map<String, String>> siblingParamMaps =
      siblingLogs.map(_extractAllParamsMap).toList();
  final Map<String, String> currentParams = siblingParamMaps[currentIdx];

  final Set<String> allKeys = {};
  for (final m in siblingParamMaps) {
    allKeys.addAll(m.keys);
  }

  final Set<String> diffKeys = {};
  final List<_ParamDiffEntry> diffEntries = [];
  final Map<String, String> sameParams = {};

  for (final key in allKeys) {
    final Set<String> distinctVals = {};
    for (final m in siblingParamMaps) {
      distinctVals.add(m[key] ?? '<không gửi>');
    }
    if (distinctVals.length > 1) {
      diffKeys.add(key);
      final bool isMissing = !currentParams.containsKey(key);
      final String curVal = currentParams[key] ?? '<không gửi>';
      final List<({int callIndex, String value, String phase})> others = [];
      final List<({int callIndex, String value, String phase, bool isCurrent})>
          allVals = [];

      for (int i = 0; i < siblingLogs.length; i++) {
        final sib = siblingLogs[i];
        final v = siblingParamMaps[i][key] ?? '<không gửi>';
        allVals.add((
          callIndex: i + 1,
          value: v,
          phase: sib.phase,
          isCurrent: i == currentIdx,
        ));
        if (i != currentIdx && v != curVal) {
          others.add((callIndex: i + 1, value: v, phase: sib.phase));
        }
      }

      diffEntries.add(_ParamDiffEntry(
        key: key,
        currentValue: curVal,
        otherValues: others,
        allCallValues: allVals,
        isMissingInCurrent: isMissing,
      ));
    } else if (currentParams.containsKey(key)) {
      sameParams[key] = currentParams[key]!;
    }
  }

  final callers = siblingLogs
      .map((s) => s.callerName.trim())
      .where((c) => c.isNotEmpty && c != 'unknown')
      .toSet();
  final phases = siblingLogs.map((s) => s.phase).toSet();

  return _SiblingEndpointInfo(
    siblings: siblingLogs,
    currentCallIndex: currentCallNumber,
    diffKeys: diffKeys,
    diffEntries: diffEntries,
    sameParams: sameParams,
    hasDiffCaller: callers.length > 1,
    hasDiffPhase: phases.length > 1,
  );
}

Set<String> _findDiffQueryKeys(ApiLogItem log) =>
    _analyzeSiblingEndpoint(log).diffKeys;

String _truncateParamVal(String v, [int maxLen = 22]) {
  if (v.length <= maxLen) return v;
  return '${v.substring(0, maxLen)}…';
}

Widget? _buildPayloadRow(BuildContext context, ApiLogItem log) {
  final info = _analyzeSiblingEndpoint(log);
  final allParams = _extractAllParamsMap(log);
  final isDark = MonitorColors.isDark;
  final diffColor =
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  final warnColor =
      isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  final keyColor =
      isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1);
  final valColor = MonitorColors.primaryText.withValues(alpha: 0.9);

  // Case 1: Duplicate endpoint on the same screen WITH request parameter diffs!
  if (info.hasMultipleCallsToEndpoint && info.hasParamDiffs) {
    final List<InlineSpan> spans = [];
    final visibleDiffs = info.diffEntries.take(3).toList();
    final remainingDiffs = info.diffEntries.length - visibleDiffs.length;

    for (int i = 0; i < visibleDiffs.length; i++) {
      final d = visibleDiffs[i];
      final curStr = _truncateParamVal(d.currentValue, 20);
      final otherSummary = d.otherValues.isNotEmpty
          ? d.otherValues
              .take(2)
              .map((o) => '#${o.callIndex}: ${_truncateParamVal(o.value, 14)}')
              .join(', ')
          : '';

      spans.add(TextSpan(
        text: '${d.key}: ',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9.0,
          color: diffColor,
          fontWeight: FontWeight.w700,
        ),
      ));
      spans.add(TextSpan(
        text: curStr,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9.0,
          color: d.isMissingInCurrent ? warnColor : diffColor,
          fontWeight: FontWeight.w800,
        ),
      ));
      if (otherSummary.isNotEmpty) {
        spans.add(TextSpan(
          text: ' ($otherSummary)',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 8.3,
            color: MonitorColors.secondaryText.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ));
      }
      if (i < visibleDiffs.length - 1 ||
          remainingDiffs > 0 ||
          info.sameParams.isNotEmpty) {
        spans.add(TextSpan(
          text: '  ·  ',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9.0,
            color: MonitorColors.secondaryText.withValues(alpha: 0.45),
          ),
        ));
      }
    }
    if (remainingDiffs > 0) {
      spans.add(TextSpan(
        text: '+$remainingDiffs khác',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 8.5,
          color: diffColor,
          fontWeight: FontWeight.w700,
        ),
      ));
      if (info.sameParams.isNotEmpty) {
        spans.add(TextSpan(
          text: '  ·  ',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9.0,
            color: MonitorColors.secondaryText.withValues(alpha: 0.45),
          ),
        ));
      }
    }

    // Append unchanged params inline in subtle text so user sees full context calmly
    final sameEntries = info.sameParams.entries.take(2).toList();
    for (int i = 0; i < sameEntries.length; i++) {
      final e = sameEntries[i];
      spans.add(TextSpan(
        text: '${e.key}: ${_truncateParamVal(e.value, 14)}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 8.5,
          color: MonitorColors.secondaryText.withValues(alpha: 0.70),
          fontWeight: FontWeight.w500,
        ),
      ));
      if (i < sameEntries.length - 1) {
        spans.add(TextSpan(
          text: ' · ',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 8.5,
            color: MonitorColors.secondaryText.withValues(alpha: 0.40),
          ),
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: diffColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: diffColor.withValues(alpha: 0.25),
          width: 0.6,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.8),
            margin: const EdgeInsets.only(top: 0.5, right: 5),
            decoration: BoxDecoration(
              color: diffColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(3),
            ),
            child: MonoText(
              'Khác ${info.diffEntries.length}',
              7.5,
              color: diffColor,
              weight: FontWeight.w800,
            ),
          ),
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(children: spans),
            ),
          ),
        ],
      ),
    );
  }

  // Case 2 & 3: Single call OR Duplicate endpoint with identical params (subtle, non-intrusive)
  if (allParams.isNotEmpty || info.hasMultipleCallsToEndpoint) {
    final entries = allParams.entries.toList();
    final maxPreview = 4;
    final visibleEntries = entries.take(maxPreview).toList();
    final remaining = entries.length - visibleEntries.length;

    final otherIndices = <int>[];
    if (info.hasMultipleCallsToEndpoint) {
      for (int i = 0; i < info.siblings.length; i++) {
        if (i + 1 != info.currentCallIndex) otherIndices.add(i + 1);
      }
    }
    final sameTag = otherIndices.isNotEmpty
        ? 'Giống #${otherIndices.first}'
        : '';

    final List<InlineSpan> spans = [];
    if ( visibleEntries.isEmpty && sameTag.isNotEmpty) {
      spans.add(TextSpan(
        text: 'Không có params',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 8.5,
          color: MonitorColors.secondaryText.withValues(alpha: 0.65),
        ),
      ));
    }
    for (int i = 0; i < visibleEntries.length; i++) {
      final entry = visibleEntries[i];
      final valStr = _truncateParamVal(entry.value, 24);

      spans.add(TextSpan(
        text: '${entry.key}: ',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9.0,
          color: keyColor,
          fontWeight: FontWeight.w700,
        ),
      ));
      spans.add(TextSpan(
        text: valStr,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9.0,
          color: valColor,
          fontWeight: FontWeight.w600,
        ),
      ));

      if (i < visibleEntries.length - 1 || remaining > 0) {
        spans.add(TextSpan(
          text: '  ·  ',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9.0,
            color: MonitorColors.secondaryText.withValues(alpha: 0.45),
          ),
        ));
      }
    }

    if (remaining > 0) {
      spans.add(TextSpan(
        text: '+$remaining',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 8.5,
          color: MonitorColors.metricTotal,
          fontWeight: FontWeight.w700,
        ),
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: MonitorColors.expandedDetailBg.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: MonitorColors.border.withValues(alpha: 0.6),
          width: 0.6,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (sameTag.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.8),
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                color: MonitorColors.secondaryText.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: MonoText(
                sameTag,
                7.5,
                color: MonitorColors.secondaryText,
                weight: FontWeight.w700,
              ),
            ),
          ] else ...[
            Icon(
              Icons.tune_rounded,
              size: 10,
              color: MonitorColors.secondaryText.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
  final allParams = _extractAllParamsMap(log);
  if (allParams.isNotEmpty) {
    final diffKeys = _findDiffQueryKeys(log);
    final entries = allParams.entries.toList();
    entries.sort((a, b) {
      final aDiff = diffKeys.contains(a.key) ? 0 : 1;
      final bDiff = diffKeys.contains(b.key) ? 0 : 1;
      return aDiff.compareTo(bDiff);
    });

    final isDark = MonitorColors.isDark;
    final diffColor =
        isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    final keyColor =
        isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1);

    final visible = entries.take(3).toList();
    final List<InlineSpan> spans = [];
    for (int i = 0; i < visible.length; i++) {
      final entry = visible[i];
      final isDiff = diffKeys.contains(entry.key);
      spans.add(TextSpan(
        text: '${isDiff ? "⚡" : ""}${entry.key}=${entry.value}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 8.5,
          color: isDiff ? diffColor : keyColor,
          fontWeight: isDiff ? FontWeight.bold : FontWeight.w600,
        ),
      ));
      if (i < visible.length - 1) {
        spans.add(TextSpan(
          text: ' · ',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 8.5,
            color: MonitorColors.secondaryText.withValues(alpha: 0.4),
          ),
        ));
      }
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }

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
  void didUpdateWidget(covariant ApiLogTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.log.id != widget.log.id) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final statusColor = _statusColor(log);
    final laneColor =
        widget.lane != null ? _palette[widget.lane! % _palette.length] : null;

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
                  ? MonitorColors.statusSlow
                      .withValues(alpha: widget.compact ? 0.35 : 0.4)
                  : (log.isSuccess
                      ? MonitorColors.border
                          .withValues(alpha: widget.compact ? 0.45 : 1.0)
                      : MonitorColors.statusError.withValues(alpha: 0.35))),
          width: isExpanded
              ? (widget.compact ? 1.0 : 1.2)
              : (widget.compact ? 0.6 : 1.0),
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: MonitorColors.isDark ? 0.40 : 0.08),
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
              if (!widget.compact)
                Container(
                  width: isExpanded ? 4.5 : 3.5,
                  color: laneColor ??
                      (!log.isSuccess
                          ? MonitorColors.statusError
                          : (log.isSlow
                              ? MonitorColors.statusSlow
                              : (log.phase == 'OPEN'
                                  ? MonitorColors.metricInit
                                      .withValues(alpha: 0.75)
                                  : MonitorColors.metricRefresh
                                      .withValues(alpha: 0.75)))),
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

  static Widget _buildHighlightedUrl(String url, bool expanded) {
    final clean = url.trim();
    final segments = clean.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length <= 2) {
      return MonoText(
        clean,
        11.5,
        color: MonitorColors.primaryText,
        weight: FontWeight.w700,
        maxLines: expanded ? null : 2,
        overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
      );
    }

    final prefixSegments = segments.sublist(0, segments.length - 2);
    final endpointSegments = segments.sublist(segments.length - 2);
    final prefix = '/${prefixSegments.join('/')}/';
    final endpoint = endpointSegments.join('/');

    return RichText(
      maxLines: expanded ? null : 2,
      overflow: expanded ? TextOverflow.clip : TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontFamily: 'monospace', height: 1.25),
        children: [
          TextSpan(
            text: prefix,
            style: TextStyle(
              fontSize: 10.0,
              color: MonitorColors.secondaryText.withValues(alpha: 0.65),
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: endpoint,
            style: TextStyle(
              fontSize: 11.5,
              color: MonitorColors.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final siblingInfo = _analyzeSiblingEndpoint(log);
    final payloadRow = _buildPayloadRow(context, log);
    // Shorten URL path (clean endpoint path without query string)
    String displayUrl = log.url;
    if (!showFullUrl) {
      displayUrl = _extractCleanPath(log.url);
    }

    final ts = log.timestamp;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
    final isInitPhase = log.phase == 'OPEN';
    final phaseColor =
        isInitPhase ? MonitorColors.metricInit : MonitorColors.metricRefresh;
    final statusText = log.statusCode > 0 ? '${log.statusCode}' : 'ERR';

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
            // Row 1: Primary API signature (Method + Status + Sibling/Call Count + URL path + Duration)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: _MethodBadge(method: log.method),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.32),
                        width: 0.5,
                      ),
                    ),
                    child: MonoText(
                      statusText,
                      9,
                      color: statusColor,
                      weight: FontWeight.bold,
                    ),
                  ),
                ),
                if (siblingInfo.hasMultipleCallsToEndpoint) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: _SiblingCallBadge(
                      currentIndex: siblingInfo.currentCallIndex,
                      totalCount: siblingInfo.siblings.length,
                      hasDiff: siblingInfo.hasParamDiffs,
                    ),
                  ),
                ] else if (log.hasMultipleCalls) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: _CallCountBadge(count: log.callCount),
                  ),
                ],
                const SizedBox(width: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: _buildHighlightedUrl(displayUrl, expanded),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 1.5),
                  child: _DurationLabel(
                      duration: log.duration,
                      isSlow: log.isSlow,
                      color: statusColor),
                ),
                const SizedBox(width: 5),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    Navigator.of(context).push(
                      MonitorResponsiveRoute(
                        builder: (_) => MonitorApiDetailPage(log: log),
                        settings: const RouteSettings(
                            name: MonitorConstants.apiDetailPage),
                      ),
                    );
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: MonitorColors.expandedDetailBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: MonitorColors.border,
                        width: 0.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.open_in_new_rounded,
                      color: MonitorColors.secondaryText,
                      size: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(top: 3.5),
                  child: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: MonitorColors.secondaryText,
                    size: 15,
                  ),
                ),
              ],
            ),
            if (payloadRow != null) ...[
              const SizedBox(height: 4),
              payloadRow,
            ],
            // Row 2: Phase + Screen + Size + Caller + Timestamp metadata
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4.5, vertical: 1),
                  decoration: BoxDecoration(
                    color: phaseColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(3.5),
                  ),
                  child: LabelText(
                    isInitPhase
                        ? LocaleKeys.initLabel.tr
                        : (log.refreshCycle > 0
                            ? '${LocaleKeys.actionLabel.tr} #${log.refreshCycle}'
                            : LocaleKeys.actionLabel.tr),
                    phaseColor,
                    size: 7.5,
                    spacing: 0.3,
                  ),
                ),
                if (showScreenBadge) ...[
                  const SizedBox(width: 5),
                  _ScreenBadge(screen: log.screen, lane: lane),
                ],
                if (log.hasResponseSize) ...[
                  const SizedBox(width: 6),
                  MonoText(
                    log.responseSizeFormatted,
                    8.5,
                    color: MonitorColors.secondaryText.withValues(alpha: 0.85),
                    weight: FontWeight.w600,
                  ),
                ],
                if (log.hasCallerName) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: _CallerRow(
                      callerName: log.callerName,
                      color: MonitorColors.secondaryText.withValues(alpha: 0.8),
                    ),
                  ),
                ] else
                  const Spacer(),
                const SizedBox(width: 6),
                MonoText(
                  timeStr,
                  8.5,
                  color: MonitorColors.secondaryText.withValues(alpha: 0.65),
                ),
              ],
            ),
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
    final methodColor = MonitorColors.methodColor(log.method);

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
                        settings: const RouteSettings(
                            name: MonitorConstants.apiDetailPage),
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
    final badgeColor = lane != null
        ? _palette[lane! % _palette.length]
        : const Color(0xFFA78BFA);

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
  late int _tab;

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    final hasResBody = log.responseBody != null && log.responseBody!.isNotEmpty;
    final hasReqPayload =
        (log.requestBody != null && log.requestBody!.isNotEmpty) ||
            _extractEffectiveQueryParams(log).isNotEmpty;
    // Open RESPONSE tab by default when response body exists (since QuickParamsStrip
    // shows request params right above the response!). Otherwise open REQUEST if present.
    _tab = (hasResBody || !log.isSuccess || !hasReqPayload) ? 1 : 0;
  }

  List<String> _buildTabLabels(ApiLogItem log) {
    final paramCount = _extractAllParamsMap(log).length;
    final hdrCount = log.requestHeaders.length + log.responseHeaders.length;
    return [
      paramCount > 0 ? 'REQUEST ($paramCount)' : 'REQUEST',
      'RESPONSE',
      'TIMELINE',
      hdrCount > 0 ? 'HEADERS ($hdrCount)' : 'HEADERS',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final tabLabels = _buildTabLabels(log);
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
                  tabs: tabLabels,
                  active: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
              ),
              // Vertical divider
              Container(
                width: 1,
                height: 32,
                color: MonitorColors.border,
              ),
              // Copy-all button
              InkWell(
                onTap: () => _showCopySheet(context, log),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  height: 32,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_all_rounded,
                        size: 14,
                        color: MonitorColors.secondaryText,
                      ),
                      const SizedBox(width: 3),
                      BodyText(
                        'Copy',
                        8.5,
                        color: MonitorColors.secondaryText,
                        weight: FontWeight.w600,
                      ),
                    ],
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
      routeSettings:
          const RouteSettings(name: MonitorConstants.copyActionsSheet),
      builder: (_) => _CopyActionsSheet(log: log),
    );
  }

  Widget _buildContent(ApiLogItem log) {
    switch (_tab) {
      case 0:
        return _RequestContent(log: log);
      case 1:
        return _ResponseContent(
          log: log,
          onSwitchToRequestTab: () => setState(() => _tab = 0),
        );
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
    final curl = _buildCurl(log);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: MonitorColors.expandedDetailBg,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          _CurlCopyButton(curl: curl),
          const SizedBox(width: 8),
          if (log.hasCallerName)
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.call_made,
                      size: 10,
                      color:
                          MonitorColors.secondaryText.withValues(alpha: 0.7)),
                  const SizedBox(width: 3),
                  Expanded(
                    child: MonoText(
                      log.callerName,
                      9.0,
                      color: MonitorColors.secondaryText.withValues(alpha: 0.8),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 6),
          // Fullscreen Detail button
          InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: () {
              Navigator.of(context).push(
                MonitorResponsiveRoute(
                  builder: (_) => MonitorApiDetailPage(log: log),
                  settings:
                      const RouteSettings(name: MonitorConstants.apiDetailPage),
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
                  Icon(Icons.open_in_new_rounded,
                      size: 11, color: MonitorColors.primaryText),
                  const SizedBox(width: 4),
                  BodyText('Detail', 9.5,
                      color: MonitorColors.primaryText,
                      weight: FontWeight.w500),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
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
                    Icon(Icons.keyboard_arrow_up_rounded,
                        size: 13, color: MonitorColors.metricTotal),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < tabs.length; i++)
              GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
                  decoration: BoxDecoration(
                    color: active == i
                        ? MonitorColors.metricTotal.withValues(alpha: 0.08)
                        : Colors.transparent,
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
                      ? LabelText(tabs[i], MonitorColors.metricTotal, size: 8.5)
                      : BodyText(tabs[i], 8.5,
                          color: MonitorColors.secondaryText,
                          weight: FontWeight.w600),
                ),
              ),
          ],
        ),
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
          LabelText('EXECUTION TIMELINE', MonitorColors.secondaryText,
              size: 9, spacing: 0.8),
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

// ─── Quick Params Strip (shown above Response so params are always visible) ──

class _QuickParamsStrip extends StatefulWidget {
  final ApiLogItem log;
  final VoidCallback? onOpenRequestTab;

  const _QuickParamsStrip({
    required this.log,
    this.onOpenRequestTab,
  });

  @override
  State<_QuickParamsStrip> createState() => _QuickParamsStripState();
}

class _QuickParamsStripState extends State<_QuickParamsStrip> {
  bool _tableMode = false;
  bool _showAllChips = false;

  @override
  Widget build(BuildContext context) {
    final siblingInfo = _analyzeSiblingEndpoint(widget.log);
    final queryParams = _extractEffectiveQueryParams(widget.log);
    final bodyParams = _extractBodyMapParams(widget.log);
    final allParams = <String, String>{...queryParams, ...bodyParams};
    if (allParams.isEmpty && !siblingInfo.hasMultipleCallsToEndpoint) {
      return const SizedBox.shrink();
    }

    final diffKeys = siblingInfo.diffKeys;
    final entries = allParams.entries.toList();
    entries.sort((a, b) {
      final aDiff = diffKeys.contains(a.key) ? 0 : 1;
      final bDiff = diffKeys.contains(b.key) ? 0 : 1;
      return aDiff.compareTo(bDiff);
    });

    final isDark = MonitorColors.isDark;
    final diffColor =
        isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    final hasDiff = diffKeys.isNotEmpty;
    final copyFormatted =
        entries.map((e) => '${e.key}: ${e.value}').join('\n');

    final int maxInitialChips = 6;
    final bool hasMoreChips = entries.length > maxInitialChips;
    final visibleChipEntries = (!_showAllChips && hasMoreChips)
        ? entries.take(maxInitialChips).toList()
        : entries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (siblingInfo.hasMultipleCallsToEndpoint &&
            siblingInfo.hasParamDiffs)
          _SiblingRequestComparisonCard(info: siblingInfo),
        if (allParams.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: MonitorColors.surface,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: hasDiff
                    ? diffColor.withValues(alpha: 0.35)
                    : MonitorColors.border.withValues(alpha: 0.85),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 11,
                      color: hasDiff ? diffColor : MonitorColors.metricTotal,
                    ),
                    const SizedBox(width: 4),
                    LabelText(
                      'PARAMS (${entries.length})',
                      hasDiff ? diffColor : MonitorColors.metricTotal,
                      size: 8.5,
                      spacing: 0.5,
                    ),
                    if (queryParams.isNotEmpty && bodyParams.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      MonoText(
                        '${queryParams.length} query · ${bodyParams.length} body',
                        8.0,
                        color: MonitorColors.secondaryText,
                      ),
                    ] else if (bodyParams.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      MonoText(
                        'JSON body',
                        8.0,
                        color: MonitorColors.secondaryText,
                      ),
                    ],
                    if (hasDiff) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: diffColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: MonoText(
                          '⚡ ${diffKeys.length} khác',
                          7.5,
                          color: diffColor,
                          weight: FontWeight.bold,
                        ),
                      ),
                    ] else if (siblingInfo.hasMultipleCallsToEndpoint) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: MonitorColors.secondaryText
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: MonoText(
                          'Lần #${siblingInfo.currentCallIndex}/${siblingInfo.siblings.length} · Giống nhau',
                          7.5,
                          color: MonitorColors.secondaryText,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Toggle Chips vs Table view
                    GestureDetector(
                      onTap: () => setState(() => _tableMode = !_tableMode),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _tableMode
                              ? MonitorColors.metricTotal
                                  .withValues(alpha: 0.12)
                              : MonitorColors.expandedDetailBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _tableMode
                                ? MonitorColors.metricTotal
                                    .withValues(alpha: 0.4)
                                : MonitorColors.border,
                            width: 0.6,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _tableMode
                                  ? Icons.table_rows_rounded
                                  : Icons.grid_view_rounded,
                              size: 9.5,
                              color: _tableMode
                                  ? MonitorColors.metricTotal
                                  : MonitorColors.secondaryText,
                            ),
                            const SizedBox(width: 3),
                            MonoText(
                              _tableMode ? 'Bảng' : 'Chips',
                              7.5,
                              color: _tableMode
                                  ? MonitorColors.metricTotal
                                  : MonitorColors.secondaryText,
                              weight: FontWeight.bold,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    _InlineCopyBtn(text: copyFormatted),
                  ],
                ),
                const SizedBox(height: 6),
                if (_tableMode)
                  _KVTable(entries: entries, diffKeys: diffKeys)
                else
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final entry in visibleChipEntries)
                        _ParamChipItem(
                          paramKey: entry.key,
                          paramValue: entry.value,
                          isDiff: diffKeys.contains(entry.key),
                        ),
                      if (hasMoreChips)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showAllChips = !_showAllChips),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: MonitorColors.metricTotal
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: MonitorColors.metricTotal
                                    .withValues(alpha: 0.3),
                                width: 0.6,
                              ),
                            ),
                            child: MonoText(
                              _showAllChips
                                  ? 'Thu gọn'
                                  : '+${entries.length - maxInitialChips} xem thêm',
                              8.5,
                              color: MonitorColors.metricTotal,
                              weight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ParamChipItem extends StatefulWidget {
  final String paramKey;
  final String paramValue;
  final bool isDiff;

  const _ParamChipItem({
    required this.paramKey,
    required this.paramValue,
    this.isDiff = false,
  });

  @override
  State<_ParamChipItem> createState() => _ParamChipItemState();
}

class _ParamChipItemState extends State<_ParamChipItem> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(
        ClipboardData(text: '${widget.paramKey}=${widget.paramValue}'));
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MonitorColors.isDark;
    final diffColor =
        isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    final keyColor =
        isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1);

    String displayVal = widget.paramValue;
    if (displayVal.length > 36) {
      displayVal = '${displayVal.substring(0, 36)}…';
    }

    return GestureDetector(
      onTap: _copy,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _copied
              ? MonitorColors.statusSuccess.withValues(alpha: 0.14)
              : (widget.isDiff
                  ? diffColor.withValues(alpha: 0.10)
                  : MonitorColors.expandedDetailBg),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _copied
                ? MonitorColors.statusSuccess.withValues(alpha: 0.45)
                : (widget.isDiff
                    ? diffColor.withValues(alpha: 0.38)
                    : MonitorColors.border.withValues(alpha: 0.8)),
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_copied) ...[
              Icon(Icons.check_rounded,
                  size: 10, color: MonitorColors.statusSuccess),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 9.0),
                  children: [
                    TextSpan(
                      text:
                          '${widget.isDiff ? "⚡" : ""}${widget.paramKey}: ',
                      style: TextStyle(
                        color: _copied
                            ? MonitorColors.statusSuccess
                            : (widget.isDiff ? diffColor : keyColor),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: displayVal,
                      style: TextStyle(
                        color: _copied
                            ? MonitorColors.statusSuccess
                            : (widget.isDiff
                                ? diffColor
                                : MonitorColors.primaryText),
                        fontWeight:
                            widget.isDiff ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiblingCallBadge extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final bool hasDiff;

  const _SiblingCallBadge({
    required this.currentIndex,
    required this.totalCount,
    required this.hasDiff,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MonitorColors.isDark;
    final color = hasDiff
        ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
        : MonitorColors.secondaryText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: hasDiff ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: hasDiff ? 0.40 : 0.25),
          width: 0.6,
        ),
      ),
      child: MonoText(
        '#$currentIndex/$totalCount',
        8.5,
        color: color,
        weight: hasDiff ? FontWeight.w800 : FontWeight.w700,
      ),
    );
  }
}

class _SiblingRequestComparisonCard extends StatelessWidget {
  final _SiblingEndpointInfo info;

  const _SiblingRequestComparisonCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final isDark = MonitorColors.isDark;
    final diffColor =
        isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    final neutralColor = MonitorColors.secondaryText;
    final accentColor = info.hasParamDiffs ? diffColor : neutralColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: info.hasParamDiffs
            ? diffColor.withValues(alpha: 0.07)
            : MonitorColors.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: info.hasParamDiffs
              ? diffColor.withValues(alpha: 0.35)
              : MonitorColors.border.withValues(alpha: 0.8),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                info.hasParamDiffs
                    ? Icons.compare_arrows_rounded
                    : Icons.history_rounded,
                size: 12,
                color: accentColor,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: LabelText(
                  info.hasParamDiffs
                      ? 'SO SÁNH REQUEST (${info.siblings.length} LẦN GỌI · KHÁC ${info.diffEntries.length} PARAM)'
                      : 'LỊCH SỬ GỌI TRONG MÀN (${info.siblings.length} LẦN · CÙNG PARAMS)',
                  accentColor,
                  size: 8.2,
                  spacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Call timeline chips (#1, #2, ...)
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              for (int i = 0; i < info.siblings.length; i++)
                _buildCallChip(info.siblings[i], i + 1,
                    isCurrent: (i + 1) == info.currentCallIndex,
                    accentColor: info.hasParamDiffs
                        ? diffColor
                        : MonitorColors.metricTotal),
            ],
          ),
          if (info.hasParamDiffs) ...[
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: MonitorColors.surface,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.28),
                  width: 0.6,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < info.diffEntries.length; i++) ...[
                    if (i > 0)
                      Container(
                        height: 0.5,
                        color: MonitorColors.border.withValues(alpha: 0.6),
                      ),
                    _DiffMatrixRow(entry: info.diffEntries[i]),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCallChip(
    ApiLogItem item,
    int idx, {
    required bool isCurrent,
    required Color accentColor,
  }) {
    final ts = item.timestamp;
    final tStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
    final phaseLabel = item.phase == 'OPEN'
        ? 'LOAD'
        : (item.refreshCycle > 0
            ? 'INTERACTION #${item.refreshCycle}'
            : 'INTERACTION');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: isCurrent
            ? accentColor.withValues(alpha: 0.18)
            : MonitorColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isCurrent
              ? accentColor.withValues(alpha: 0.65)
              : MonitorColors.border,
          width: isCurrent ? 1.0 : 0.6,
        ),
      ),
      child: MonoText(
        isCurrent
            ? '● Lần #$idx (Đang xem · $phaseLabel · $tStr)'
            : 'Lần #$idx ($phaseLabel · $tStr)',
        8.0,
        color: isCurrent ? accentColor : MonitorColors.secondaryText,
        weight: isCurrent ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}

class _DiffMatrixRow extends StatelessWidget {
  final _ParamDiffEntry entry;

  const _DiffMatrixRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = MonitorColors.isDark;
    final diffColor =
        isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: MonoText(
              '⚡ ${entry.key}',
              9.0,
              color: diffColor,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final callVal in entry.allCallValues)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: callVal.isCurrent
                          ? diffColor.withValues(alpha: 0.16)
                          : MonitorColors.expandedDetailBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: callVal.isCurrent
                            ? diffColor.withValues(alpha: 0.55)
                            : MonitorColors.border.withValues(alpha: 0.7),
                        width: callVal.isCurrent ? 0.9 : 0.5,
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 8.6),
                        children: [
                          TextSpan(
                            text: '#${callVal.callIndex}: ',
                            style: TextStyle(
                              color: callVal.isCurrent
                                  ? diffColor
                                  : MonitorColors.secondaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: callVal.value,
                            style: TextStyle(
                              color: callVal.isCurrent
                                  ? diffColor
                                  : MonitorColors.primaryText,
                              fontWeight: callVal.isCurrent
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Request content ──────────────────────────────────────────────────────────

class _RequestContent extends StatelessWidget {
  final ApiLogItem log;
  final bool isFullPage;
  const _RequestContent({required this.log, this.isFullPage = false});

  @override
  Widget build(BuildContext context) {
    final siblingInfo = _analyzeSiblingEndpoint(log);
    final effectiveQuery = _extractEffectiveQueryParams(log);
    final bodyMapParams = _extractBodyMapParams(log);
    final diffKeys = siblingInfo.diffKeys;
    final hasQuery = effectiveQuery.isNotEmpty;
    final hasBody = log.requestBody != null && log.requestBody!.isNotEmpty;
    final curl = _buildCurl(log);

    final topContent = [
      if (siblingInfo.hasMultipleCallsToEndpoint)
        _SiblingRequestComparisonCard(info: siblingInfo),
      // URL row: label + copy url + copy cURL
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SectionLabel('ENDPOINT URL'),
          const Spacer(),
          _InlineCopyBtn(text: log.url),
          const SizedBox(width: 6),
          _CurlCopyButton(curl: curl),
        ],
      ),
      const SizedBox(height: 5),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: MonitorColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: MonitorColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MethodBadge(method: log.method),
            const SizedBox(width: 8),
            Expanded(
              child: SelectionArea(
                child: MonoText(log.url, 10.5,
                    color: MonitorColors.primaryText, height: 1.35),
              ),
            ),
          ],
        ),
      ),
      if (hasQuery) ...[
        const SizedBox(height: 10),
        _SectionRow(
            label: 'QUERY PARAMS (${effectiveQuery.length})',
            copyText: _fmtParams(effectiveQuery)),
        const SizedBox(height: 5),
        _KVTable(
          entries: effectiveQuery.entries.toList(),
          diffKeys: diffKeys,
        ),
      ],
      if (bodyMapParams.isNotEmpty) ...[
        const SizedBox(height: 10),
        _SectionRow(
          label: 'BODY PARAMS (${bodyMapParams.length})',
          copyText: bodyMapParams.entries
              .map((e) => '${e.key}: ${e.value}')
              .join('\n'),
        ),
        const SizedBox(height: 5),
        _KVTable(
          entries: bodyMapParams.entries.toList(),
          diffKeys: diffKeys,
        ),
      ],
    ];

    if (!isFullPage) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...topContent,
            if (hasBody) ...[
              const SizedBox(height: 10),
              _SectionLabel('RAW BODY'),
              const SizedBox(height: 5),
              _BodyBlock(text: log.requestBody!),
            ],
            if (!hasQuery && !hasBody) ...[
              const SizedBox(height: 8),
              BodyText('No query params or request body.', 11,
                  color: MonitorColors.secondaryText),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...topContent,
          if (hasBody) ...[
            const SizedBox(height: 10),
            _SectionLabel('RAW BODY'),
            const SizedBox(height: 5),
            Expanded(
              child: _BodyBlock(
                text: log.requestBody!,
                fillHeight: true,
              ),
            ),
          ],
          if (!hasQuery && !hasBody) ...[
            const SizedBox(height: 8),
            BodyText('No query params or request body.', 11,
                color: MonitorColors.secondaryText),
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
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
            BodyText(_copied ? 'Copied!' : 'cURL', 9,
                color: _copied
                    ? MonitorColors.statusSuccess
                    : MonitorColors.metricTotal,
                weight: FontWeight.bold),
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
  final VoidCallback? onSwitchToRequestTab;

  const _ResponseContent({
    required this.log,
    this.isFullPage = false,
    this.onSwitchToRequestTab,
  });

  @override
  Widget build(BuildContext context) {
    final hasBody = log.responseBody != null && log.responseBody!.isNotEmpty;
    final hasParams = _extractAllParamsMap(log).isNotEmpty;

    if (isFullPage) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasParams)
              _QuickParamsStrip(
                log: log,
                onOpenRequestTab: onSwitchToRequestTab,
              ),
            if (hasBody)
              Expanded(
                child: _BodyBlock(
                  text: log.responseBody!,
                  fillHeight: true,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(8),
                child: BodyText('No response body.', 11,
                    color: MonitorColors.secondaryText),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasParams)
            _QuickParamsStrip(
              log: log,
              onOpenRequestTab: onSwitchToRequestTab,
            ),
          if (hasBody)
            _BodyBlock(text: log.responseBody!)
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: BodyText('No response body.', 11,
                  color: MonitorColors.secondaryText),
            ),
        ],
      ),
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
        child: BodyText('No headers captured.', 11,
            color: MonitorColors.secondaryText),
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
          preview: log.requestBody!
              .replaceAll('\n', ' ')
              .substring(0, log.requestBody!.length.clamp(0, 60)),
          text: log.requestBody!,
        ),
      if (log.responseBody != null && log.responseBody!.isNotEmpty)
        _CopyAction(
          key: 'res_body',
          icon: Icons.download_rounded,
          label: 'Response Body',
          preview: log.responseBody!
              .replaceAll('\n', ' ')
              .substring(0, log.responseBody!.length.clamp(0, 60)),
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

    return MonitorThemeScope(
      child: Container(
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
                    child: MonoText('${log.method} ${log.statusCode}', 10,
                        color: log.isSuccess
                            ? MonitorColors.statusSuccess
                            : MonitorColors.statusError,
                        weight: FontWeight.bold),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: MonitorColors.expandedDetailBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: MonitorColors.border),
                        ),
                        child: Icon(action.icon,
                            size: 15, color: MonitorColors.secondaryText),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BodyText(action.label, 13, weight: FontWeight.w600),
                            const SizedBox(height: 2),
                            MonoText(action.preview, 10,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
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
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
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
  final Set<String> diffKeys;
  const _KVTable({
    required this.entries,
    this.diffKeys = const {},
  });

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
            _KVTableRow(
              entry: entries[i],
              isDiff: diffKeys.contains(entries[i].key),
            ),
          ],
        ],
      ),
    );
  }
}

class _KVTableRow extends StatefulWidget {
  final MapEntry<String, String> entry;
  final bool isDiff;

  const _KVTableRow({
    required this.entry,
    this.isDiff = false,
  });

  @override
  State<_KVTableRow> createState() => _KVTableRowState();
}

class _KVTableRowState extends State<_KVTableRow> {
  bool _copied = false;

  Future<void> _copyValue() async {
    await Clipboard.setData(ClipboardData(text: widget.entry.value));
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MonitorColors.isDark;
    final diffColor =
        isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);

    return InkWell(
      onTap: _copyValue,
      child: Container(
        color: widget.isDiff
            ? diffColor.withValues(alpha: 0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isDiff)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: MonoText('⚡', 9.5,
                          color: diffColor, weight: FontWeight.bold),
                    ),
                  Expanded(
                    child: MonoText(
                      widget.entry.key,
                      10,
                      color:
                          widget.isDiff ? diffColor : MonitorColors.callerName,
                      weight:
                          widget.isDiff ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectionArea(
                child: MonoText(
                  widget.entry.value,
                  10,
                  color: widget.isDiff ? diffColor : MonitorColors.primaryText,
                  weight: widget.isDiff ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 11,
                color: _copied
                    ? MonitorColors.statusSuccess
                    : MonitorColors.secondaryText.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
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
  static final RegExp _jsonTokenRegExp = RegExp(
    r'("(?:\\.|[^"\\])*")(\s*:)|("(?:\\.|[^"\\])*")|\b(true|false|null)\b|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)',
  );

  bool _prettyJson = true;
  bool _wordWrap = false;
  bool _searchMode = false;
  bool _tallBox = false;
  String _searchQuery = '';
  late final ScrollController _scrollController;
  late final ScrollController _horizontalScrollController;

  late String _formattedText;
  late List<String> _lines;
  int _maxLineChars = 0;
  final List<int> _matchingLineIndices = [];
  int _currentMatchIndex = 0;

  bool _isAtTop = true;
  bool _isAtBottom = false;
  int _currentTopLine = 1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScrollChanged);
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
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final offset = pos.pixels;
    final maxExt = pos.maxScrollExtent;
    final atTop = offset <= 4.0;
    final atBottom = maxExt > 0 && offset >= (maxExt - 6.0);
    final estLine =
        ((offset / 18.5).floor() + 1).clamp(1, _lines.length.clamp(1, 999999));

    if (atTop != _isAtTop ||
        atBottom != _isAtBottom ||
        (estLine - _currentTopLine).abs() >= 2) {
      setState(() {
        _isAtTop = atTop;
        _isAtBottom = atBottom;
        _currentTopLine = atBottom ? _lines.length : estLine;
      });
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    if (_horizontalScrollController.hasClients) {
      _horizontalScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    }
    if (mounted) {
      setState(() {
        _isAtTop = true;
        _isAtBottom = false;
        _currentTopLine = 1;
      });
    }
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
    // Ensure exact bottom landing even when wordWrap dynamically measures lines
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final finalExtent = _scrollController.position.maxScrollExtent;
      if ((_scrollController.offset - finalExtent).abs() > 2.0) {
        _scrollController.jumpTo(finalExtent);
      }
      setState(() {
        _isAtTop = false;
        _isAtBottom = true;
        _currentTopLine = _lines.length;
      });
    });
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
    int maxChars = 0;
    for (final line in _lines) {
      if (line.length > maxChars) maxChars = line.length;
    }
    _maxLineChars = maxChars;
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
    if (_matchingLineIndices.isEmpty ||
        matchIndex >= _matchingLineIndices.length) {
      return;
    }
    final lineIdx = _matchingLineIndices[matchIndex];
    const double lineH = 18.5;
    final targetY = (lineIdx * lineH) - 60.0;
    if (_scrollController.hasClients) {
      final clamped =
          targetY.clamp(0.0, _scrollController.position.maxScrollExtent);
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
      _currentMatchIndex =
          (_currentMatchIndex + 1) % _matchingLineIndices.length;
      _scrollToMatch(_currentMatchIndex);
    });
  }

  void _prevMatch() {
    if (_matchingLineIndices.isEmpty) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _matchingLineIndices.length) %
              _matchingLineIndices.length;
      _scrollToMatch(_currentMatchIndex);
    });
  }

  void _appendSearchHighlightedSegment(
    List<InlineSpan> out,
    String segment,
    String lowerQuery,
    TextStyle style,
  ) {
    if (segment.isEmpty) return;
    if (lowerQuery.isEmpty) {
      out.add(TextSpan(text: segment, style: style));
      return;
    }

    final lowerSeg = segment.toLowerCase();
    int start = 0;
    while (true) {
      final index = lowerSeg.indexOf(lowerQuery, start);
      if (index == -1) {
        out.add(TextSpan(text: segment.substring(start), style: style));
        break;
      }
      if (index > start) {
        out.add(TextSpan(text: segment.substring(start, index), style: style));
      }
      out.add(TextSpan(
        text: segment.substring(index, index + lowerQuery.length),
        style: style.copyWith(
          backgroundColor: Colors.orange.withValues(alpha: 0.85),
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = index + lowerQuery.length;
    }
  }

  TextSpan _buildHighlightedLine(
    String line,
    String query,
    TextStyle baseStyle, {
    required bool isJson,
    required bool isDark,
  }) {
    final lowerQuery = query.toLowerCase();
    if (!isJson || line.length > 500) {
      final spans = <InlineSpan>[];
      _appendSearchHighlightedSegment(spans, line, lowerQuery, baseStyle);
      return TextSpan(children: spans);
    }

    final keyColor = isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1);
    final strColor = isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
    final numColor = isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
    final boolColor =
        isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9);
    final punctStyle = baseStyle.copyWith(
      color: MonitorColors.secondaryText.withValues(alpha: 0.85),
    );

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _jsonTokenRegExp.allMatches(line)) {
      if (match.start > lastEnd) {
        _appendSearchHighlightedSegment(
          spans,
          line.substring(lastEnd, match.start),
          lowerQuery,
          punctStyle,
        );
      }

      if (match.group(1) != null) {
        // JSON key + colon
        _appendSearchHighlightedSegment(
          spans,
          match.group(1)!,
          lowerQuery,
          baseStyle.copyWith(color: keyColor, fontWeight: FontWeight.w600),
        );
        _appendSearchHighlightedSegment(
          spans,
          match.group(2) ?? ':',
          lowerQuery,
          punctStyle,
        );
      } else if (match.group(3) != null) {
        // JSON string value
        _appendSearchHighlightedSegment(
          spans,
          match.group(3)!,
          lowerQuery,
          baseStyle.copyWith(color: strColor),
        );
      } else if (match.group(4) != null) {
        // true / false / null
        _appendSearchHighlightedSegment(
          spans,
          match.group(4)!,
          lowerQuery,
          baseStyle.copyWith(color: boolColor, fontWeight: FontWeight.w600),
        );
      } else if (match.group(5) != null) {
        // number
        _appendSearchHighlightedSegment(
          spans,
          match.group(5)!,
          lowerQuery,
          baseStyle.copyWith(color: numColor, fontWeight: FontWeight.w600),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < line.length) {
      _appendSearchHighlightedSegment(
        spans,
        line.substring(lastEnd),
        lowerQuery,
        punctStyle,
      );
    }

    return TextSpan(children: spans);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Widget _buildQuickJumpButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isActive,
    required Color borderCol,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: isActive
              ? MonitorColors.metricTotal.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive
                ? MonitorColors.metricTotal.withValues(alpha: 0.45)
                : borderCol,
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 9.5,
              color: isActive
                  ? MonitorColors.metricTotal
                  : MonitorColors.secondaryText.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 2),
            MonoText(
              label,
              7.5,
              color: isActive
                  ? MonitorColors.metricTotal
                  : MonitorColors.secondaryText.withValues(alpha: 0.6),
              weight: FontWeight.bold,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineRow(
    int index, {
    required bool isJson,
    required bool isDark,
    required Color lineNumCol,
    required Color borderCol,
    required bool wrap,
  }) {
    final line = _lines[index];
    final isMatchedLine =
        _searchQuery.isNotEmpty && _matchingLineIndices.contains(index);
    final isCurrentActiveMatch = _matchingLineIndices.isNotEmpty &&
        _currentMatchIndex < _matchingLineIndices.length &&
        _matchingLineIndices[_currentMatchIndex] == index;

    final lineNumWidth =
        (_lines.length.toString().length * 7.5 + 14.0).clamp(28.0, 60.0);

    return Container(
      color: isCurrentActiveMatch
          ? Colors.orange.withValues(alpha: 0.18)
          : isMatchedLine
              ? Colors.yellow.withValues(alpha: 0.08)
              : Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: 6,
        vertical: wrap ? 2.0 : 0.0,
      ),
      child: Row(
        crossAxisAlignment:
            wrap ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: lineNumWidth,
            child: Padding(
              padding: EdgeInsets.only(top: wrap ? 1.5 : 0.0),
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: MonitorTextStyle.monoFontFamily,
                  fontSize: 9,
                  color: lineNumCol,
                  height: 1.2,
                ),
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
              maxLines: wrap ? null : 1,
              softWrap: wrap,
              overflow: TextOverflow.visible,
              text: _buildHighlightedLine(
                line,
                _searchQuery,
                TextStyle(
                  fontFamily: MonitorTextStyle.monoFontFamily,
                  fontSize: 10.5,
                  color: MonitorColors.primaryText,
                  height: wrap ? 1.35 : 1.1,
                ),
                isJson: isJson,
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MonitorColors.isDark;
    final headerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final bodyBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderCol = MonitorColors.border.withValues(alpha: 0.8);
    final lineNumCol = MonitorColors.secondaryText.withValues(alpha: 0.5);

    final isJson = widget.text.trim().startsWith('{') ||
        widget.text.trim().startsWith('[');
    final sizeStr = _formatSize(widget.text.length);
    final lineCount = _lines.length;
    final bool isLongContent = lineCount > 12;

    final double linesHeight = (_lines.length * 18.5) + 16.0;
    final double maxInlineHeight = _tallBox ? 580.0 : 340.0;
    final double boxHeight = linesHeight.clamp(80.0, maxInlineHeight);

    final Widget scrollableList = SelectionArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_wordWrap) {
            return Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _lines.length,
                padding: EdgeInsets.only(
                  top: 8,
                  bottom: isLongContent ? 34 : 8,
                ),
                itemBuilder: (context, index) => _buildLineRow(
                  index,
                  isJson: isJson,
                  isDark: isDark,
                  lineNumCol: lineNumCol,
                  borderCol: borderCol,
                  wrap: true,
                ),
              ),
            );
          }

          final double estimatedWidth =
              (_maxLineChars * 6.5 + 72.0).clamp(280.0, 2400.0);
          final double targetWidth = constraints.maxWidth.isFinite &&
                  constraints.maxWidth > estimatedWidth
              ? constraints.maxWidth
              : estimatedWidth;

          return Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: targetWidth,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _lines.length,
                  itemExtent: 18.5,
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: isLongContent ? 34 : 8,
                  ),
                  itemBuilder: (context, index) => _buildLineRow(
                    index,
                    isJson: isJson,
                    isDark: isDark,
                    lineNumCol: lineNumCol,
                    borderCol: borderCol,
                    wrap: false,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    final Widget codeContent = Container(
      decoration: BoxDecoration(
        color: bodyBg,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(7.2),
          bottomRight: Radius.circular(7.2),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: scrollableList),
          if (lineCount > 15)
            Positioned(
              right: 10,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: headerBg.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: MonitorColors.metricTotal.withValues(alpha: 0.35),
                    width: 0.7,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MonoText(
                      'L$_currentTopLine/$lineCount',
                      7.5,
                      color: MonitorColors.secondaryText,
                      weight: FontWeight.w600,
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _scrollToTop,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.vertical_align_top_rounded,
                              size: 11,
                              color: !_isAtTop
                                  ? MonitorColors.metricTotal
                                  : MonitorColors.secondaryText
                                      .withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 1.5),
                            MonoText(
                              'Đầu',
                              8.0,
                              color: !_isAtTop
                                  ? MonitorColors.metricTotal
                                  : MonitorColors.secondaryText
                                      .withValues(alpha: 0.4),
                              weight: FontWeight.bold,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: borderCol,
                    ),
                    GestureDetector(
                      onTap: _scrollToBottom,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.vertical_align_bottom_rounded,
                              size: 11,
                              color: !_isAtBottom
                                  ? MonitorColors.metricTotal
                                  : MonitorColors.secondaryText
                                      .withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 1.5),
                            MonoText(
                              'Cuối',
                              8.0,
                              color: !_isAtBottom
                                  ? MonitorColors.metricTotal
                                  : MonitorColors.secondaryText
                                      .withValues(alpha: 0.4),
                              weight: FontWeight.bold,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!widget.fillHeight && lineCount > 22) ...[
                      Container(
                        width: 1,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: borderCol,
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _tallBox = !_tallBox),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 2, vertical: 1),
                          child: Icon(
                            _tallBox
                                ? Icons.unfold_less_rounded
                                : Icons.unfold_more_rounded,
                            size: 12,
                            color: _tallBox
                                ? MonitorColors.metricTotal
                                : MonitorColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4.5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isJson
                              ? MonitorColors.statusSuccess
                                  .withValues(alpha: 0.15)
                              : MonitorColors.secondaryText
                                  .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: MonoText(
                          isJson ? 'JSON' : 'TEXT',
                          8.0,
                          color: isJson
                              ? MonitorColors.statusSuccess
                              : MonitorColors.secondaryText,
                          weight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '$lineCount lines · $sizeStr',
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
                    if (isLongContent) ...[
                      _buildQuickJumpButton(
                        icon: Icons.vertical_align_top_rounded,
                        label: 'Đầu',
                        onTap: _scrollToTop,
                        isActive: !_isAtTop,
                        borderCol: borderCol,
                      ),
                      const SizedBox(width: 3),
                      _buildQuickJumpButton(
                        icon: Icons.vertical_align_bottom_rounded,
                        label: 'Cuối',
                        onTap: _scrollToBottom,
                        isActive: !_isAtBottom,
                        borderCol: borderCol,
                      ),
                      const SizedBox(width: 4),
                    ],
                    GestureDetector(
                      onTap: () => setState(() => _wordWrap = !_wordWrap),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: _wordWrap
                              ? MonitorColors.metricTotal
                                  .withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _wordWrap
                                ? MonitorColors.metricTotal
                                    .withValues(alpha: 0.4)
                                : borderCol,
                            width: 0.6,
                          ),
                        ),
                        child: MonoText(
                          'WRAP',
                          7.5,
                          color: _wordWrap
                              ? MonitorColors.metricTotal
                              : MonitorColors.secondaryText,
                          weight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: _prettyJson
                                ? MonitorColors.metricTotal
                                    .withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _prettyJson
                                  ? MonitorColors.metricTotal
                                      .withValues(alpha: 0.4)
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
                        color: _searchMode
                            ? MonitorColors.statusError
                            : MonitorColors.secondaryText,
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
                      constraints:
                          const BoxConstraints(minWidth: 20, minHeight: 20),
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
                border:
                    Border(bottom: BorderSide(color: borderCol, width: 0.5)),
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        hintText: LocaleKeys.searchResponsePlaceholder.tr,
                        hintStyle: TextStyle(
                          fontFamily: MonitorTextStyle.monoFontFamily,
                          fontSize: 9.5,
                          color: MonitorColors.secondaryText
                              .withValues(alpha: 0.5),
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
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
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
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
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
    final color = MonitorColors.methodColor(method);
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
          BodyText('⚠ SLOW', 7,
              color: MonitorColors.statusSlow, weight: FontWeight.bold),
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
          child: MonoText(callerName, 10,
              color: color, maxLines: 1, overflow: TextOverflow.ellipsis),
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
      child: MonoText('×$count', 9,
          color: Color(0xFFB45309), weight: FontWeight.bold),
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
            child: BodyText(
                'Slow: ${(duration / 1000).toStringAsFixed(2)}s — risk of UI jank.',
                10,
                color: MonitorColors.statusSlow,
                weight: FontWeight.w500),
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
        MonoText(
            '${MonitorController.formatRouteName(log.screen)}  ·  ${log.phase == 'OPEN' ? LocaleKeys.initLabel.tr : LocaleKeys.actionLabel.tr}',
            10,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        if (log.hasCallerName) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.call_made, size: 10, color: MonitorColors.callerName),
              const SizedBox(width: 4),
              Expanded(
                child: SelectionArea(
                  child: MonoText(log.callerName, 10,
                      color: MonitorColors.callerName,
                      weight: FontWeight.w600,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
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
        return MonitorResponsiveDialogWrapper(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: MonitorColors.surface,
            elevation: 0,
            leading: IconButton(
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
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
                                color: MonitorColors.secondaryText
                                    .withValues(alpha: 0.8),
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
  late int _tab;

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    final hasResBody = log.responseBody != null && log.responseBody!.isNotEmpty;
    final hasReqPayload =
        (log.requestBody != null && log.requestBody!.isNotEmpty) ||
            _extractEffectiveQueryParams(log).isNotEmpty;
    _tab = (hasResBody || !log.isSuccess || !hasReqPayload) ? 1 : 0;
  }

  List<String> _buildTabLabels(ApiLogItem log) {
    final paramCount = _extractAllParamsMap(log).length;
    final hdrCount = log.requestHeaders.length + log.responseHeaders.length;
    return [
      paramCount > 0 ? 'REQUEST ($paramCount)' : 'REQUEST',
      'RESPONSE',
      'TIMELINE',
      hdrCount > 0 ? 'HEADERS ($hdrCount)' : 'HEADERS',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final tabLabels = _buildTabLabels(log);
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
                  tabs: tabLabels,
                  active: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
              ),
              // Vertical divider
              Container(
                width: 1,
                height: 32,
                color: MonitorColors.border,
              ),
              // Copy-all button
              InkWell(
                onTap: () => _showCopySheet(context, log),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  height: 32,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_all_rounded,
                        size: 14,
                        color: MonitorColors.secondaryText,
                      ),
                      const SizedBox(width: 3),
                      BodyText(
                        'Copy',
                        8.5,
                        color: MonitorColors.secondaryText,
                        weight: FontWeight.w600,
                      ),
                    ],
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
      routeSettings:
          const RouteSettings(name: MonitorConstants.copyActionsSheet),
      builder: (_) => _CopyActionsSheet(log: log),
    );
  }

  Widget _buildContent(ApiLogItem log, {bool isFullPage = false}) {
    switch (_tab) {
      case 0:
        return _RequestContent(log: log, isFullPage: isFullPage);
      case 1:
        return _ResponseContent(
          log: log,
          isFullPage: isFullPage,
          onSwitchToRequestTab: () => setState(() => _tab = 0),
        );
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
