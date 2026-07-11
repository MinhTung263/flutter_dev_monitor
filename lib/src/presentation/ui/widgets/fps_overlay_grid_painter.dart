import 'package:flutter/material.dart';
import '../../../domain/overlay_state_entity.dart';

class FpsOverlayGridPainter extends CustomPainter {
  final GridMode mode;
  final bool isDark;
  final EdgeInsets? padding;

  const FpsOverlayGridPainter({
    required this.mode,
    required this.isDark,
    this.padding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == GridMode.off) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Use high-contrast blue/cyan colors that stand out on white/black backgrounds
    final Color baseColor = isDark
        ? const Color(0xFF22D3EE) // Cyan accent
        : const Color(0xFF0284C7); // Light Blue accent

    final Color mainLineColor = baseColor.withValues(alpha: 0.35);
    final Color majorLineColor = baseColor.withValues(alpha: 0.70);

    if (mode == GridMode.grid8 || mode == GridMode.grid16) {
      final double spacing = mode == GridMode.grid8 ? 8.0 : 16.0;

      // Draw vertical lines
      for (double x = 0.0; x < size.width; x += spacing) {
        final int lineIndex = (x / spacing).round();
        final isMajor = lineIndex % 5 == 0;
        paint.color = isMajor ? majorLineColor : mainLineColor;
        paint.strokeWidth = isMajor ? 1.5 : 0.8;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }

      // Draw horizontal lines
      for (double y = 0.0; y < size.height; y += spacing) {
        final int lineIndex = (y / spacing).round();
        final isMajor = lineIndex % 5 == 0;
        paint.color = isMajor ? majorLineColor : mainLineColor;
        paint.strokeWidth = isMajor ? 1.5 : 0.8;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } else if (mode == GridMode.crosshair) {
      final centerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = isDark ? const Color(0xFF22D3EE) : const Color(0xFF0891B2);

      final centerX = size.width / 2;
      final centerY = size.height / 2;

      // Draw center cross
      canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), centerPaint);
      canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), centerPaint);

      // Draw 25% / 75% reference lines
      final dashPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = baseColor.withValues(alpha: 0.50);

      canvas.drawLine(Offset(size.width * 0.25, 0), Offset(size.width * 0.25, size.height), dashPaint);
      canvas.drawLine(Offset(size.width * 0.75, 0), Offset(size.width * 0.75, size.height), dashPaint);
      canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25), dashPaint);
      canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), dashPaint);
    } else if (mode == GridMode.margins) {
      final pad = padding ?? EdgeInsets.zero;

      // 16px Margins (Coral Red)
      final paint16 = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFF43F5E);

      // Outer boundary: Left = 16, Right = width - 16
      canvas.drawLine(Offset(16.0, 0), Offset(16.0, size.height), paint16);
      canvas.drawLine(Offset(size.width - 16.0, 0), Offset(size.width - 16.0, size.height), paint16);

      // Top boundary (16px below status bar) and Bottom boundary (16px above home indicator)
      final topY16 = pad.top + 16.0;
      final bottomY16 = size.height - pad.bottom - 16.0;
      canvas.drawLine(Offset(0, topY16), Offset(size.width, topY16), paint16);
      canvas.drawLine(Offset(0, bottomY16), Offset(size.width, bottomY16), paint16);

      // 24px Margins (Cyan / Blue)
      final paint24 = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7);

      // Outer boundary: Left = 24, Right = width - 24
      canvas.drawLine(Offset(24.0, 0), Offset(24.0, size.height), paint24);
      canvas.drawLine(Offset(size.width - 24.0, 0), Offset(size.width - 24.0, size.height), paint24);

      // Top boundary (24px below status bar) and Bottom boundary (24px above home indicator)
      final topY24 = pad.top + 24.0;
      final bottomY24 = size.height - pad.bottom - 24.0;
      canvas.drawLine(Offset(0, topY24), Offset(size.width, topY24), paint24);
      canvas.drawLine(Offset(0, bottomY24), Offset(size.width, bottomY24), paint24);

      // Draw text labels for 16px / 24px near the top-left
      final textPainter16 = TextPainter(
        text: const TextSpan(
          text: ' 16px margin ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0xFFF43F5E),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textPainter24 = TextPainter(
        text: TextSpan(
          text: ' 24px margin ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            backgroundColor: isDark ? const Color(0xFF0891B2) : const Color(0xFF0284C7),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter16.paint(canvas, Offset(16.0, pad.top + 32.0));
      textPainter24.paint(canvas, Offset(24.0, pad.top + 45.0));
    }
  }

  @override
  bool shouldRepaint(covariant FpsOverlayGridPainter oldDelegate) =>
      oldDelegate.mode != mode ||
      oldDelegate.isDark != isDark ||
      oldDelegate.padding != padding;
}
