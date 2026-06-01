import 'package:flutter/material.dart';

import '../theme/monitor_theme.dart';

class FpsChartWidget extends StatefulWidget {
  final List<double> history;

  const FpsChartWidget({super.key, required this.history});

  @override
  State<FpsChartWidget> createState() => _FpsChartWidgetState();
}

class _FpsChartWidgetState extends State<FpsChartWidget> {
  final _scrollCtrl = ScrollController();
  bool _userScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (!_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position;
      _userScrolling = pos.pixels < pos.maxScrollExtent - 1;
    });
  }

  @override
  void didUpdateWidget(FpsChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_userScrolling && widget.history.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients && _scrollCtrl.position.maxScrollExtent > 0) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.history;
    final maxVal = h.isEmpty ? 0.0 : h.reduce((a, b) => a > b ? a : b);
    final minVal = h.isEmpty ? 0.0 : h.reduce((a, b) => a < b ? a : b);
    final avgVal = h.isEmpty ? 0.0 : h.reduce((a, b) => a + b) / h.length;
    final maxFpsCeil = h.any((fps) => fps > 65) ? 120.0 : 60.0;

    return Column(
      children: [
        Row(
          children: [
            _FpsStatCard(
                label: 'Avg', value: avgVal.toStringAsFixed(1), color: MonitorColors.fpsLine),
            SizedBox(width: 8),
            _FpsStatCard(
              label: 'Min',
              value: minVal.toStringAsFixed(1),
              color: minVal < 50 && minVal > 0
                  ? MonitorColors.statusError
                  : MonitorColors.secondaryText,
            ),
            SizedBox(width: 8),
            _FpsStatCard(
                label: 'Max', value: maxVal.toStringAsFixed(1), color: MonitorColors.statusSuccess),
          ],
        ),
        SizedBox(height: 10),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: MonitorColors.expandedDetailBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MonitorColors.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double stepX = 14.0;
              const double hPad = 52.0;
              final double available = constraints.maxWidth - hPad;
              final double dataWidth = h.length * stepX;
              final bool overflows = dataWidth > available;

              return Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollCtrl,
                    scrollDirection: Axis.horizontal,
                    physics: overflows
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(right: 44, left: 8, top: 10, bottom: 6),
                    child: CustomPaint(
                      size: Size(overflows ? dataWidth : available, 104),
                      painter: _FpsChartPainter(history: h, maxFps: maxFpsCeil, stepX: stepX, isDark: MonitorColors.isDark),
                    ),
                  ),
                  _FpsYAxis(maxFpsCeil: maxFpsCeil),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FpsStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FpsStatCard({required this.label, required this.value, required this.color});

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
            Text('$value fps',
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}

class _FpsYAxis extends StatelessWidget {
  final double maxFpsCeil;
  const _FpsYAxis({required this.maxFpsCeil});

  @override
  Widget build(BuildContext context) {
    final labels = maxFpsCeil == 120.0 ? [120, 90, 60, 30] : [60, 40, 20, 0];
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.only(top: 8, bottom: 6, right: 5),
        decoration: BoxDecoration(
          color: MonitorColors.expandedDetailBg.withValues(alpha: 0.92),
          borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
          border: Border(left: BorderSide(color: MonitorColors.border.withValues(alpha: 0.5))),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: labels
              .map((v) => Text('$v',
                  style: TextStyle(
                      color: MonitorColors.secondaryText,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')))
              .toList(),
        ),
      ),
    );
  }
}

class _FpsChartPainter extends CustomPainter {
  final List<double> history;
  final double maxFps;
  final double stepX;
  final bool isDark;

  const _FpsChartPainter({
    required this.history,
    required this.maxFps,
    required this.stepX,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    if (history.isEmpty) return;

    final points = [
      for (int i = 0; i < history.length; i++)
        Offset(i * stepX, size.height - (history[i].clamp(0.0, maxFps) / maxFps * size.height)),
    ];

    _drawFill(canvas, size, points);
    _drawLine(canvas, points);
    _drawDot(canvas, points.last);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MonitorColors.border
      ..strokeWidth = 0.5;
    final values = maxFps == 120.0 ? [30.0, 60.0, 90.0, 120.0] : [0.0, 20.0, 40.0, 60.0];
    for (final v in values) {
      final y = size.height - (v / maxFps * size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawFill(Canvas canvas, Size size, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) path.lineTo(points[i].dx, points[i].dy);
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
            MonitorColors.fpsLine.withValues(alpha: 0.18),
            MonitorColors.fpsLine.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  void _drawLine(Canvas canvas, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) path.lineTo(points[i].dx, points[i].dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = MonitorColors.fpsLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawDot(Canvas canvas, Offset point) {
    canvas.drawCircle(point, 5.0, Paint()..color = MonitorColors.fpsDot.withValues(alpha: 0.2));
    canvas.drawCircle(point, 2.5, Paint()..color = MonitorColors.fpsDot);
  }

  @override
  bool shouldRepaint(covariant _FpsChartPainter old) =>
      old.isDark != isDark ||
      old.history.length != history.length ||
      old.maxFps != maxFps ||
      (history.isNotEmpty &&
          old.history.isNotEmpty &&
          old.history.last != history.last);
}
