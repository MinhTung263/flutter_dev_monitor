import 'package:flutter/material.dart';

import '../theme/monitor_theme.dart';

const Color _kRamColor = Color(0xFFF472B6);

class RamChartWidget extends StatelessWidget {
  final List<double> history;
  final double totalRam;

  const RamChartWidget({
    super.key,
    required this.history,
    required this.totalRam,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: Text('No RAM data for this screen',
            style: TextStyle(color: MonitorColors.secondaryText, fontSize: 11)),
      );
    }

    final maxVal = history.reduce((a, b) => a > b ? a : b);
    final minVal = history.reduce((a, b) => a < b ? a : b);
    final avgVal = history.reduce((a, b) => a + b) / history.length;
    final curVal = history.last;
    // Auto-scale to actual usage so the chart isn't flat at the bottom
    // (device total RAM can be 8+ GB while app only uses ~200–400 MB).
    // Keep at least 256 MB ceiling so an idle app doesn't look huge.
    final chartMax = (maxVal * 1.4).clamp(256.0, double.infinity);
    final isHighMem = totalRam > 0 && maxVal > totalRam * 0.8;

    final usagePct = totalRam > 0 ? curVal / totalRam * 100 : 0.0;
    final usageStr = totalRam > 0 ? '${usagePct.toStringAsFixed(1)}%' : '--';
    final deviceStr = totalRam <= 0
        ? '--'
        : totalRam >= 1024
            ? '${(totalRam / 1024).toStringAsFixed(1)} GB'
            : '${totalRam.toStringAsFixed(0)} MB';

    return Column(
      children: [
        Row(
          children: [
            _RamStatCard(
                label: 'Avg',
                value: '${avgVal.toStringAsFixed(0)}MB',
                color: _kRamColor),
            SizedBox(width: 8),
            _RamStatCard(
                label: 'Min',
                value: '${minVal.toStringAsFixed(0)}MB',
                color: MonitorColors.secondaryText),
            SizedBox(width: 8),
            _RamStatCard(
                label: 'Max',
                value: '${maxVal.toStringAsFixed(0)}MB',
                color: isHighMem ? MonitorColors.statusError : _kRamColor),
          ],
        ),
        SizedBox(height: 6),
        Row(
          children: [
            _RamStatCard(
                label: 'USAGE',
                value: usageStr,
                color: isHighMem ? MonitorColors.statusError : _kRamColor),
            SizedBox(width: 8),
            _RamStatCard(
                label: 'DEVICE',
                value: deviceStr,
                color: MonitorColors.secondaryText),
          ],
        ),
        SizedBox(height: 10),
        Container(
          height: 90,
          width: double.infinity,
          decoration: BoxDecoration(
            color: MonitorColors.expandedDetailBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MonitorColors.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double hPad = 52.0;
              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        right: 44, left: 8, top: 8, bottom: 6),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth - hPad, 76),
                      painter: _RamChartPainter(
                          history: history,
                          maxVal: chartMax,
                          isDark: MonitorColors.isDark),
                    ),
                  ),
                  _RamYAxis(maxVal: chartMax, totalRam: totalRam),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RamStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RamStatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: MonitorColors.border),
        ),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    color: MonitorColors.secondaryText,
                    fontSize: 9,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: MonitorTextStyle.monoFontFamily)),
          ],
        ),
      ),
    );
  }
}

class _RamYAxis extends StatelessWidget {
  final double maxVal;
  final double totalRam;

  const _RamYAxis({required this.maxVal, required this.totalRam});

  @override
  Widget build(BuildContext context) {
    final top = maxVal.toStringAsFixed(0);
    final mid = (maxVal / 2).toStringAsFixed(0);
    final total = totalRam > 0 ? '/${totalRam.toStringAsFixed(0)}' : '';

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: 44,
        padding: const EdgeInsets.only(top: 8, bottom: 6, right: 5),
        decoration: BoxDecoration(
          color: MonitorColors.expandedDetailBg.withValues(alpha: 0.92),
          borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
          border: Border(
              left: BorderSide(
                  color: MonitorColors.border.withValues(alpha: 0.5))),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${top}M',
                style: TextStyle(
                    color: MonitorColors.secondaryText,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    fontFamily: MonitorTextStyle.monoFontFamily)),
            Text('${mid}M$total',
                style: TextStyle(
                    color: MonitorColors.secondaryText,
                    fontSize: 7,
                    fontFamily: MonitorTextStyle.monoFontFamily)),
            Text('0M',
                style: TextStyle(
                    color: MonitorColors.secondaryText,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    fontFamily: MonitorTextStyle.monoFontFamily)),
          ],
        ),
      ),
    );
  }
}

class _RamChartPainter extends CustomPainter {
  final List<double> history;
  final double maxVal;
  final bool isDark;

  const _RamChartPainter({
    required this.history,
    required this.maxVal,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    if (history.isEmpty) return;

    final n = history.length;
    final stepX = n > 1 ? size.width / (n - 1) : size.width;

    final points = [
      for (int i = 0; i < n; i++)
        Offset(
          i * stepX,
          size.height - (history[i].clamp(0.0, maxVal) / maxVal * size.height),
        ),
    ];

    _drawFill(canvas, size, points);
    _drawLine(canvas, points);
    _drawDot(canvas, points.last);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MonitorColors.border
      ..strokeWidth = 0.5;
    for (final ratio in [0.25, 0.5, 0.75, 1.0]) {
      final y = size.height - ratio * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawFill(Canvas canvas, Size size, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _kRamColor.withValues(alpha: 0.20),
            _kRamColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  void _drawLine(Canvas canvas, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _kRamColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawDot(Canvas canvas, Offset point) {
    canvas.drawCircle(
        point, 5.0, Paint()..color = _kRamColor.withValues(alpha: 0.2));
    canvas.drawCircle(point, 2.5, Paint()..color = _kRamColor);
  }

  @override
  bool shouldRepaint(covariant _RamChartPainter old) =>
      old.isDark != isDark ||
      old.history.length != history.length ||
      (history.isNotEmpty &&
          old.history.isNotEmpty &&
          old.history.last != history.last);
}
