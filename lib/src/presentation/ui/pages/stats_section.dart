part of 'monitor_dashboard_page.dart';

class _StatsSection extends StatefulWidget {
  const _StatsSection();

  @override
  State<_StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends State<_StatsSection> {
  bool _loading = true;
  List<DailyStatItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final data = await MonitorController.instance.getDailyStats();
    if (mounted) {
      setState(() {
        _items = data;
        _loading = false;
      });
    }
  }

  Map<String, int> _getTopScreens() {
    final counts = <String, int>{};
    for (final item in _items) {
      if (item.type == 'route') {
        counts[item.route] = (counts[item.route] ?? 0) + 1;
      }
    }
    return counts;
  }

  Map<String, int> _getTopApis() {
    final counts = <String, int>{};
    for (final item in _items) {
      if (item.type == 'api' && item.url != null) {
        final key = '[${item.method ?? "GET"}] ${item.url}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return counts;
  }

  Map<String, int> _getTopErrors() {
    final counts = <String, int>{};
    for (final item in _items) {
      final isApiError = item.type == 'api' &&
          item.status != null &&
          (item.status! < 200 || item.status! >= 300);
      final isGeneralError = item.type == 'error';
      if (isApiError || isGeneralError) {
        final screen = item.route;
        final displayScreen =
            screen.isEmpty ? MonitorConstants.unknownRoute : screen;
        counts[displayScreen] = (counts[displayScreen] ?? 0) + 1;
      }
    }
    return counts;
  }

  Map<String, ({double avg, int count})> _getTopSlowApis() {
    final durations = <String, List<int>>{};
    for (final item in _items) {
      if (item.type == 'api' && item.url != null && item.duration != null) {
        final key = '[${item.method ?? "GET"}] ${item.url}';
        durations.putIfAbsent(key, () => []).add(item.duration!);
      }
    }
    final stats = <String, ({double avg, int count})>{};
    durations.forEach((key, list) {
      final avg = list.reduce((a, b) => a + b) / list.length;
      stats[key] = (avg: avg, count: list.length);
    });
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation<Color>(MonitorColors.primaryText),
          ),
        ),
      );
    }

    final topScreens = _getTopScreens();
    final topApis = _getTopApis();
    final topErrors = _getTopErrors();
    final topSlow = _getTopSlowApis();

    final noData = topScreens.isEmpty &&
        topApis.isEmpty &&
        topErrors.isEmpty &&
        topSlow.isEmpty;

    if (noData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 40, color: MonitorColors.secondaryText),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.statsNoData.tr,
              style: TextStyle(
                fontSize: 11,
                color: MonitorColors.secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: MonitorColors.primaryText,
      backgroundColor: MonitorColors.surface,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _StatsCard(
            title: LocaleKeys.statsApiTraffic.tr,
            icon: Icons.trending_up_rounded,
            iconColor: MonitorColors.metricTotal,
            child: _TrafficLineChart(items: _items),
          ),
          _StatsCard(
            title: LocaleKeys.statsTopScreens.tr,
            icon: Icons.layers_outlined,
            iconColor: const Color(0xFF57D888),
            child: _HorizontalBarChart(
              data: topScreens,
              countFormatter: (v) => LocaleKeys.statsVisits.trWith({'count': v}),
              barColor: const Color(0xFF57D888),
            ),
          ),
          _StatsCard(
            title: LocaleKeys.statsTopApis.tr,
            icon: Icons.api_rounded,
            iconColor: MonitorColors.metricTotal,
            child: _HorizontalBarChart(
              data: topApis,
              countFormatter: (v) => LocaleKeys.statsCalls.trWith({'count': v}),
              barColor: MonitorColors.metricTotal,
            ),
          ),
          _StatsCard(
            title: LocaleKeys.statsErrorDistribution.tr,
            icon: Icons.pie_chart_rounded,
            iconColor: MonitorColors.statusError,
            child: _ErrorDonutChart(data: topErrors),
          ),
          _StatsCard(
            title: LocaleKeys.statsTopSlow.tr,
            icon: Icons.timer_outlined,
            iconColor: Colors.orange,
            child: _SlowApisList(data: topSlow),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _StatsCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MonitorColors.expandedDetailBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MonitorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: MonitorColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HorizontalBarChart extends StatelessWidget {
  final Map<String, int> data;
  final String Function(int count) countFormatter;
  final Color barColor;

  const _HorizontalBarChart({
    required this.data,
    required this.countFormatter,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            LocaleKeys.statsNoData.tr,
            style: TextStyle(
              fontSize: 10,
              color: MonitorColors.secondaryText,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(5).toList();
    final maxVal = topEntries.first.value;

    return Column(
      children: topEntries.map((entry) {
        final ratio = maxVal > 0 ? entry.value / maxVal : 0.0;
        final cleanLabel = MonitorController.formatRouteName(entry.key);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      cleanLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: MonitorColors.primaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    countFormatter(entry.value),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: MonitorColors.secondaryText,
                      fontFamily: MonitorTextStyle.monoFontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, constraints) {
                  final barWidth = constraints.maxWidth * ratio;
                  return Stack(
                    children: [
                      Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: MonitorColors.border.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        height: 8,
                        width: barWidth.clamp(8.0, double.infinity),
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: barColor.withValues(alpha: 0.25),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            )
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SlowApisList extends StatelessWidget {
  final Map<String, ({double avg, int count})> data;

  const _SlowApisList({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            LocaleKeys.statsNoData.tr,
            style: TextStyle(
              fontSize: 10,
              color: MonitorColors.secondaryText,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.avg.compareTo(a.value.avg));
    final topEntries = sortedEntries.take(5).toList();

    return Column(
      children: topEntries.map((entry) {
        final key = entry.key;
        final val = entry.value;
        final avgMs = val.avg.round();
        final isSlow = avgMs > 1000;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  key,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: MonitorColors.primaryText,
                    fontFamily: MonitorTextStyle.monoFontFamily,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$avgMs ms',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSlow
                          ? MonitorColors.statusError
                          : const Color(0xFF57D888),
                      fontFamily: MonitorTextStyle.monoFontFamily,
                    ),
                  ),
                  Text(
                    LocaleKeys.statsCalls.trWith({'count': val.count}),
                    style: TextStyle(
                      fontSize: 8,
                      color: MonitorColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TrafficLineChart extends StatelessWidget {
  final List<DailyStatItem> items;

  const _TrafficLineChart({required this.items});

  List<int> _computeBuckets() {
    final buckets = List<int>.filled(12, 0);
    final now = DateTime.now();
    for (final item in items) {
      if (item.type == 'api') {
        final time = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
        final diff = now.difference(time);
        final diffHours = diff.inHours;
        if (diffHours >= 0 && diffHours < 72) {
          final bucketIdx = 11 - (diffHours ~/ 6);
          if (bucketIdx >= 0 && bucketIdx < 12) {
            buckets[bucketIdx]++;
          }
        }
      }
    }
    return buckets;
  }

  @override
  Widget build(BuildContext context) {
    final data = _computeBuckets();
    final maxVal = data.isEmpty ? 0 : data.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 120,
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _TrafficChartPainter(
              data: data,
              maxVal: maxVal.toDouble(),
              isDark: MonitorColors.isDark,
            ),
          );
        },
      ),
    );
  }
}

class _TrafficChartPainter extends CustomPainter {
  final List<int> data;
  final double maxVal;
  final bool isDark;

  const _TrafficChartPainter({
    required this.data,
    required this.maxVal,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double bottomPadding = 16.0;
    const double sidePadding = 12.0;
    final chartHeight = size.height - bottomPadding;
    final chartWidth = size.width - (sidePadding * 2);

    // 1. Draw Grid Lines
    final gridPaint = Paint()
      ..color = MonitorColors.border.withValues(alpha: 0.15)
      ..strokeWidth = 0.8;

    const linesCount = 4;
    for (int i = 0; i < linesCount; i++) {
      final y = chartHeight * (i / (linesCount - 1));
      canvas.drawLine(
        Offset(sidePadding, y),
        Offset(size.width - sidePadding, y),
        gridPaint,
      );

      // Add Y-axis labels
      if (maxVal > 0) {
        final val = maxVal * (1 - (i / (linesCount - 1)));
        if (val >= 0) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: val.toInt().toString(),
              style: TextStyle(
                fontSize: 8.5,
                color: MonitorColors.secondaryText,
                fontFamily: MonitorTextStyle.monoFontFamily,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(canvas, Offset(sidePadding, y - textPainter.height - 2));
        }
      }
    }

    if (data.isEmpty || maxVal == 0) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'No API traffic logged',
          style: TextStyle(
            fontSize: 9,
            color: MonitorColors.secondaryText,
            fontStyle: FontStyle.italic,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (chartHeight - textPainter.height) / 2,
        ),
      );
      _drawTimeLabels(canvas, size, sidePadding, chartHeight);
      return;
    }

    final lineAccent = MonitorColors.metricTotal;
    final barPaint = Paint()..color = lineAccent;
    final glowPaint = Paint()..color = lineAccent.withValues(alpha: 0.25);

    // 2. Draw Bars
    final barTotalWidth = chartWidth / data.length;
    final barWidth = barTotalWidth * 0.6;
    final spacing = barTotalWidth * 0.4;

    for (int i = 0; i < data.length; i++) {
      final val = data[i];
      if (val == 0) continue;
      
      final ratio = maxVal > 0 ? val / maxVal : 0.0;
      final x = sidePadding + (i * barTotalWidth) + (spacing / 2);
      final barH = ratio * (chartHeight - 12);
      final y = chartHeight - barH - 4;

      final rect = Rect.fromLTWH(x, y, barWidth, barH.clamp(3.0, double.infinity));

      // Draw faint glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left - 1, rect.top - 1, rect.width + 2, rect.height + 2),
          const Radius.circular(4),
        ),
        glowPaint,
      );

      // Draw solid bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        barPaint,
      );
    }

    // 6. Draw time labels
    _drawTimeLabels(canvas, size, sidePadding, chartHeight);
  }

  void _drawTimeLabels(
      Canvas canvas, Size size, double sidePadding, double chartHeight) {
    final labels = ['-72h', '-54h', '-36h', '-18h', 'Now'];
    final labelsCount = labels.length;
    final stepLabelX = (size.width - (sidePadding * 2)) / (labelsCount - 1);

    for (int i = 0; i < labelsCount; i++) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.w600,
            color: MonitorColors.secondaryText,
            fontFamily: MonitorTextStyle.monoFontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final x = sidePadding + (i * stepLabelX) - (textPainter.width / 2);
      final y = chartHeight + 6.0;
      textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _TrafficChartPainter old) {
    return old.isDark != isDark ||
        old.maxVal != maxVal ||
        old.data.length != data.length ||
        (data.isNotEmpty && old.data.isNotEmpty && old.data.last != data.last);
  }
}

class _ErrorDonutChart extends StatelessWidget {
  final Map<String, int> data;

  const _ErrorDonutChart({required this.data});

  static const List<Color> _donutColors = [
    Color(0xFFEF5350), // Red
    Color(0xFFAB47BC), // Purple
    Color(0xFF5C6BC0), // Indigo
    Color(0xFF26A69A), // Teal
    Color(0xFFFFA726), // Orange
  ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            LocaleKeys.statsNoData.tr,
            style: TextStyle(
              fontSize: 10,
              color: MonitorColors.secondaryText,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final total = data.values.fold(0, (a, b) => a + b);
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(5).toList();

    // Map colors to top entries
    final sectors = <_DonutSector>[];
    for (int i = 0; i < topEntries.length; i++) {
      sectors.add(_DonutSector(
        label: topEntries[i].key,
        count: topEntries[i].value,
        ratio: topEntries[i].value / total,
        color: _donutColors[i % _donutColors.length],
      ));
    }

    // Account for remaining errors if there are more than 5 screens
    final topSum = topEntries.fold(0, (sum, entry) => sum + entry.value);
    if (total > topSum) {
      final remaining = total - topSum;
      sectors.add(_DonutSector(
        label: 'Others',
        count: remaining,
        ratio: remaining / total,
        color: Colors.grey,
      ));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left side: The Donut Chart
        SizedBox(
          width: 80,
          height: 80,
          child: CustomPaint(
            painter: _DonutChartPainter(
              sectors: sectors,
              total: total,
              isDark: MonitorColors.isDark,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Right side: The Legend
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sectors.map((sector) {
              final percentage = (sector.ratio * 100).toStringAsFixed(0);
              final cleanLabel = MonitorController.formatRouteName(sector.label);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.5),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: sector.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cleanLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: MonitorColors.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$percentage% (${sector.count})',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: MonitorColors.secondaryText,
                        fontFamily: MonitorTextStyle.monoFontFamily,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutSector {
  final String label;
  final int count;
  final double ratio;
  final Color color;

  const _DonutSector({
    required this.label,
    required this.count,
    required this.ratio,
    required this.color,
  });
}

class _DonutChartPainter extends CustomPainter {
  final List<_DonutSector> sectors;
  final int total;
  final bool isDark;

  const _DonutChartPainter({
    required this.sectors,
    required this.total,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12.0) / 2;

    final bgPaint = Paint()
      ..color = MonitorColors.border.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;
    canvas.drawCircle(center, radius, bgPaint);

    double startAngle = -math.pi / 2; // Start from 12 o'clock
    for (final sector in sectors) {
      final sweepAngle = sector.ratio * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..color = sector.color
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    // Draw total errors text in center
    final countPainter = TextPainter(
      text: TextSpan(
        text: '$total',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: MonitorColors.primaryText,
          fontFamily: MonitorTextStyle.monoFontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final countOffset = Offset(
      center.dx - (countPainter.width / 2),
      center.dy - (countPainter.height / 2) - 4.0,
    );
    countPainter.paint(canvas, countOffset);

    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'ERRORS',
        style: TextStyle(
          fontSize: 6.5,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelOffset = Offset(
      center.dx - (labelPainter.width / 2),
      center.dy + (countPainter.height / 2) - 4.0,
    );
    labelPainter.paint(canvas, labelOffset);
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter old) {
    return old.isDark != isDark ||
        old.total != total ||
        old.sectors.length != sectors.length;
  }
}
