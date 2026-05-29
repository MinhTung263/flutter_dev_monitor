import 'package:flutter/material.dart';

abstract class MonitorColors {
  static const Color pageBackground = Color(0xFFF4F6F9);
  static const Color surface = Colors.white;
  static const Color expandedDetailBg = Color(0xFFF8FAFC);
  static const Color metricsBarBg = Color(0xFFEBF0F5);
  static const Color dropdownBg = Color(0xFFF0F2F5);
  static const Color border = Color(0xFFE2E8F0);

  static const Color primaryText = Color(0xFF1A1D23);
  static const Color secondaryText = Color(0xFF64748B);

  static const Color statusSuccess = Color(0xFF2E7D32);
  static const Color statusError = Color(0xFFD32F2F);
  static const Color statusSlow = Color(0xFFE65100);

  static const Color initPhase = Color(0xFFE65100);
  static const Color refreshPhase = Color(0xFF00796B);

  static const Color methodGet = Color(0xFF1976D2);
  static const Color methodPost = Color(0xFF388E3C);

  static const Color metricTotal = Color(0xFF0288D1);
  static const Color metricInit = Color(0xFFE65100);
  static const Color metricRefresh = Color(0xFF00796B);

  static const Color orderBadgeBg = Color(0xFFE2E8F0);
  static const Color orderBadgeText = Color(0xFF64748B);

  static const Color callerName = Color(0xFF7B61FF);

  static const Color slowBannerBg = Color(0xFFFFF3E0);
  static const Color slowBannerBorder = Color(0xFFFFB74D);

  static const Color fpsLine = Color(0xFF0EA5E9);
  static const Color fpsDot = Color(0xFFEF4444);

  static const Color overlayBg = Color(0xEE0A0A0A);
  static const Color overlayPanelBg = Color(0xFF0D0D0D);
  static const Color overlayButtonBg = Color(0xFF1A1A1A);
  static const Color overlayBorder = Color(0xFF1F1F1F);
  static const Color overlayFps = Color(0xFF4ADE80);
  static const Color overlayAlert = Color(0xFFFF5555);
  static const Color overlayGpu = Color(0xFFFB923C);
  static const Color overlayBuild = Color(0xFFFBBF24);
  static const Color overlayMem = Color(0xFFF472B6);
  static const Color overlayApi = Color(0xFF60A5FA);
}

abstract class OverlayLayout {
  static const double expandedW = 258.0;
  static const double expandedH = 240.0;
  static const double pillW = 110.0;
  static const double pillH = 48.0;
  static const double edgeMargin = 8.0;
}

String fmtDuration(int ms) {
  if (ms >= 1000) return '${(ms / 1000).toStringAsFixed(2)}s';
  return '${ms}ms';
}
