part of 'monitor_dashboard_page.dart';

// ─── Grouped log list ─────────────────────────────────────────────────────────

class _HeaderData {
  final String phase;
  final int refreshCycle;
  final int callCount;
  final int totalDuration;
  final int totalBytes;
  const _HeaderData({
    required this.phase,
    required this.refreshCycle,
    required this.callCount,
    required this.totalDuration,
    required this.totalBytes,
  });
}

class _GroupedLogList extends StatelessWidget {
  final List<ApiLogItem> logs;
  const _GroupedLogList({required this.logs});

  List<Object> _buildItems() {
    final items = <Object>[];
    String? prevKey;

    for (final log in logs) {
      final key = '${log.phase}_${log.refreshCycle}';
      if (key != prevKey) {
        prevKey = key;
        final groupLogs = logs.where(
            (l) => l.phase == log.phase && l.refreshCycle == log.refreshCycle);
        items.add(_HeaderData(
          phase: log.phase,
          refreshCycle: log.refreshCycle,
          callCount: groupLogs.fold(0, (s, l) => s + l.callCount),
          totalDuration: groupLogs.fold(0, (s, l) => s + l.duration),
          totalBytes: groupLogs.fold(0, (s, l) => s + l.responseBytes),
        ));
      }
      items.add(log);
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is _HeaderData) return _SectionHeader(data: item);
        return ApiLogTile(log: item as ApiLogItem);
      },
    );
  }
}

// ─── Filter bar ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final List<ApiLogItem> allLogs;
  final String activeFilter;
  final ValueChanged<String> onChanged;

  const _FilterBar({
    required this.allLogs,
    required this.activeFilter,
    required this.onChanged,
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
              SizedBox(width: 6),
              _FilterChip(
                label: 'SLOW',
                count: slowCount,
                active: activeFilter == 'SLOW',
                color: MonitorColors.statusSlow,
                onTap: () => onChanged('SLOW'),
              ),
            ],
            if (errCount > 0) ...[
              SizedBox(width: 6),
              _FilterChip(
                label: 'ERR',
                count: errCount,
                active: activeFilter == 'ERR',
                color: MonitorColors.statusError,
                onTap: () => onChanged('ERR'),
              ),
            ],
            if (getCount > 0) ...[
              SizedBox(width: 6),
              _FilterChip(
                label: 'GET',
                count: getCount,
                active: activeFilter == 'GET',
                color: MonitorColors.methodGet,
                onTap: () => onChanged('GET'),
              ),
            ],
            if (postCount > 0) ...[
              SizedBox(width: 6),
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
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                active ? color.withValues(alpha: 0.55) : MonitorColors.border,
          ),
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
            SizedBox(width: 5),
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

class _SectionHeader extends StatelessWidget {
  final _HeaderData data;
  const _SectionHeader({required this.data});

  static String _fmtBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  String _sectionSummary(_HeaderData d) {
    final size = _fmtBytes(d.totalBytes);
    final parts = ['${d.callCount} calls'];
    if (size.isNotEmpty) parts.add(size);
    parts.add('${d.totalDuration}ms');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final isRefresh = data.phase == ApiLogItem.phaseRefresh;
    final color =
        isRefresh ? MonitorColors.metricRefresh : MonitorColors.metricInit;
    final label = isRefresh
        ? 'ACTION #${data.refreshCycle}'
        : 'INIT #${data.refreshCycle}';

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          LabelText(
            label,
            color,
            size: 10,
            spacing: 0.8,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: MonoText(
              _sectionSummary(data),
              9,
              color: color.withValues(alpha: 0.70),
              weight: FontWeight.w600,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
