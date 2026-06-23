import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class MonitorColors {
  static const _channel = MethodChannel('flutter_dev_monitor/system_monitor');

  static final ValueNotifier<bool> isDarkNotifier = ValueNotifier<bool>(true);

  static bool get isDark => isDarkNotifier.value;
  static set isDark(bool v) {
    isDarkNotifier.value = v;
    _channel.invokeMethod<void>('setTheme', v).catchError((_) {});
  }

  /// Called automatically by [MonitorController] on first use — no manual
  /// init needed. Updates [isDarkNotifier] once the native read completes.
  static Future<void> load() async {
    try {
      final saved = await _channel.invokeMethod<bool>('getTheme');
      if (saved != null) isDarkNotifier.value = saved;
    } catch (_) {}
  }

  // ── Backgrounds ───────────────────────────────────────────────────────
  static Color get pageBackground =>
      isDark ? const Color(0xFF0D1117) : const Color(0xFFF4F6F9);
  static Color get surface => isDark ? const Color(0xFF161B22) : Colors.white;
  static Color get expandedDetailBg =>
      isDark ? const Color(0xFF1C2128) : const Color(0xFFF8FAFC);
  static Color get metricsBarBg =>
      isDark ? const Color(0xFF0D1117) : const Color(0xFFEBF0F5);
  static Color get dropdownBg =>
      isDark ? const Color(0xFF21262D) : const Color(0xFFF0F2F5);
  static Color get border =>
      isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
  // Subtle separator lines (thinner visual weight than border)
  static Color get divider =>
      isDark ? const Color(0xFF30363D) : const Color(0xFFF1F4F9);

  // ── Text ─────────────────────────────────────────────────────────────
  static Color get primaryText =>
      isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1A1D23);
  static Color get secondaryText =>
      isDark ? const Color(0xFF7D8590) : const Color(0xFF64748B);

  // ── Status ───────────────────────────────────────────────────────────
  static Color get statusSuccess =>
      isDark ? const Color(0xFF3FB950) : const Color(0xFF2E7D32);
  static Color get statusError =>
      isDark ? const Color(0xFFF85149) : const Color(0xFFD32F2F);
  static Color get statusSlow =>
      isDark ? const Color(0xFFD29922) : const Color(0xFFE65100);

  // ── Phase ─────────────────────────────────────────────────────────────
  static Color get initPhase =>
      isDark ? const Color(0xFFD29922) : const Color(0xFFE65100);
  static Color get refreshPhase =>
      isDark ? const Color(0xFF3FB950) : const Color(0xFF00796B);

  // ── Methods ───────────────────────────────────────────────────────────
  static Color get methodGet =>
      isDark ? const Color(0xFF58A6FF) : const Color(0xFF1976D2);
  static Color get methodPost =>
      isDark ? const Color(0xFF3FB950) : const Color(0xFF388E3C);

  // ── Metrics ───────────────────────────────────────────────────────────
  static Color get metricTotal =>
      isDark ? const Color(0xFF58A6FF) : const Color(0xFF0288D1);
  static Color get metricInit =>
      isDark ? const Color(0xFFD29922) : const Color(0xFFE65100);
  static Color get metricRefresh =>
      isDark ? const Color(0xFF3FB950) : const Color(0xFF00796B);

  // ── Badges ────────────────────────────────────────────────────────────
  static Color get orderBadgeBg =>
      isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0);
  static Color get orderBadgeText =>
      isDark ? const Color(0xFF7D8590) : const Color(0xFF64748B);
  static Color get callerName =>
      isDark ? const Color(0xFFA5D6FF) : const Color(0xFF7B61FF);

  // ── Slow banner ───────────────────────────────────────────────────────
  static Color get slowBannerBg =>
      isDark ? const Color(0xFF2D1F00) : const Color(0xFFFFF3E0);
  static Color get slowBannerBorder =>
      isDark ? const Color(0xFFD29922) : const Color(0xFFFFB74D);

  // ── Charts ────────────────────────────────────────────────────────────
  static Color get fpsLine =>
      isDark ? const Color(0xFF58A6FF) : const Color(0xFF0EA5E9);
  static Color get fpsDot =>
      isDark ? const Color(0xFFF85149) : const Color(0xFFEF4444);

  // ── Overlay (floating HUD — always dark) ─────────────────────────────
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

abstract class MonitorTextStyle {
  /// Monospace — values, timestamps, route names, JSON.
  /// [color] defaults to [MonitorColors.secondaryText].
  static TextStyle mono(
    double size, {
    Color? color,
    FontWeight? weight,
    double? height,
  }) =>
      TextStyle(
        color: color ?? MonitorColors.secondaryText,
        fontSize: size,
        fontFamily: 'monospace',
        fontWeight: weight,
        height: height,
      );

  /// Uppercase bold label — section headers, event badges, chip labels.
  /// Default size 8, letterSpacing 0.4.
  static TextStyle label(
    Color color, {
    double size = 8,
    double spacing = 0.4,
  }) =>
      TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.bold,
        letterSpacing: spacing,
      );

  /// Regular (non-monospace) body text.
  /// [color] defaults to [MonitorColors.primaryText].
  static TextStyle body(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.normal,
  }) =>
      TextStyle(
        color: color ?? MonitorColors.primaryText,
        fontSize: size,
        fontWeight: weight,
      );
}

abstract class OverlayLayout {
  static const double expandedW = 258.0;
  static const double expandedH = 208.0;
  static const double pillW = 110.0;
  static const double pillH = 62.0;
  static const double edgeMargin = 8.0;
}

String fmtDuration(int ms) {
  if (ms >= 1000) return '${(ms / 1000).toStringAsFixed(2)}s';
  return '${ms}ms';
}
