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
          BodyText('No Flutter errors', 13,
              color: MonitorColors.secondaryText,
              weight: FontWeight.w500),
          SizedBox(height: 4),
          BodyText('caught yet', 11, color: MonitorColors.border),
        ],
      ),
    );
  }
}

class _ErrorList extends StatelessWidget {
  final List<ErrorLogItem> errors;
  const _ErrorList({required this.errors});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: errors.length,
      itemBuilder: (_, i) => _ErrorLogTile(error: errors[i]),
    );
  }
}

class _ErrorLogTile extends StatefulWidget {
  final ErrorLogItem error;
  const _ErrorLogTile({required this.error});

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
                          color: MonitorColors.orderBadgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: MonoText('#${e.id}', 9,
                            color: MonitorColors.orderBadgeText,
                            weight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
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
                              content: Text('Error copied to clipboard',
                                  style: TextStyle(
                                      color: MonitorColors.primaryText,
                                      fontFamily: 'monospace',
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
